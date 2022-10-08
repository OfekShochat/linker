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
    definition: std.meta.FnPtr(fn (ptr: *anyopaque) DefinitionError!Definition),
    alignment: std.meta.FnPtr(fn (ptr: *anyopaque) u32),
    isLTO: std.meta.FnPtr(fn (ptr: *anyopaque) bool),
};

/// very much inspired by the Allocator implementation.
name: []const u8,
ptr: *anyopaque,
vtable: *const VTable,

pub fn init(
    pointer: anytype,
    definitionFn: fn (@TypeOf(pointer)) DefinitionError!Definition,
    alignmentFn: fn (@TypeOf(pointer)) u32,
    isLTOFn: fn (@TypeOf(pointer)) bool,
) Symbol {
    const Ptr = @TypeOf(pointer);
    const ptr_info = @typeInfo(Ptr);

    assert(ptr_info == .Pointer);
    assert(ptr_info.Pointer.size == .One);

    const ptr_align = ptr_info.Pointer.alignment;

    const gen = struct {
        fn definitionImpl(ptr: *anyopaque) DefinitionError!Definition {
            const self = @ptrCast(Ptr, @alignCast(ptr_align, ptr));
            return @call(.{ .modifier = .always_inline }, definitionFn, .{self});
        }
        fn alignmentImpl(ptr: *anyopaque) u32 {
            const self = @ptrCast(Ptr, @alignCast(ptr_align, ptr));
            return @call(.{ .modifier = .always_inline }, alignmentFn, .{self});
        }
        fn isLTOImpl(ptr: *anyopaque) bool {
            const self = @ptrCast(Ptr, @alignCast(ptr_align, ptr));
            return @call(.{ .modifier = .always_inline }, isLTOFn, .{self});
        }

        const vtable = VTable{
            .definition = definitionImpl,
            .alignment = alignmentImpl,
            .isLTO = isLTOImpl,
        };
    };

    return Symbol{
        .name = pointer.name,
        .ptr = pointer,
        .vtable = &gen.vtable,
    };
}

pub fn format(self: Symbol, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt;
    _ = options;
    try writer.print("Symbol{{ .name = {s}, .ptr = {}, .isLTO = {} }}", .{
        self.name,
        self.ptr,
        self.isLTO(),
    });
}

pub fn definition(self: Symbol) !Definition {
    return self.vtable.definition(self.ptr);
}

pub fn alignment(self: Symbol) u32 {
    return self.vtable.alignment(self.ptr);
}

pub fn isLTO(self: Symbol) bool {
    return self.vtable.isLTO(self.ptr);
}
