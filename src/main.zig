const std = @import("std");
const linker = @import("linker");

pub fn main() anyerror!void {
    std.log.info("good", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // var buf = try linker.ElfBuffer.init("/home/ghostway/projects/cpp/llvm-project/build/lib/LLVMHello.so", gpa.allocator());
    var elf = try linker.Elf.init("/home/ghostway/projects/zig/linker/zig-out/bin/linker", gpa.allocator());

    std.log.err("{}", .{elf});
}
