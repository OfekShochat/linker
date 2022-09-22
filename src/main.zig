const std = @import("std");
const linker = @import("linker");

pub fn main() anyerror!void {
    std.log.info("good", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var elf = try linker.Elf.init("/home/ghostway/projects/zig/linker/zig-out/bin/linker", gpa.allocator());

    std.log.info("{}", .{elf});
}
