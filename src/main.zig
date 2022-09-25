const std = @import("std");
const Allocator = std.mem.Allocator;
const Elf64_Sym = std.elf.Elf64_Sym;
const ArrayList = std.ArrayList;
const File = std.fs.File;
const ElfFile = @import("ElfFile.zig");

pub const Index = u32;

pub const Symbols = struct {
    symbols: ArrayList(*Node),
    entry: Index, // should this be included or is this always the first because its the entry?
    elf: ElfFile,

    pub fn init(elf: ElfFile, allocator: Allocator) !Symbols {
        var symbols = ArrayList(*Node).init(allocator);

        return Symbols{
            .symbols = symbols,
            .elf = elf,
        };
    }

    pub fn get(self: Symbols, index: Index) ?*Node {
        if (index >= self.symbols.items.len) return null;
        return self.symbols.items[index];
    }
};

pub const Node = struct {
    pub const ChildrenArray = ArrayList(Index);

    info: Elf64_Sym,
    children: ChildrenArray,

    pub fn init(self: *Node, info: Elf64_Sym, allocator: Allocator) Node {
        self.children = ChildrenArray.init(allocator);
        self.info = info;
    }
};

pub fn symbolBinding(sym: Elf64_Sym) u8 {
    return sym.st_info >> 4;
}

pub fn symbolType(sym: Elf64_Sym) u8 {
    return sym.st_info & 0x0f;
}

pub fn main() anyerror!void {
    std.log.info("good", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    _ = gpa;
    var elf = try ElfFile.init(try std.fs.cwd().openFile("poop.o", .{}));

    std.log.info("{}", .{elf});

    var phi = elf.sectionHeaderIter();
    var i: u8 = 0;
    while (i < 9) : (i += 1) {
        std.log.info("{}", .{(try phi.next()).?});
    }
    var a = try elf.symbolIter();
    while (try a.next()) |sym| {
        std.log.info("{any} {} {}", .{sym, symbolBinding(sym), symbolType(sym)});
    }
}
