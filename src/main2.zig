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
const Allocator = mem.Allocator;

const ElfFile = struct { header: elf.Header };

const LLVMLTO = struct {
    module: c.lto_module_t,
};

pub const InputFile = union {
    elf: ElfFile,
    llvm_lto: LLVMLTO,
};

const c = @cImport({
    @cInclude("lto.h");
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

fn loadElfFile(path: []const u8) !ElfFile {
    var path_buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
    const full_path = try fs.realpath(path, &path_buffer);

    var file = try fs.openFileAbsolute(full_path, .{});
    defer file.close();

    const header = try elf.Header.read(file);
    return ElfFile{
        .header = header,
    };
}

/// assumes the file is a loadable (llvm) object file.
fn loadLLVMLTO(path: []const u8) !LLVMLTO {
    if (c.lto_module_create(path.ptr)) |module| {
        std.log.info("{}", .{c.lto_module_get_num_symbols(module)});
        return LLVMLTO{ .module = module };
    } else {
        std.log.err("{s}", .{c.lto_get_error_message()});
        return error.InvalidLLVMBitcode;
    }
}

pub fn createLTOContext(modules: []const LLVMLTO) !c.lto_code_gen_t {
    if (c.lto_codegen_create()) |ctx| {
        for (modules) |mod| {
            if (c.lto_codegen_add_module(ctx, mod.module)) {
                return error.LTOModuleError;
            }
        }
        return ctx;
    } else {
        return error.ContextCreationFailed;
    }
}

pub fn main() anyerror!void {
    var module = try loadInputFile("poop.bc");
    std.log.info("{s}", .{c.lto_module_get_symbol_name(module.llvm_lto.module, 0)});
    var ctx = try createLTOContext(&.{module.llvm_lto});
    var names: [*c]const u8 = "";
    std.log.info("{s}", .{names});
    if (c.lto_codegen_compile_to_file(ctx, &names)) {
        return error.CodegenError;
    }
    std.log.info("{s}", .{names});
    std.time.sleep(10000000000);
    c.lto_codegen_dispose(ctx);
}
