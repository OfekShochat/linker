const std = @import("std");
const fs = std.fs;
const File = fs.File;
const mem = std.mem;
const Allocator = mem.Allocator;

const ElfBuffer = @This();

offset: u64,
file: File,
allocator: Allocator,

pub fn init(path: []const u8, allocator: Allocator) !ElfBuffer {
    return ElfBuffer {
        .offset = 0,
        .file = try fs.openFileAbsolute(path, .{}),
        .allocator = allocator,
    };
}

pub fn setOffset(self: *ElfBuffer, off: u64) !void {
    if (self.file.getEndPos())
        return error.OffsetTooLarge;
    self.offset = off;
}

pub fn read(self: *ElfBuffer, comptime DestType: type) !DestType {
    const size = @sizeOf(DestType);
    var buffer align(@alignOf(DestType)) = try self.allocator.alloc(u8, size);
    defer self.allocator.free(buffer);

    const bytes = try self.file.pread(buffer, self.offset);
    if (bytes != size) return error.ReadError;

    self.offset += size;

    return mem.bytesAsSlice(DestType, buffer[0..])[0];
}

pub fn readI32(self: *ElfBuffer) !i32 {
    return self.read(i32);
}

pub fn readU8(self: *ElfBuffer) !u8 {
    return self.read(u8);
}

pub fn readU32(self: *ElfBuffer) !u32 {
    return self.read(u32);
}

pub fn readU64(self: *ElfBuffer) !u32 {
    return self.read(u32);
}

pub fn readI64(self: *ElfBuffer) !i32 {
    return self.read(i32);
}

pub fn readBytes(self: *ElfBuffer, comptime n: usize) ![n]u8 {
    return self.read([n]u8);
}
