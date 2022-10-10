const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const extension = fs.path.extension;
const Stack = std.atomic.Stack;
const Allocator = mem.Allocator;

const ThreadPool = @import("ThreadPool.zig");
const WaitGroup = @import("WaitGroup.zig");
const lto = @import("lto.zig");
const llvm = lto.llvm;
// const ErrorStack = @import("ErrorStack.zig");
// const WorkList = @import("")

pub const Error = enum {
    load_symbols,
};

const ErrorStack = Stack(Error);
const WorkList = Stack(void);

const Loading = @This();

error_stack: ErrorStack,
allocator: Allocator,
// : WorkList,

pub fn init(allocator: Allocator) Loading {
    return Loading{
        .error_stack = ErrorStack.init(),
        .allocator = allocator,
    };
}

pub fn start(self: *Loading, thread_pool: *ThreadPool, paths: []const []const u8) !void {
    var wg = WaitGroup{};

    for (paths) |path| {
        wg.start();
        try thread_pool.spawn(workerLoadSymbols, .{ self, path, &wg });
    }

    // _ = paths;
    // wg.start();
    // try thread_pool.spawn(workerLoadSymbols, .{ self, "poop.bc", &wg });
    // wg.start();
    // try thread_pool.spawn(workerLoadSymbols, .{ self, "hi.bc", &wg });
    wg.wait();

    // maybe not only loading?
}

pub fn pushErr(self: *Loading, err: Error) void {
    var node = self.allocator.create(ErrorStack.Node) catch @panic("Could not allocate on error.");
    node.next = null;
    node.data = err;

    self.error_stack.push(node);
}

pub fn workerLoadSymbols(self: *Loading, path: []const u8, wg: *WaitGroup) void {
    defer wg.finish();

    self.loadSymbols(path) catch {
        self.pushErr(.load_symbols);
    };
}

fn loadSymbols(self: *Loading, path: []const u8) !void {
    if (mem.eql(u8, extension(path), ".bc")) {
        const mod = try llvm.Module.load(path);
        defer mod.deinit();
        try self.loadSymbolsFromModule(mod);
    } else if (mem.eql(u8, extension(path), ".o")) {
        // TODO: use the magic instead of extension.
    }
}

pub fn loadSymbolsFromModule(self: *Loading, module: anytype) !void {
    var iter = try module.symbolIter(self.allocator);

    while (try iter.next()) |sym| {
        std.log.info("{}", .{sym});
        if (!sym.isUndefined()) {
            // try self.symmap.putMutex(sym, self.allocator);
        }
    }
}
