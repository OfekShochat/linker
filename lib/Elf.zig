const std = @import("std");
const mem = std.mem;
const ElfBuffer = @import("ElfBuffer.zig");

const Header = @This();
// https://uclibc.org/docs/elf-64-gen.pdf

fn checkedInit(comptime T: type, val: anytype) !T {
    inline for (@typeInfo(T).Enum.fields) |f| {
        if (f.value == val) {
            return @intToEnum(T, val);
        }
    }
    return error.Invalid;
}

pub const ElfType = enum(u16) {
    none = 0,
    rel,
    exec,
    dyn,
    core,
    loos = 0xFE00,
    hios = 0xFEEF,
    loproc = 0xFF00,
    hiproc = 0xFFFF,
};

pub const SectionIndex = enum(u16) {
    undef = 0,
    loproc = 0xFF00,
    hiproc = 0xFF1F,
    loos = 0xFF20,
    hios = 0xFF3F,
    abs = 0xFFF1,
    common = 0xFFF2,
};

pub const SectionType = enum(u32) {
    null,
    progbits,
    symtab,
    strtab,
    rela,
    hash,
    dynamic,
    note,
    nobits,
    rel,
    shlib,
    dynsym,
    loos = 0x60000000,
    hios = 0x6FFFFFFF,
    loproc = 0x70000000,
    hiproc = 0x7FFFFFFF,
};

pub const LinkType = enum(u32) {
    undef = SectionIndex.undef,
    dynamic = SectionType.dynamic,
    hash = SectionType.hash,
    rel = SectionType.rel,
    rela = SectionType.rela,
    symtab = SectionType.symtab,
    dynsym = SectionType.dynsym,
};

pub const InfoType = enum(u32) {
    null = 0,
    rel = SectionType.rel,
    rela = SectionType.rela,
    symtab = SectionType.symtab,
    dynsym = SectionType.dynsym,
};

pub const SectionAttr = struct {
    flags: u64,

    pub fn init(flags: u64) SectionAttr {
        return SectionAttr{
            .flags = flags,
        };
    }

    pub fn hasWrite(self: SectionAttr) bool {
        return 0x1 & self.flags;
    }

    pub fn hasAlloc(self: SectionAttr) bool {
        return 0x2 & self.flags;
    }
    
    pub fn hasExecInst(self: SectionAttr) bool {
        return 0x4 & self.flags;
    }

    pub fn hasMaskOs(self: SectionAttr) bool {
        return 0x0F000000 & self.flags;
    }

    pub fn hasMaskProc(self: SectionAttr) bool {
        return 0xF0000000 & self.flags;
    }
};

pub const SectionEntries = struct {
    name: u32,
    section_type: SectionType,
    flags: SectionAttr,
    virt_addr: u64,
    offset: u64,
    size: u64,
    link: SectionType, // not sure
    info: u32,
    addr_align: u64,
    entry_size: u64,
};

pub const BitContext = enum(u8) {
    x86 = 1,
    x64 = 2,
};

pub const Version = union(enum) {
    current,
    other: u32,
};

pub const Endianness = enum(u8) {
    big = 1,
    little,
};

pub const OsAbi = enum(u8) {
    sysv,
    hpux,
    standalone = 255,
};

magic: [4]u8 = .{0x7F, 0x45, 0x4c, 0x46}, // always should be \x7fELF. is this necessary?
class: BitContext,
endianness: Endianness,
abi: OsAbi,
abi_version: u8 = 1,

elf_type: ElfType,
machine: void,
version: Version,
entry: u64,
phoff: u64,
shoff: u64,
flags: SectionAttr,
hdr_size: u16,
phent_size: u16,
phnum: u16,
shent_size: u16,
shnum: u16,
shstrndx: u16,
section_index: SectionIndex,

pub fn parse(self: *Header, buf: *ElfBuffer) !void {
    const ident = try buf.readBytes(16);
    if (mem.eql(u8, ident[0..4], &.{0x7F, 0x45, 0x4c, 0x46})) {
        return error.InvalidMagic;
    }
    self.class = try checkedInit(BitContext, ident[4]);

    // self.endianness = try Endianness.init(ident[5]);

    // self.abi = ident[7];

    const abi_version = ident[8];
    if (abi_version != 1) {
        return error.InvalidAbiVersion;
    }

    // self.elf_type = ElfType.init(try buf.readU8());
}
