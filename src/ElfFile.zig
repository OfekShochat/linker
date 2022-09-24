const std = @import("std");
const mem = std.mem;
const elf = std.elf;
const Header = elf.Header;
const SectionHeaderIterator = elf.SectionHeaderIterator;
const ProgramHeaderIterator = elf.ProgramHeaderIterator;
const Elf64_Sym = elf.Elf64_Sym;
const Elf32_Sym = elf.Elf32_Sym;
const File = std.fs.File;
const native_endian = @import("builtin").target.cpu.arch.endian();

const ElfFile = @This();

file: File,
header: Header,

pub fn init(file: File) !ElfFile {
    const header = try Header.read(file);

    return ElfFile{
        .file = file,
        .header = header,
    };
}

pub fn programHeaderIter(self: ElfFile) ProgramHeaderIterator(File) {
    return self.header.program_header_iterator(self.file);
}

pub fn sectionHeaderIter(self: ElfFile) SectionHeaderIterator(File) {
    return self.header.section_header_iterator(self.file);
}

pub fn symbolIter(self: ElfFile) !SymbolIterator(File) {
    return try SymbolIterator(File).init(
        self.header,
        self.file,
    );
}

pub fn SymbolIterator(comptime ParseSource: anytype) type {
    return struct {
        elf_header: Header,
        parse_source: ParseSource,
        offset: usize,
        index: usize = 0,
        number: usize,

        pub fn init(
            elf_header: Header,
            parse_source: ParseSource,
        ) !@This() {
            var sh_iter = elf_header.section_header_iterator(parse_source);
            // TODO: clean this up
            var offset: usize = 0;
            var size: usize = 0;
            while (true) {
                const shi = (try sh_iter.next()) orelse break;
                if (shi.sh_type == elf.SHT_SYMTAB) {
                    offset = shi.sh_offset;
                    size = shi.sh_size;
                    break;
                }
            }

            return .{
                .elf_header = elf_header,
                .parse_source = parse_source,
                .offset = offset,
                .number = size / @sizeOf(elf.Sym),
            };
        }

        pub fn next(self: *@This()) !?Elf64_Sym {
            if (self.index >= self.number) return null;
            defer self.index += 1;

            if (self.elf_header.is_64) {
                var sym: Elf64_Sym = undefined;
                const offset = self.offset + @sizeOf(@TypeOf(sym)) * self.index;
                try self.parse_source.seekableStream().seekTo(offset);
                try self.parse_source.reader().readNoEof(std.mem.asBytes(&sym));

                if (self.elf_header.endian == native_endian) return sym;

                mem.byteSwapAllFields(Elf64_Sym, &sym);
                return sym;
            }

            var sym: Elf32_Sym = undefined;
            const offset = self.offset + @sizeOf(@TypeOf(sym)) * self.index;
            try self.parse_source.seekableStream().seekTo(offset);
            try self.parse_source.reader().readNoEof(std.mem.asBytes(&sym));

            if (self.elf_header.endian != native_endian) mem.byteSwapAllFields(Elf32_Sym, &sym);

            return Elf64_Sym{
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
