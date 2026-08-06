const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Core library module (shared by executable and tests)
    const field_mod = b.addModule("field", .{
        .root_source_file = b.path("src/field.zig"),
        .target = target,
        .optimize = optimize,
    });

    const collapse_mod = b.addModule("collapse", .{
        .root_source_file = b.path("src/collapse.zig"),
        .target = target,
        .optimize = optimize,
    });
    collapse_mod.addImport("field", field_mod);

    const stabilise_mod = b.addModule("stabilise", .{
        .root_source_file = b.path("src/stabilise.zig"),
        .target = target,
        .optimize = optimize,
    });
    stabilise_mod.addImport("field", field_mod);
    stabilise_mod.addImport("collapse", collapse_mod);

    const store_mod = b.addModule("store", .{
        .root_source_file = b.path("src/store.zig"),
        .target = target,
        .optimize = optimize,
    });
    store_mod.addImport("field", field_mod);

    // Executable
    const exe = b.addExecutable(.{
        .name = "crc-df",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("field", field_mod);
    exe.root_module.addImport("collapse", collapse_mod);
    exe.root_module.addImport("stabilise", stabilise_mod);
    exe.root_module.addImport("store", store_mod);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the CRC-DF CLI");
    run_step.dependOn(&run_cmd.step);

    // Property tests (Phase 1)
    const tests = b.addTest(.{
        .root_source_file = b.path("tests/property_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.root_module.addImport("field", field_mod);
    tests.root_module.addImport("collapse", collapse_mod);
    tests.root_module.addImport("stabilise", stabilise_mod);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run Phase 1 property tests");
    test_step.dependOn(&run_tests.step);
}
