/// NOT USED NOW

const std = @import("std");
const math = std.math;

const c = @cImport({
    @cInclude("lto.h");
    @cInclude("sys/stat.h"); // for symbol permissions
});

pub const LLVMLTOSymbol = struct {
    index: u32,
    attr: u32,
    name: []const u8,

    pub fn alignment(self: LLVMLTOSymbol) u32 {
        return math.pow(u32, 2, self.attr & c.LTO_SYMBOL_ALIGNMENT_MASK);
    }

    pub fn isWeak(self: LLVMLTOSymbol) bool {
        return self.attr & c.LTO_SYMBOL_DEFINITION_WEAK != 0;
    }

    pub fn isRegular(self: LLVMLTOSymbol) bool {
        return self.attr & c.LTO_SYMBOL_DEFINITION_REGULAR != 0;
    }

    pub fn isUndefined(self: LLVMLTOSymbol) bool {
        return self.attr & c.LTO_SYMBOL_DEFINITION_UNDEFINED != 0;
    }

    pub fn isWeakUndef(self: LLVMLTOSymbol) bool {
        return self.attr & c.LTO_SYMBOL_DEFINITION_WEAKUNDEF != 0;
    }

    pub fn isTentative(self: LLVMLTOSymbol) bool {
        return self.attr & c.LTO_SYMBOL_DEFINITION_TENTATIVE != 0;
    }
};

/// does not check if the symbol index is in the range (it will segfault).
pub fn symbolDetails(module: c.lto_module_t, symbol_index: u32) !LLVMLTOSymbol {
    return LLVMLTOSymbol{
        .index = symbol_index,
        .attr = c.lto_module_get_symbol_attributes(module, symbol_index),
        .name = c.lto_module_get_symbol_name(module, symbol_index),
    };
}

pub const LLVMLTO = struct {
    module: c.lto_module_t,

    pub fn symbols(self: LLVMLTO) !void {
        const num_symbols = c.lto_module_get_num_symbols(self.module);
        if (num_symbols == 0) return;

        var i: c_uint = 0;
        while (i < num_symbols) : (i += 1) {
            const attr = c.lto_module_get_symbol_attribute(self.module, i);
            std.log.info("{s}", .{c.lto_module_get_symbol_name(self.module, i)});
            std.log.info("undef {b}", .{attr & c.LTO_SYMBOL_DEFINITION_UNDEFINED});
        }
    }
};
