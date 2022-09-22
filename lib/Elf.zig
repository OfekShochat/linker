const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

const ElfBuffer = @import("ElfBuffer.zig");
const Header = @import("Header.zig");

const Elf = @This();

header: Header,
buf: ElfBuffer,

pub fn init(path: []const u8, allocator: Allocator) !Elf {
    var buf = try ElfBuffer.init(path, allocator);

    var header: Header = undefined;
    try header.parse(&buf);

    std.log.info("{}", .{buf.offset});

    return Elf{
        .header = header,
        .buf = buf,
    };
}
