const std = @import("std");
const mem = std.mem;
const math = std.math;
const Allocator = mem.Allocator;

const Symbol = @import("../Symbol.zig");
const Definition = Symbol.Definition;
const DefinitionError = Symbol.DefinitionError;
pub const c = @cImport({
    @cInclude("lto.h");
});

pub const LLVMSymbol = struct {
    attr: u32,
    name: []const u8,

    pub fn symbol(self: *LLVMSymbol) Symbol {
        return Symbol.init(self, definition, alignment, isLTO);
    }

    pub fn name(self: LLVMSymbol) []const u8 {
        return self.name;
    }

    pub fn definition(self: *const LLVMSymbol) DefinitionError!Definition {
        const def_attr = (self.attr & c.LTO_SYMBOL_DEFINITION_MASK) >> 8;
        return switch (def_attr) {
            1 => .regular,
            2 => .tentative,
            3 => .weak,
            4 => .undefined,
            5 => .weak_undef,
            else => DefinitionError.InvalidSymbolDefinition,
        };
    }

    pub fn alignment(self: *const LLVMSymbol) u32 {
        return math.pow(u32, 2, self.attr & c.LTO_SYMBOL_ALIGNMENT_MASK);
    }

    pub fn isLTO(_: *const LLVMSymbol) bool {
        return true;
    }
};

// in InputFile, then we call symbolIter and add the symbols (this can be made with one function, as we can use anytype).
pub const Module = struct {
    llvm: c.lto_module_t,

    pub fn load(path: []const u8) !Module {
        if (c.lto_module_create(path.ptr)) |module| {
            return Module{ .llvm = module };
        } else return error.InvalidLLVMBitcode;
    }

    pub fn symbolIter(self: Module, allocator: Allocator) !SymbolIter {
        return SymbolIter{
            .allocator = allocator,
            .mod = self.llvm,
            .number = c.lto_module_get_num_symbols(self.llvm),
        };
    }

    pub fn deinit(self: Module) void {
        c.lto_module_dispose(self.llvm);
    }
};

pub const SymbolIter = struct {
    mod: c.lto_module_t,
    number: u32,
    index: u32 = 0,
    allocator: Allocator,

    pub fn next(self: *SymbolIter) !?Symbol {
        if (self.index >= self.number) return null;
        defer self.index += 1;

        var llsym = try self.allocator.create(LLVMSymbol);
        llsym.attr = c.lto_module_get_symbol_attribute(self.mod, self.index);
        llsym.name = mem.span(c.lto_module_get_symbol_name(self.mod, self.index));

        return llsym.symbol();
    }
};

fn createLTOContext() !c.lto_code_gen_t {
    if (c.lto_codegen_create()) |ctx| {
        return ctx;
    } else return error.ContextCreationFailed;
}

pub const LTO = struct {
    codegen: c.lto_code_gen_t,

    pub fn init() !LTO {
        return LTO{
            .codegen = try createLTOContext(),
        };
    }

    pub fn addModule(self: LTO, mod: Module) !void {
        if (c.lto_codegen_add_module(self.codegen, mod.llvm)) {
            return error.ModuleAddFailed;
        }
    }

    pub fn addModuleFromPath(self: LTO, path: []const u8) !void {
        const mod = try Module.load(path);
        return self.addModule(mod);
    }

    pub fn preserveSymbol(self: LTO, symbol: []const u8) void {
        c.lto_codegen_add_must_preserve_symbol(self.codegen, symbol.ptr);
    }

    /// returns the path to the compiled elf file and disposes the codegen structure (TODO: should it?).
    pub fn compile(self: LTO) ![]const u8 {
        var path: [*c]const u8 = "";
        if (c.lto_codegen_compile_to_file(self.codegen, &path)) {
            return error.CodegenError;
        }
        return mem.span(path);
    }

    pub fn deinit(self: LTO) void {
        c.lto_codegen_dispose(self.codegen);
    }
};
