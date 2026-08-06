const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Core modules
    const field_mod = b.createModule(.{
        .root_source_file = b.path("src/field.zig"),
        .target = target,
        .optimize = optimize,
    });

    const collapse_mod = b.createModule(.{
        .root_source_file = b.path("src/collapse.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &{
            .{ .name = "field", .module = field_mod },
        },
    });

    const stabilise_mod = b.createModule(.{
        .root_source_file = b.path("src/stabilise.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &{
            .{ .name = "field", .module = field_mod },
            .{ .name = "collapse", .module = collapse_mod },
        },
    });

    const store_mod = b.createModule(.{
        .root_source_file = b.path("src/store.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &{
            .{ .name = "field", .module = field_mod },
        },
    });

    // Main executable
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &{
            .{ .name = "field", .module = field_mod },
            .{ .name = "collapse", .module = collapse_mod },
            .{ .name = "stabilise", .module = stabilise_mod },
            .{ .name = "store", .module = store_mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "crc-df",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the CRC-DF CLI");
    run_step.dependOn(&run_cmd.step);

    // Benchmark executable (always ReleaseFast)
    const bench_mod = b.createModule(.{
        .root_source_file = b.path("src/bench.zig"),
        .target = target,
        .optimize = .ReleaseFast,
        .imports = &{
            .{ .name = "field", .module = field_mod },
            .{ .name = "collapse", .module = collapse_mod },
            .{ .name = "stabilise", .module = stabilise_mod },
        },
    });

    const bench_exe = b.addExecutable(.{
        .name = "crc-df-bench",
        .root_module = bench_mod,
    });
    b.installArtifact(bench_exe);

    const bench_cmd = b.addRunArtifact(bench_exe);
    bench_cmd.step.dependOn(b.getInstallStep());
    const bench_step = b.step("bench", "Run micro-benchmarks (collapse + stabilise)");
    bench_step.dependOn(&bench_cmd.step);

    // Property tests
    const test_mod = b.createModule(.{
        .root_source_file = b.path("tests/property_tests.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &{
            .{ .name = "field", .module = field_mod },
            .{ .name = "collapse", .module = collapse_mod },
            .{ .name = "stabilise", .module = stabilise_mod },
        },
    });

    const tests = b.addTest(.{
        .root_module = test_mod,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run Phase 1 property tests");
    test_step.dependOn(&run_tests.step);
}
