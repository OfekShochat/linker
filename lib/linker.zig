const std = @import("std");
const testing = std.testing;
pub const ElfBuffer = @import("ElfBuffer.zig");
pub const Elf = @import("Elf.zig");

/// read symbols from buffer
/// assumes the header is already read.
pub fn readSymbols(elf: *Elf) void {
    _ = elf;
}
