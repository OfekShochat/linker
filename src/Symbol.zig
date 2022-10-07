const std = @import("std");
const assert = std.debug.assert;

const Symbol = @This();

pub const Definition = enum {
    undefined,
    weak_undef,
    weak,
    tentative,
    regular,
};

pub const DefinitionError = error {
    InvalidSymbolDefinition,
};

pub const VTable = struct {
    definition: std.meta.FnPtr(fn (ptr: *anyopaque) DefinitionError!Definition),
    alignment: std.meta.FnPtr(fn (ptr: *anyopaque) u32),
};

/// very much inspired by the Allocator implementation.
name: []const u8,
ptr: *anyopaque,
vtable: *const VTable,

optimizable: bool,

pub fn init(
    pointer: anytype,
    definitionFn: fn (@TypeOf(pointer)) DefinitionError!Definition,
    alignmentFn: fn (@TypeOf(pointer)) u32,
) Symbol {
    const Ptr = @TypeOf(pointer);
    const ptr_info = @typeInfo(Ptr);

    assert(ptr_info == .Pointer); // Must be a pointer
    assert(ptr_info.Pointer.size == .One); // Must be a single-item pointer

    const ptr_align = ptr_info.Pointer.alignment;

    const gen = struct {
        fn definitionImpl(ptr: *anyopaque) DefinitionError!Definition {
            const self = @ptrCast(Ptr, @alignCast(ptr_align, ptr));
            return @call(.{ .modifier = .always_inline }, definitionFn, .{ self });
        }
        fn alignmentImpl(ptr: *anyopaque) u32 {
            const self = @ptrCast(Ptr, @alignCast(ptr_align, ptr));
            return @call(.{ .modifier = .always_inline }, alignmentFn, .{ self });
        }

        const vtable = VTable{
            .definition = definitionImpl,
            .alignment = alignmentImpl,
        };
    };

    return Symbol{
        .name = pointer.name,
        .ptr = pointer,
        .vtable = &gen.vtable,
        .optimizable = pointer.optimizable(),
    };
}

pub fn definition(self: Symbol) !Definition {
    self.vtable.definitionImpl(self.ptr);
}

pub fn alignment(self: Symbol) u32 {
    self.vtable.alignmentImpl(self.ptr);
}
