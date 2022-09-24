const std = @import("std");
const File = std.fs.File;
const ElfFile = @import("ElfFile.zig");

pub fn main() anyerror!void {
    std.log.info("good", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    _ = gpa;
    var elf = try ElfFile.init(try std.fs.cwd().openFile("poop.o", .{}));

    std.log.info("{}", .{elf});

    var phi = elf.sectionHeaderIter(); //.header.section_header_iterator(elf.file);
    var i: u8 = 0;
    while (i < 9) : (i += 1) {
        std.log.info("{}", .{(try phi.next()).?});
    }
    var a = try elf.symbolIter();
    while (try a.next()) |sym| {
        std.log.info("{any}", .{sym});
    }
}
