const std = @import("std");
const ArrayList = std.ArrayList;
const mem = std.mem;
const Allocator = mem.Allocator;

const ElfBuffer = @import("ElfBuffer.zig");
const Header = @import("Header.zig");

const Elf = @This();

pub const SectionsTable = struct {
    
};

header: Header,
// sections: SectionsTable,
buf: ElfBuffer,

pub fn init(path: []const u8, allocator: Allocator) !Elf {
    var buf = try ElfBuffer.init(path, allocator);

    var header: Header = undefined;
    try header.parse(&buf);

    // const sections = try parseSectionsTable(&buf, header);

    return Elf{
        .header = header,
        .buf = buf,
        // .sections = sections,
    };
}

fn parseSectionsTable(buf: *ElfBuffer, header: Header) !SectionsTable {
    _ = buf;
    _ = header;
    return error.NotImplemented;
}
