const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("zerve", .{
        .root_source_file = .{ .path = "src/zerve.zig" },
    });

    const lib = b.addStaticLibrary(.{
        .name = "zerve",
        .root_source_file = .{ .path = "src/zerve.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/zerve.zig" },
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
