// first pass: workers are parsing the elf header and adding its symtab contents to the worklist (the worklist is a pointer to the WorkList struct which has the arraylist of pairs of index of the context and the symbol's section (maybe only append new sections we come accross?))

// Two types of InputFile (a tag within it), elf and llvm lto file. the thing we need is a way to parse them (if its with libLTO or others).
// maybe have a union of elf: ElfFile and llvm: LLVMLTO and we have a function that parses either depending on their magic. this is done in parallel ofc. the workqueue has different work types for lto jobs and regular ones (Im quite sure you cant lto on non-lto elf files. hmm this might be wrong, and I need to pass it the symbol names from the native files.). the function merely passes of the work to another function like we have already, or liblto.
// from https://llvm.org/doxygen/classllvm_1_1lto_1_1LTO.html: "Create lto::InputFile objects using lto::InputFile::create(), then use the symbols() function to enumerate its symbols and compute a resolution for each symbol (see SymbolResolution below).".
// https://llvm.org/doxygen/group__LLVMCLTO.html c api
//this includes having the ability of getting the symbols defined.

const std = @import("std");
const elf = std.elf;

const ElfFile = struct {
    header: elf.Header
};

const LLVMLTO = struct {
    
};

const c = @cImport({
    @cInclude("/home/ghostway/projects/cpp/llvm-project/llvm/include/llvm-c/lto.h");
});

/// assumes the file is a loadable (llvm) object file.
pub fn loadLLVMLTO(path: []const u8) !LLVMLTO {
    if (c.lto_module_create(path)) |module| {
        std.log.info("{}", .{c.lto_module_get_num_symbols(module)});
    } else return c.lto_get_error_message();
}

pub const InputFile = union {
    elf: ElfFile,
    llvm_lto: LLVMLTO,
};

pub fn main() anyerror!void {
    try loadLLVMLTO("b.o");
}
