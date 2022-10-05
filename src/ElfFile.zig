const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const elf = std.elf;
const SectionHeaderIterator = elf.SectionHeaderIterator;
const File = std.fs.File;
const native_endian = @import("builtin").target.cpu.arch.endian();

const ElfFile = @This();

file: File,
header: elf.Header,

pub fn init(path: []const u8) !ElfFile {
    var path_buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
    const full_path = try fs.realpath(path, &path_buffer);

    var file = try fs.openFileAbsolute(full_path, .{});

    const header = try elf.Header.read(file);
    return ElfFile{
        .header = header,
        .file = file,
    };
}

// use this so that when we iterate we save both the str table offset and the symbols section.
pub fn sectionHeaderIter(self: ElfFile) SectionHeaderIterator(File) {
    return self.header.section_header_iterator(self.file);
}

pub fn symbolIter(self: ElfFile) !SymbolIterator(File) {
    var iter = SymbolIterator(File){
        .elf_header = self.header,
        .parse_source = self.file,
        .symtab_off = 0,
        .strtab_off = 0,
        .number = 0,
    };

    var symtab_size = null;
    var sh_iter = self.sectionHeaderIter();
    while (try sh_iter.next()) |sh| {
        switch (sh.sh_type) {
            elf.SHT_SYMTAB => {
                iter.symtab_off = sh.sh_offset;
                size = sh.sh_size;
            },
            elf.SHT_STRTAB => iter.strtab_off = sh.sh_offset,
        }
    }
    if (symatb_size) |size| {
        if (self.header.is_64) {
            iter.number = size / 8;
        } else {
            iter.number = size / 4;
        }
    } else return error.NoSymtab;
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
                const offset = self.offset + @sizeOf(@TypeOf(sym)) * self.index;
                try self.parse_source.seekableStream().seekTo(offset);
                try self.parse_source.reader().readNoEof(std.mem.asBytes(&sym));

                if (self.elf_header.endian == native_endian) return sym;

                mem.byteSwapAllFields(elf.Elf64_Sym, &sym);
                return sym;
            }

            var sym: elf.Elf32_Sym = undefined;
            const offset = self.offset + @sizeOf(@TypeOf(sym)) * self.index;
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
