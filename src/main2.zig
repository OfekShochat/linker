// first pass: workers are parsing the elf header and adding its symtab contents to the worklist (the worklist is a pointer to the WorkList struct which has the arraylist of pairs of index of the context and the symbol's section (maybe only append new sections we come accross?))
// Two types of InputFile (a tag within it), elf and llvm lto file. the thing we need is a way to parse them (if its with libLTO or others).
// maybe have a union of elf: ElfFile and llvm: LLVMLTO and we have a function that parses either depending on their magic. this is done in parallel ofc. the workqueue has different work types for lto jobs and regular ones (Im quite sure you cant lto on non-lto elf files. hmm this might be wrong, and I need to pass it the symbol names from the native files.). the function merely passes of the work to another function like we have already, or liblto.
// from https://llvm.org/doxygen/classllvm_1_1lto_1_1LTO.html: "Create lto::InputFile objects using lto::InputFile::create(), then use the symbols() function to enumerate its symbols and compute a resolution for each symbol (see SymbolResolution below).".
// https://llvm.org/doxygen/group__LLVMCLTO.html c api
//this includes having the ability of getting the symbols defined.

const std = @import("std");
const mem = std.mem;
const elf = std.elf;
const os = std.os;
const fs = std.fs;
const extension = fs.path.extension;
const File = fs.File;
const Allocator = mem.Allocator;
const assert = std.debug.assert;

const lto = @import("lto.zig");

// InputFile: union of lto: LTOModule(union of just llvm_lto for now), elf: ElfFile. there will be a function loadInputFile() that will take a path, and according to the extension or the magic determine which function it should use to construct the input file. every instance of InputFile should have a symbolIter() function that returns a type. that type iterates over the symbols. it returns a !?Symbol. Symbol has: name: []const u8, section index, is_volatile (if it might change after optimization, aka all symbols in lto. better name is required, because I still need this to not start over the symbol discovery process), is_undef, is_weak, is_weak_undef, is_regular, alignment.


// in ElfFile.zig there will be ElfSymbol which has a symbol() method which returns a Symbol.


const ElfFile = struct { file: File, header: elf.Header };

// is this thing even necessary?
fn symbolPermissions(sa: u32) SymbolPermissions {
    return SymbolPermissions{
        .permission_attributes = sa & c.LTO_SYMBOL_PERMISSIONS_MASK,
    };
}

pub const SymbolPermissions = struct {
    permission_attributes: u32,

    pub fn hasRead(self: SymbolPermissions) bool {
        return (self.permission_attributes & c.S_IRUSR) != 0;
    }
};

pub const InputFile = union {
    elf: ElfFile,
    llvm_lto: LLVMLTO,
};

const c = @cImport({
    @cInclude("lto.h");
    @cInclude("sys/stat.h"); // for symbol permissions
});

pub fn loadInputFile(path: []const u8) !InputFile {
    const ext = extension(path);
    if (mem.eql(u8, ext, ".bc")) {
        return InputFile{ .llvm_lto = try loadLLVMLTO(path) };
    } else if (mem.eql(u8, ext, ".o")) {
        return InputFile{ .elf = try loadElfFile(path) };
    } else {
        return error.InvalidInputType; // TODO: is this actually it? or should I detect it by the magic (aka try one by one until one doesnt fail).
    }
}

pub const Error = error{
    ModuleAddFailed,
    InvalidLLVMBitcode,
    CodegenError,
    ContextCreationFailed,
    InvalidInputType,
};

fn isLLVMError(err: Error) bool {
    switch (err) {
        .ModuleAddFailed, .InvalidLLVMBitcode, .CodegenError, .ContextCreationFailed => true,
        .InvalidInputType => false,
    }
}

fn loadElfFile(path: []const u8) !ElfFile {
    var path_buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
    const full_path = try fs.realpath(path, &path_buffer);

    var file = try fs.openFileAbsolute(full_path, .{});

    const header = try elf.Header.read(file);
    return ElfFile{
        .header = header,
        .file = file,
    };
}

pub fn preserveSymbol(ctx: c.lto_code_gen_t, symbol: []const u8) void {
    c.lto_codegen_add_must_preserve_symbol(ctx, symbol.ptr);
}

pub fn addLTOModule(ctx: c.lto_code_gen_t, module: c.lto_module_t) !void {
    if (c.lto_codegen_add_module(ctx, module)) return error.ModuleAddFailed;
}

/// assumes the file is a loadable (llvm) object file.
fn loadLLVMLTO(path: []const u8) !LLVMLTO {
    if (c.lto_module_create(path.ptr)) |module| {
        std.log.info("{}", .{c.lto_module_get_num_symbols(module)});
        return LLVMLTO{ .module = module };
    } else {
        reportLLVM();
        return error.InvalidLLVMBitcode;
    }
}

fn reportLLVM() void {
    std.log.err("{s}", .{c.lto_get_error_message()});
}

pub fn createLTOContext() !c.lto_code_gen_t {
    if (c.lto_codegen_create()) |ctx| {
        return ctx;
    } else return error.ContextCreationFailed;
}

pub const LLVMLTO = struct {
    module: c.lto_module_t,

    pub fn symbols(self: LLVMLTO) !void {
        const num_symbols = c.lto_module_get_num_symbols(self.module);
        if (num_symbols == 0) return;

        var i: c_uint = 0;
        while (i < num_symbols) : (i += 1) {
            const attr = c.lto_module_get_symbol_attribute(self.module, i);
            std.log.info("{s}", .{c.lto_module_get_symbol_name(self.module, i)});
            std.log.info("undef {b}", .{attr & c.LTO_SYMBOL_DEFINITION_UNDEFINED});
        }
    }
};

pub fn main() anyerror!void {
    var lto_manager = try lto.llvm.LTO.init();
    _ = lto_manager;
    var elf_file = try loadInputFile("hi.bc");
    // std.log.info("{}", .{elf_file.elf});
    var module = try loadInputFile("poop.bc");
    std.log.info("{s}", .{c.lto_module_get_symbol_name(module.llvm_lto.module, 0)});
    var ctx = try createLTOContext();
    try addLTOModule(ctx, elf_file.llvm_lto.module);
    try addLTOModule(ctx, module.llvm_lto.module);
    preserveSymbol(ctx, "_Z4hahav");
    var output: [*c]const u8 = "";
    if (c.lto_codegen_compile_to_file(ctx, &output)) {
        return error.CodegenError;
    }
    std.log.info("{s}", .{mem.span(output)});
    const lto_output = try loadElfFile(mem.span(output));
    c.lto_codegen_dispose(ctx);
    std.log.info("{}", .{lto_output});
    try module.llvm_lto.symbols();
}
