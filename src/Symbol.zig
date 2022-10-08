const std = @import("std");
const assert = std.debug.assert;
const llvm = @import("lto/llvm.zig");

const Symbol = @This();

pub const Definition = enum {
    undefined,
    weak_undef,
    weak,
    tentative,
    regular,
};

pub const DefinitionError = error{
    InvalidSymbolDefinition,
};

pub const VTable = struct {
    isUndefined: std.meta.FnPtr(fn (ptr: *anyopaque) bool),
};

/// very much inspired by the Allocator implementation.
name: []const u8,
is_lto: bool,
ptr: *anyopaque,
vtable: *const VTable,

pub fn init(
    pointer: anytype,
    comptime is_lto: bool,
    comptime isUndefinedFn: fn (@TypeOf(pointer)) bool,
) Symbol {
    const Ptr = @TypeOf(pointer);
    const ptr_info = @typeInfo(Ptr);

    assert(ptr_info == .Pointer);
    assert(ptr_info.Pointer.size == .One);

    const ptr_align = ptr_info.Pointer.alignment;

    const gen = struct {
        fn isUndefinedImpl(ptr: *anyopaque) bool {
            const self = @ptrCast(Ptr, @alignCast(ptr_align, ptr));
            return @call(.{ .modifier = .always_inline }, isUndefinedFn, .{self});
        }

        const vtable = VTable{
            .isUndefined = isUndefinedImpl,
        };
    };

    return Symbol{
        .name = pointer.name,
        .is_lto = is_lto,
        .ptr = pointer,
        .vtable = &gen.vtable,
    };
}

pub fn format(self: Symbol, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt;
    _ = options;
    try writer.print("Symbol{{ .name = {s}, .ptr = {}, .is_lto = {}, .is_undefined = {} }}", .{
        self.name,
        self.ptr,
        self.is_lto,
        self.isUndefined(),
    });
}

pub fn isUndefined(self: Symbol) bool {
    return self.vtable.isUndefined(self.ptr);
}
