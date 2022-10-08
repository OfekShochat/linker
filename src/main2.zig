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
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const Thread = std.Thread;
const Mutex = Thread.Mutex;

const lto = @import("lto.zig");
const Symbol = @import("Symbol.zig");
const llvm = lto.llvm;
const ElfFile = @import("ElfFile.zig");

// InputFile: union of lto: LTOModule(union of just llvm_lto for now), elf: ElfFile. there will be a function loadInputFile() that will take a path, and according to the extension or the magic determine which function it should use to construct the input file. every instance of InputFile should have a symbolIter() function that returns a type. that type iterates over the symbols. it returns a !?Symbol. Symbol has: name: []const u8, section index, is_volatile (if it might change after optimization, aka all symbols in lto. better name is required, because I still need this to not start over the symbol discovery process), is_undef, is_weak, is_weak_undef, is_regular, alignment.


// in ElfFile.zig there will be ElfSymbol which has a symbol() method which returns a Symbol.

pub fn loadSymbols(ctx: *Context, module: anytype) !void {
    var iter = try module.symbolIter(ctx.allocator);

    while (try iter.next()) |sym| {
        std.log.info("{}", .{sym});
        if (!sym.isUndefined()) try ctx.symmap.putMutex(sym, ctx.allocator);
    }
}

pub const SymbolMap = struct {
    pub const SymbolArray = ArrayList(Symbol);
    pub const Map = StringHashMap(SymbolArray);

    mutex: Mutex,
    map: Map,

    pub fn init(allocator: Allocator) SymbolMap {
        return SymbolMap{
            .mutex = Mutex{},
            .map = Map.init(allocator),
        };
    }

    pub fn put(self: *SymbolMap, sym: Symbol, allocator: Allocator) !void {
        var entry = try self.map.getOrPut(sym.name);
        if (entry.found_existing) {
            try entry.value_ptr.append(sym);
        } else {
            entry.value_ptr.* = SymbolArray.init(allocator);
            try entry.value_ptr.append(sym);
        }
    }

    pub fn putMutex(self: *SymbolMap, sym: Symbol, allocator: Allocator) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.put(sym, allocator);
    }

    pub fn get(self: SymbolMap, name: []const u8) ?SymbolArray {
        return self.map.get(name);
    }

    pub fn getMutex(self: SymbolMap, name: []const u8) ?SymbolArray {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.get(name);
    }
};

pub const Context = struct {
    symmap: SymbolMap,
    allocator: Allocator,

    pub fn init(allocator: Allocator) Context {
        return Context{
            .symmap = SymbolMap.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn put(self: *Context, sym: Symbol) !void {
        return self.symmap.put(sym, self.allocator);
    }
};

pub fn main() anyerror!void {
    var lto_manager = try llvm.LTO.init();
    defer lto_manager.deinit();
    const himod = try llvm.Module.load("hi.bc");
    // try lto_manager.addModule(himod);
    const poopmod = try llvm.Module.load("poop.bc");

    try lto_manager.addModule(poopmod);

    lto_manager.preserveSymbol("_Zhahav");
    lto_manager.preserveSymbol("main");
    const output_file = try lto_manager.compile();
    std.log.info("{s}", .{output_file});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    var map = Context.init(allocator);
    try loadSymbols(&map, himod);
    try loadSymbols(&map, poopmod);
    std.log.info("{any}", .{map.symmap.get("_Z4hahav")});
    std.log.info("{any}", .{map.symmap.get("main").?.items});
    poopmod.deinit();
    himod.deinit();

    // var elf_file = try ElfFile.init(output_file, allocator);
    // std.log.info("{}", .{elf_file});
}
