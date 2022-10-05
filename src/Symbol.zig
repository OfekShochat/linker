const std = @import("std");

pub const Definition = enum {
    undefined,
    weak_undef,
    weak,
    tentative,
    defined,
};

pub const VTable = struct {
    definition: std.meta.FnPtr(fn (ptr: *anyopaque) Definition),
    alignment: std.meta.FnPtr(fn (ptr: *anyopaque) u32),
};

/// very much inspired by the Allocator implementation.
pub const Symbol = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub fn init(pointer: anytype) Symbol {
        const Ptr = @TypeOf(pointer);
        const ptr_info = @typeInfo(Ptr);


        const ptr_align = ptr_info.Pointer.alignment;

        const gen = struct {
            fn definitionFn(ptr: *anyopaque) Definition {
                const self = @ptrCast(Ptr, @alignCast(ptr_align, ptr));
                @call(.{ .modifier = .always_align }, pointer.definition, .{ self });
            }
            fn alignmentFn(ptr: *anyopaque) u32 {
                const self = @ptrCast(Ptr, @alignCast(ptr_align, ptr));
                @call(.{ .modifier = .always_align }, pointer.alignment, .{ self });
            }

            const vtable = VTable{
                .definition = definitionFn,
                .alignment = alignmentFn,
            };
        };

        return Symbol{
            .ptr = pointer,
            .vtable = &gen.vtable,
        };
    }

    pub fn definition(self: Symbol) Definition {
        self.vtable.definitionFn(self.ptr);
    }

    pub fn alignment(self: Symbol) u32 {
        self.vtable.alignmentFn(self.ptr);
    }
};
