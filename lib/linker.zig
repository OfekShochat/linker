const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const testing = std.testing;
pub const ElfBuffer = @import("ElfBuffer.zig");
pub const Elf = @import("Elf.zig");

/// read symbols from buffer
/// assumes the header is already read.
pub fn readEntrySymbols(elf: *Elf) !void { //Symbols {
    _ = elf;
    // _ = symbols;
    try elf.buf.addOffset(elf.header.shoff);

    var i: u8 = 0;
    while (i < elf.header.shnum) : (i += 1) {
        const old = elf.buf.offset;
        var s: Symbol = undefined;
        s.name = try elf.buf.readU32();
        s.info = try @import("Header.zig").checkedInit(Info, try elf.buf.readU8());
        s.other = try elf.buf.readU8();
        s.shndx = try elf.buf.readU16();
        s.value = try elf.buf.readU64();
        s.size = try elf.buf.readU64();

        std.log.info("{} {} {}", .{s, elf.header.shent_size, elf.buf.offset - old});
    }
}

pub const Index = u32;

pub const Symbols = struct {
    symbols: ArrayList(*Node),
    entry: Index, // should this be included or is this always the first because its the entry?
    elf: Elf,

    pub fn init(elf: Elf, allocator: Allocator) !Symbols {
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

pub const Info = enum(u8) {
    local,
    global,
    weak,
    loos = 10,
    hios = 12,
    loproc = 13,
    hiproc = 15,
};

pub const Symbol = struct {
    name: u32,
    info: Info,
    other: u8,
    shndx: u16,
    value: u64,
    size: u64,
}; // is defined in a separate file. something like Symbol.zig or Info.zig.

pub const Node = struct {
    pub const ChildrenArray = ArrayList(Index);

    info: Symbol,
    children: ChildrenArray,

    pub fn init(self: *Node, info: Symbol, allocator: Allocator) Node {
        self.children = ChildrenArray.init(allocator);
        self.info = info;
    }
};
