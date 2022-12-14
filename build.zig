const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const exe = b.addExecutable("linker", "src/main2.zig");
    exe.setBuildMode(mode);
    exe.linkLibC();
    exe.addIncludePath("/home/ghostway/projects/cpp/llvm-project/llvm/include/llvm-c/");
    // exe.addLibraryPath("/home/ghostway/projects/cpp/llvm-project/build/lib/");
    exe.addLibraryPath("/home/ghostway/projects/cpp/llvm-project/build/lib/"); //libLTO.so")
    exe.linkSystemLibrary("LTO");
    exe.install();
    exe.setTarget(target);

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
