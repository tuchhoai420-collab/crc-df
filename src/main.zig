//! Minimal CLI for the CRC-DF operator.

const std = @import("std");
const field_mod = @import("field.zig");
const collapse_mod = @import("collapse.zig");
const stabilise_mod = @import("stabilise.zig");
const store_mod = @import("store.zig");

const ResonanceField = field_mod.ResonanceField;
const DIM = field_mod.DIM;

const STORE_PATH = "crc_df_field.bin";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next(); // skip program name

    const cmd = args.next() orelse {
        try printUsage();
        return;
    };

    if (std.mem.eql(u8, cmd, "observe")) {
        const text = args.next() orelse {
            std.debug.print("usage: crc-df observe \"<text>\"\n", .{});
            return;
        };
        try cmdObserve(text);
    } else if (std.mem.eql(u8, cmd, "recall")) {
        const query = args.next() orelse {
            std.debug.print("usage: crc-df recall \"<query>\"\n", .{});
            return;
        };
        try cmdRecall(query);
    } else if (std.mem.eql(u8, cmd, "stats")) {
        try cmdStats();
    } else {
        try printUsage();
    }
}

fn printUsage() !void {
    const out = std.io.getStdOut().writer();
    try out.writeAll(
        \\CRC-DF — Campo de Resonancia Colapsable de Dimensión Fija
        \\
        \\Commands:
        \\  observe "<text>"   irreversibly collapse observation into the field
        \\  recall  "<query>"  stabilise under query and report field response
        \\  stats              show current field statistics
        \\
    );
}

fn loadOrInit() !ResonanceField {
    return store_mod.load(STORE_PATH) catch ResonanceField.init();
}

fn cmdObserve(text: []const u8) !void {
    var f = try loadOrInit();
    collapse_mod.collapse(&f, text, 1.0);
    try store_mod.save(&f, STORE_PATH);
    std.debug.print("collapsed (count now = {d})\n", .{f.collapse_count});
}

fn cmdRecall(query: []const u8) !void {
    const f = try loadOrInit();
    var settled: [DIM]f64 = undefined;
    stabilise_mod.stabilise(&f, query, 12, 0.08, &settled);

    // Simple response: report cosine with the current permanent state
    // and a few diagnostic numbers. A full generative head can be added later.
    const sim = stabilise_mod.cosine(&f.state, &settled);
    std.debug.print("settled. cosine(state, settled) = {d:.4}\n", .{sim});
    std.debug.print("field norm = {d:.4}, collapses = {d}\n", .{ f.norm(), f.collapse_count });
}

fn cmdStats() !void {
    const f = try loadOrInit();
    std.debug.print("dim            = {d}\n", .{DIM});
    std.debug.print("collapse_count = {d}\n", .{f.collapse_count});
    std.debug.print("norm           = {d:.6}\n", .{f.norm()});
}
