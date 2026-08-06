//! CRC-DF CLI — Phase 1+ functional foundation
//!
//! Commands:
//!   observe "<text>" [strength]   irreversibly collapse observation
//!   recall  "<query>"             stabilise and report response
//!   stats                         field statistics + recent log
//!   sleep   [cycles]              background optimisation stub (reinforce recent)
//!   reset                         wipe field to initial state

const std = @import("std");
const field_mod = @import("field");
const collapse_mod = @import("collapse");
const stabilise_mod = @import("stabilise");
const store_mod = @import("store");

const ResonanceField = field_mod.ResonanceField;
const DIM = field_mod.DIM;
const LOG_CAPACITY = field_mod.LOG_CAPACITY;

const STORE_PATH = "crc_df_field.bin";

pub fn main(init: std.process.Init) !void {
    var args = try init.minimal.args.iterateAllocator(init.gpa);
    defer args.deinit();

    _ = args.next(); // skip program name

    const cmd = args.next() orelse {
        printUsage();
        return;
    };

    if (std.mem.eql(u8, cmd, "observe")) {
        const text = args.next() orelse {
            std.debug.print("usage: crc-df observe \"<text>\" [strength]\n", .{});
            return;
        };
        var strength: f64 = 1.0;
        if (args.next()) |s| {
            strength = std.fmt.parseFloat(f64, s) catch 1.0;
        }
        try cmdObserve(text, strength);
    } else if (std.mem.eql(u8, cmd, "recall")) {
        const query = args.next() orelse {
            std.debug.print("usage: crc-df recall \"<query>\"\n", .{});
            return;
        };
        try cmdRecall(query);
    } else if (std.mem.eql(u8, cmd, "stats")) {
        try cmdStats();
    } else if (std.mem.eql(u8, cmd, "sleep")) {
        var cycles: u32 = 3;
        if (args.next()) |c| {
            cycles = std.fmt.parseInt(u32, c, 10) catch 3;
        }
        try cmdSleep(cycles);
    } else if (std.mem.eql(u8, cmd, "reset")) {
        try cmdReset();
    } else {
        printUsage();
    }
}

fn printUsage() void {
    std.debug.print(
        \\CRC-DF — Campo de Resonancia Colapsable de Dimensión Fija
        \\
        \\Commands:
        \\  observe "<text>" [strength]   irreversibly collapse observation (default strength 1.0)
        \\  recall  "<query>"             stabilise under query and report field response
        \\  stats                         show field statistics + recent collapse log
        \\  sleep   [cycles]              background optimisation (reinforce recent useful collapses)
        \\  reset                         wipe field back to initial state
        \\
        ,
        .{},
    );
}

fn loadOrInit() !ResonanceField {
    return store_mod.load(STORE_PATH) catch ResonanceField.init();
}

fn cmdObserve(text: []const u8, strength: f64) !void {
    var f = try loadOrInit();
    const before_norm = f.norm();
    collapse_mod.collapse(&f, text, strength);
    try store_mod.save(&f, STORE_PATH);
    std.debug.print("collapsed (strength={d:.2}, count now = {d}, norm {d:.4} → {d:.4})\n", .{
        strength,
        f.collapse_count,
        before_norm,
        f.norm(),
    });
}

fn cmdRecall(query: []const u8) !void {
    const f = try loadOrInit();
    var settled: [DIM]f64 = undefined;
    const metrics = stabilise_mod.stabiliseWithMetrics(&f, query, 16, 0.07, &settled);

    std.debug.print("recall metrics:\n", .{});
    std.debug.print("  cosine(state, settled) = {d:.4}\n", .{metrics.cosine_to_state});
    std.debug.print("  residual energy        = {d:.6}\n", .{metrics.residual_energy});
    std.debug.print("  steps                  = {d}\n", .{metrics.steps_done});
    std.debug.print("  field norm             = {d:.4}\n", .{f.norm()});
    std.debug.print("  total collapses        = {d}\n", .{f.collapse_count});

    // Simple diagnostic: show the strongest dimensions of the settled vector
    std.debug.print("  top dimensions of settled state:\n", .{});
    var top_idx: [5]usize = .{ 0, 1, 2, 3, 4 };
    var top_val: [5]f64 = .{ -1e9, -1e9, -1e9, -1e9, -1e9 };
    for (0..DIM) |i| {
        const v = @abs(settled[i]);
        if (v > top_val[4]) {
            top_val[4] = v;
            top_idx[4] = i;
            // bubble sort the top-5
            var k: usize = 4;
            while (k > 0 and top_val[k] > top_val[k - 1]) : (k -= 1) {
                const tmpv = top_val[k - 1];
                top_val[k - 1] = top_val[k];
                top_val[k] = tmpv;
                const tmpi = top_idx[k - 1];
                top_idx[k - 1] = top_idx[k];
                top_idx[k] = tmpi;
            }
        }
    }
    for (0..5) |j| {
        std.debug.print("    dim[{d}] = {d:.4}\n", .{ top_idx[j], settled[top_idx[j]] });
    }
}

fn cmdStats() !void {
    const f = try loadOrInit();
    std.debug.print("CRC-DF field statistics\n", .{});
    std.debug.print("  dimension       = {d}\n", .{DIM});
    std.debug.print("  collapse_count  = {d}\n", .{f.collapse_count});
    std.debug.print("  norm            = {d:.6}\n", .{f.norm()});
    std.debug.print("  log capacity    = {d}\n", .{LOG_CAPACITY});
    std.debug.print("  log entries     = {d}\n", .{f.log_len});

    if (f.log_len > 0) {
        var buf: [LOG_CAPACITY]field_mod.CollapseEntry = undefined;
        const n = f.recentCollapses(&buf);
        std.debug.print("\n  recent collapses (oldest → newest):\n", .{});
        var i: usize = 0;
        while (i < n) : (i += 1) {
            const e = buf[i];
            // find null terminator or end
            var len: usize = 0;
            while (len < 48 and e.fingerprint[len] != 0) : (len += 1) {}
            const fp = e.fingerprint[0..len];
            std.debug.print("    [{d}] strength={d:.2}  \"{s}\"\n", .{ e.sequence, e.strength, fp });
        }
    }
}

/// Sleep loop stub (Phase 3 foundation).
/// For now: mild re-collapse of the most recent high-strength entries
/// with reduced strength → reinforces useful deformations without unbounded growth.
fn cmdSleep(cycles: u32) !void {
    var f = try loadOrInit();
    if (f.log_len == 0) {
        std.debug.print("sleep: nothing in the collapse log yet\n", .{});
        return;
    }

    var buf: [LOG_CAPACITY]field_mod.CollapseEntry = undefined;
    const n = f.recentCollapses(&buf);

    var c: u32 = 0;
    while (c < cycles) : (c += 1) {
        // Reinforce the last few high-strength collapses lightly
        var i: usize = if (n > 6) n - 6 else 0;
        while (i < n) : (i += 1) {
            const e = buf[i];
            if (e.strength < 0.4) continue;
            var len: usize = 0;
            while (len < 48 and e.fingerprint[len] != 0) : (len += 1) {}
            const text = e.fingerprint[0..len];
            // very mild reinforcement
            collapse_mod.collapse(&f, text, 0.12);
        }
    }

    try store_mod.save(&f, STORE_PATH);
    std.debug.print("sleep completed ({d} cycles). collapse_count now = {d}\n", .{ cycles, f.collapse_count });
}

fn cmdReset() !void {
    const f = ResonanceField.init();
    try store_mod.save(&f, STORE_PATH);
    std.debug.print("field reset to initial state\n", .{});
}
