const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const StringHashMap = std.StringHashMap;
const File = std.fs.File;
const stdelf = std.elf;
const Elf64_Sym = stdelf.Elf64_Sym;
const Elf64_Section = stdelf.Elf64_Section;
const Elf64_Shdr = stdelf.Elf64_Shdr;
const Mutex = std.Thread.Mutex;

const ElfFile = @import("ElfFile.zig");

pub const Index = u32;

pub const Symbols = struct {
    symbols: ArrayList(*Node),
    entry: Index, // should this be included or is this always the first because its the entry?
    elf: ElfFile,

    pub fn init(elf: ElfFile, allocator: Allocator) !Symbols {
        var symbols = ArrayList(*Node).init(allocator);

        return Symbols{
            .symbols = symbols,
            .elf = elf,
        };
    }

    pub fn get(self: Symbols, index: Index) ?*Node {
        if (index >= self.symbols.items.len) return null;
        return self.symbols.items[index];
    }
};

pub const Node = struct {
    pub const ChildrenArray = ArrayList(Index);

    info: Elf64_Section,
    children: ChildrenArray,

    pub fn init(self: *Node, info: Elf64_Section, allocator: Allocator) Node {
        self.children = ChildrenArray.init(allocator);
        self.info = info;
    }
};

pub fn symbolBinding(sym: Elf64_Sym) u8 {
    return sym.st_info >> 4;
}

pub fn symbolType(sym: Elf64_Sym) u8 {
    return sym.st_info & 0x0f;
}

const SectionName = usize;

const SectionDeps = struct {
    deps: ArrayList(SectionName),

    pub fn init(allocator: Allocator) !SectionDeps {
        var deps = ArrayList(SectionName).init(allocator);
        return SectionDeps{
            .deps = deps,
        };
    }
    
    pub fn addDependency(self: *SectionDeps, dep: SectionName) !void {
        self.deps.append(dep);
    }
};

pub const SectionMap = AutoHashMap(SectionName, SectionDeps);
// IDEA: priority queue, that has a separate thread so that stuff that we dont need rn can still be computed for later (for example symbols that we dont need to calculate stuff rn for them because they arent in a, current, path from the seed function).

pub fn RelocationSectionIterator(comptime ParseSource: anytype) type {
    return struct {
        parse_source: ParseSource,
        offset: usize,
        index: u32,

        
    };
}

// TODO: find better name
pub fn worker(elf: ElfFile, map: *SectionMap, section_index: SectionName, allocator: Allocator) !void {
    _ = map;
    _ = elf;
    _ = section_index;
    _ = allocator;

    // var deps = SectionDeps.init(allocator);

    // step 1: find our rela section (maybe with a RelocationSectionIterator?).
    // step 2: add to deps.

    // map.put(section_index, deps);
}

// TODO: generally rewrite this somehow better, its ugly.
const Sections = struct {
    sections: ArrayList(Elf64_Shdr),
    type_map: AutoHashMap(usize, ArrayList(SectionName)),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Sections {
        return Sections{
            .sections = ArrayList(Elf64_Shdr).init(allocator),
            .type_map = AutoHashMap(usize, ArrayList(SectionName)).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn append(self: *Sections, section: Elf64_Shdr) !void {
        try self.sections.append(section);
        // NOTE: is it possible to do this like rust's entry api?
        const curr_section = self.numSections() - 1;
        var entry = self.type_map.getPtr(section.sh_type);
        if (entry) |e| {
            try e.append(curr_section);
        } else {
            var arr = ArrayList(SectionName).init(self.allocator);
            try self.type_map.put(curr_section, arr);
        }
    }

    pub fn getSection(self: Sections, name: SectionName) ?Elf64_Shdr {
        if (name >= self.numSections()) return null;
        return self.sections.items[name];
    }

    pub fn getSectionsOf(self: Sections, section_type: u32) ?ArrayList(SectionName) {
        return self.type_map.get(section_type);
    }

    pub fn numSections(self: Sections) usize {
        return self.sections.items.len;
    }
};

fn parseSectionHeader(elf: ElfFile, allocator: Allocator) !Sections {
    var sh = Sections.init(allocator);

    var iter = elf.sectionHeaderIter();
    var i: SectionName = 0;
    while (try iter.next()) |section| : (i += 1) {
        try sh.append(section);
    }
    std.log.info("{any}", .{sh});
    return sh;
}

// pub const SymbolMap = struct {
//     map: StringHashMap([]Elf64_Sym),
//     allocator: Allocator,
//     mutex: Mutex,
//
//     pub fn init(allocator: Allocator) SymbolMap {
//         return SymbolMap{
//             .allocator = allocator,
//             .map = StringHashMap([]Elf64_Sym).init(allocator),
//         };
//     }
//
//     pub fn addDefinition(self: *SymbolMap, name: []const u8, sym: Elf64_Sym) !void {
//         const sym_arr = self.allocator.alloc(Elf64_Sym, 1);
//         var entry = self.map.getOrPutValue(name, sym);
//         self.map.put(name, sym);
//     }
// };

pub fn Protected(comptime T: type) type {
    return struct {
        map: T,
        mutex: Mutex,

        pub fn init(allocator: Allocator) @This() {
            return .{
                .map  = T.init(allocator),
                .mutex = Mutex{},
            };
        }

        pub fn lockGet(self: *@This()) T {
            self.mutex.lock();
            return self.map;
        }

        pub fn release(self: *@This()) void {
            self.mutex.unlock();
        }
    };
}

pub fn main() anyerror!void {
    std.log.info("good", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    var elf = try ElfFile.init(try std.fs.cwd().openFile("poop2.o", .{}));

    std.log.info("{}", .{elf});

    var phi = elf.sectionHeaderIter();
    while (try phi.next()) |ph| {
        std.log.info("{}", .{ph});
    }
    var a = try elf.symbolIter();
    while (try a.next()) |sym| {
        std.log.info("{any} {} {}", .{ sym, symbolBinding(sym), symbolType(sym) });
    }

    // const SymbolMap = ProtectedMap(StringHashMap(ArrayList(Elf64_Sym)));
    // var symbol_map = SymbolMap.init(allocator);
    // symbol_map.lockGet().put(ArrayList(Elf64_Sym).init(allocator));
    // symbol_map.lockGet().getOrPutValue("poop", );
    // symbol_map.release();

    const section_header = try parseSectionHeader(elf, allocator);

    var section_map = SectionMap.init(allocator);

    var i: u8 = 0;
    std.log.info("heh", .{});
    while (i < section_header.numSections()) : (i += 1) {
        try worker(elf, &section_map, i, allocator);
    }
}
