//! Micro-benchmark harness for CRC-DF core operations.
//! Measures wall-clock cost of collapse and stabilise.

const std = @import("std");
const field_mod = @import("field");
const collapse_mod = @import("collapse");
const stabilise_mod = @import("stabilise");

const ResonanceField = field_mod.ResonanceField;
const DIM = field_mod.DIM;

const ITERATIONS: u32 = 5000;

pub fn main() !void {
    std.debug.print("CRC-DF Micro-Benchmark\n", .{});
    std.debug.print("DIM = {d}\n", .{DIM});
    std.debug.print("Iterations per measurement = {d}\n\n", .{ITERATIONS});

    // --- Collapse benchmark ---
    {
        var f = ResonanceField.init();
        const text = "dependency conflict resolution path for package libssl and openssl version mismatch on staging";

        const start = std.time.nanoTimestamp();
        var i: u32 = 0;
        while (i < ITERATIONS) : (i += 1) {
            collapse_mod.collapse(&f, text, 1.0);
        }
        const end = std.time.nanoTimestamp();
        const total_ns: u64 = @intCast(end - start);
        const per_op_ns = total_ns / ITERATIONS;

        std.debug.print("collapse:\n", .{});
        std.debug.print("  total   = {d} ns\n", .{total_ns});
        std.debug.print("  per op  = {d} ns\n", .{per_op_ns});
        std.debug.print("  per op  = {d:.3} µs\n\n", .{@as(f64, @floatFromInt(per_op_ns)) / 1000.0});
    }

    // --- Stabilise benchmark ---
    {
        var f = ResonanceField.init();
        collapse_mod.collapse(&f, "initial seed knowledge about the environment", 1.0);

        const query = "how was the dependency conflict resolved last time";
        var settled: [DIM]f64 = undefined;

        const start = std.time.nanoTimestamp();
        var i: u32 = 0;
        while (i < ITERATIONS) : (i += 1) {
            stabilise_mod.stabilise(&f, query, 12, 0.08, &settled);
        }
        const end = std.time.nanoTimestamp();
        const total_ns: u64 = @intCast(end - start);
        const per_op_ns = total_ns / ITERATIONS;

        std.debug.print("stabilise (12 steps):\n", .{});
        std.debug.print("  total   = {d} ns\n", .{total_ns});
        std.debug.print("  per op  = {d} ns\n", .{per_op_ns});
        std.debug.print("  per op  = {d:.3} µs\n\n", .{@as(f64, @floatFromInt(per_op_ns)) / 1000.0});
    }

    // --- Combined observe+recall style cost ---
    {
        var f = ResonanceField.init();
        const obs = "user resolved package conflict by pinning openssl to 3.0.12 and rebuilding the container";
        const query = "openssl dependency problem";
        var settled: [DIM]f64 = undefined;

        const start = std.time.nanoTimestamp();
        var i: u32 = 0;
        while (i < ITERATIONS) : (i += 1) {
            collapse_mod.collapse(&f, obs, 1.0);
            stabilise_mod.stabilise(&f, query, 12, 0.08, &settled);
        }
        const end = std.time.nanoTimestamp();
        const total_ns: u64 = @intCast(end - start);
        const per_op_ns = total_ns / ITERATIONS;

        std.debug.print("collapse + stabilise (combined):\n", .{});
        std.debug.print("  total   = {d} ns\n", .{total_ns});
        std.debug.print("  per op  = {d} ns\n", .{per_op_ns});
        std.debug.print("  per op  = {d:.3} µs\n", .{@as(f64, @floatFromInt(per_op_ns)) / 1000.0});
    }

    std.debug.print("\nDone.\n", .{});
}
