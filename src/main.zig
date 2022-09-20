const std = @import("std");
const linker = @import("linker");

pub fn main() anyerror!void {
    std.log.info("good", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var buf = try linker.ElfBuffer.init("/home/ghostway/projects/zig/linker/zig-out/bin/linker", gpa.allocator());
    var elf: linker.Elf = undefined;
    try elf.parse(&buf);

    std.log.info("{any}", .{buf.readBytes(4)});
}
