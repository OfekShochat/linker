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
    little = 1,
    big,
};

pub const OsAbi = enum(u8) {
    sysv,
    hpux,
    standalone = 255,
};

pub const Machine = enum(u16) {
    none = 0,
    sparc = 2,
    i386 = 3,
    sparc32plus = 18,
    sparcv9 = 43,
    amd64 = 62,
};

magic: [4]u8 = .{ 0x7F, 0x45, 0x4c, 0x46 }, // always should be \x7fELF. is this necessary?
class: BitContext,
endianness: Endianness,
abi: OsAbi,
abi_version: u8 = 1,

elf_type: ElfType,
machine: Machine,
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
    std.log.info("{any}", .{ident});
    if (!mem.eql(u8, ident[0..4], &.{ 0x7F, 0x45, 0x4c, 0x46 })) {
        return error.InvalidMagic;
    }
    self.class = try checkedInit(BitContext, ident[4]);

    self.endianness = try checkedInit(Endianness, ident[5]);

    self.abi = try checkedInit(OsAbi, ident[7]);

    self.abi_version = ident[8];

    self.elf_type = try checkedInit(ElfType, try buf.readU16());

    self.machine = try checkedInit(Machine, try buf.readU16());

    self.entry = try buf.readU64();
    self.phoff = try buf.readU64();
    self.shoff = try buf.readU64();

    self.flags = SectionAttr.init(try buf.readU64());

    self.hdr_size = try buf.readU16();
    self.phent_size = try buf.readU16();
    self.phnum = try buf.readU16();
    self.shent_size = try buf.readU16();
    self.shnum = try buf.readU16();
    self.shstrndx = try buf.readU16();

    self.section_index = try checkedInit(SectionIndex, try buf.readU16());
}
