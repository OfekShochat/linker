const std = @import("std");
const ArrayList = std.ArrayList;
const mem = std.mem;
const Allocator = mem.Allocator;
const elf = std.elf;
const Header = elf.Header;
const ProgramHeaderIterato = elf.ProgramHeaderIterator;
const SectionHeaderIterator = elf.SectionHeaderIterator;

const ElfBuffer = @import("ElfBuffer.zig");

const Elf = @This();

pub const SectionsTable = struct {
    
};

header: Header,
// sections: SectionsTable,

pub fn init(path: []const u8, allocator: Allocator) !Elf {
    var buf = try ElfBuffer.init(path, allocator);

    const bytes align(@sizeOf(elf.Elf64_Ehdr)) = try buf.readBytes(@sizeOf(elf.Elf64_Ehdr));
    const header = try Header.parse(&bytes);

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
