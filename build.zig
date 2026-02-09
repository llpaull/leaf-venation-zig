const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // EXECUTABLE
    const exe = b.addExecutable(.{
        .name = "leaves",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.addObjectFile(.{ .cwd_relative = "raylib/src/libraylib.a" });
    exe.addIncludePath(.{ .cwd_relative = "raylib/src" });

    exe.linkSystemLibrary("X11");
    exe.linkSystemLibrary("Xrandr");
    exe.linkSystemLibrary("Xinerama");
    exe.linkSystemLibrary("Xcursor");
    exe.linkSystemLibrary("Xi");

    exe.linkSystemLibrary("wayland-client");
    exe.linkSystemLibrary("wayland-cursor");
    exe.linkSystemLibrary("wayland-egl");

    exe.linkSystemLibrary("EGL");
    exe.linkSystemLibrary("GL");
    exe.linkSystemLibrary("pthread");
    exe.linkSystemLibrary("dl");
    exe.linkSystemLibrary("m");

    exe.linkSystemLibrary("asound");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // TESTING
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
