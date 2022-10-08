const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const elf = std.elf;
const File = fs.File;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const SectionHeaderIterator = elf.SectionHeaderIterator;
const native_endian = @import("builtin").target.cpu.arch.endian();

const Symbol = @import("Symbol.zig");
const DefinitionError = Symbol.DefinitionError;
const Definition = Symbol.Definition;

const ElfFile = @This();

pub const ELfSymbol = struct {
    name: []const u8,
    info: elf.Elf64_Sym,

    pub fn symbol(self: *ElfFile) Symbol {
        return Symbol.init(self);
    }

    // pub fn definition(self: *const ELfSymbol) DefinitionError!Definition {
    //     switch (def) {
    //         
    //     }
    // }
};

pub const SectionHeader = struct {
    strtab: []const u8 = undefined,
    symtab: usize = 0, // offset
    progbits: ArrayList(elf.Elf64_Shdr),
};

fn readSectionHeader(file: File, header: elf.Header, allocator: Allocator) !SectionHeader {
    var progbits = ArrayList(elf.Elf64_Shdr).init(allocator);
    var symtab: usize = 0;
    var strtab: []u8 = undefined;

    var iter = header.section_header_iterator(file);
    while (try iter.next()) |shi| {
        switch (shi.sh_type) {
            elf.SHT_STRTAB => {
                // technically I can get this with the index form the header, but Im iterating over all of them anyways...
                strtab = try allocator.alloc(u8, shi.sh_size);
                try file.seekableStream().seekTo(shi.sh_offset);
                try file.reader().readNoEof(strtab);
            },
            elf.SHT_SYMTAB => symtab = shi.sh_offset,
            elf.SHT_PROGBITS => try progbits.append(shi),
            else => {}
        }
    }

    return SectionHeader{
        .progbits = progbits,
        .symtab = symtab,
        .strtab = strtab,
    };
}

file: File,
header: elf.Header,
shdr: SectionHeader,

pub fn init(path: []const u8, allocator: Allocator) !ElfFile {
    var path_buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
    const full_path = try fs.realpath(path, &path_buffer);

    var file = try fs.openFileAbsolute(full_path, .{});

    const header = try elf.Header.read(file);
    const shdr = try readSectionHeader(file, header, allocator);

    return ElfFile{
        .header = header,
        .file = file,
        .shdr = shdr,
    };
}

// use this so that when we iterate we save both the str table offset and the symbols section.
pub fn sectionHeaderIter(self: ElfFile) SectionHeaderIterator(File) {
    return self.header.section_header_iterator(self.file);
}

// TODO: make this like llvm's and use Symbol.
pub fn symbolIter(self: ElfFile) !SymbolIterator(File) {
    var iter = SymbolIterator(File){
        .elf_header = self.header,
        .parse_source = self.file,
        .symtab_off = 0,
        .strtab_off = 0,
        .number = 0,
    };

    var sh_iter = self.sectionHeaderIter();
    while (try sh_iter.next()) |sh| {
        if (sh.sh_type == elf.SHT_SYMTAB) {
            iter.symtab_off = sh.sh_offset;
            const sym_size = if (self.header.is_64) 8 else 4;
            iter.number = sh.sh_size / sym_size;
        }
    }
    return iter;
}

pub fn SymbolIterator(comptime ParseSource: anytype) type {
    return struct {
        elf_header: elf.Header,
        parse_source: ParseSource,
        symtab_off: usize,
        strtab_off: usize,
        number: usize,
        index: usize = 0,

        pub fn next(self: *@This()) !?elf.Elf64_Sym {
            if (self.index >= self.number) return null;
            defer self.index += 1;

            if (self.elf_header.is_64) {
                var sym: elf.Elf64_Sym = undefined;
                const offset = self.symtab_off + @sizeOf(@TypeOf(sym)) * self.index;
                try self.parse_source.seekableStream().seekTo(offset);
                try self.parse_source.reader().readNoEof(std.mem.asBytes(&sym));

                if (self.elf_header.endian == native_endian) return sym;

                mem.byteSwapAllFields(elf.Elf64_Sym, &sym);
                return sym;
            }

            var sym: elf.Elf32_Sym = undefined;
            const offset = self.symtab_off + @sizeOf(@TypeOf(sym)) * self.index;
            try self.parse_source.seekableStream().seekTo(offset);
            try self.parse_source.reader().readNoEof(std.mem.asBytes(&sym));

            if (self.elf_header.endian != native_endian) mem.byteSwapAllFields(elf.Elf32_Sym, &sym);

            return elf.Elf64_Sym{
                .st_name = sym.st_name,
                .st_value = sym.st_value,
                .st_other = sym.st_other,
                .st_shndx = sym.st_shndx,
                .st_info = sym.st_info,
                .st_size = sym.st_size,
            };
        }
    };
}
