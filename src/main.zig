//! CRC-DF CLI — Phase 1+ / early Phase 2 foundation
//!
//! Commands:
//!   observe "<text>" [strength]   irreversibly collapse observation
//!   recall  "<query>"             stabilise + decode nearest log entries
//!   stats                         field statistics + recent log
//!   sleep   [cycles]              background optimisation stub
//!   reset                         wipe field to initial state

const std = @import("std");
const field_mod = @import("field");
const collapse_mod = @import("collapse");
const stabilise_mod = @import("stabilise");
const store_mod = @import("store");

const ResonanceField = field_mod.ResonanceField;
const DIM = field_mod.DIM;
const LOG_CAPACITY = field_mod.LOG_CAPACITY;
const CollapseEntry = field_mod.CollapseEntry;

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
        \\  recall  "<query>"             stabilise + return nearest past observations
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

/// Decode: rank recent log entries by cosine similarity of their
/// text-vectors against the settled state. This is the first real
/// trajectory/memory readout.
fn decodeNearest(settled: *const [DIM]f64, log_entries: []const CollapseEntry, top_k: usize) void {
    if (log_entries.len == 0) {
        std.debug.print("  (no entries in collapse log to decode against)\n", .{});
        return;
    }

    // score + index pairs
    var scores: [LOG_CAPACITY]struct { score: f64, idx: usize } = undefined;
    var n: usize = 0;

    for (log_entries, 0..) |entry, i| {
        var len: usize = 0;
        while (len < 48 and entry.fingerprint[len] != 0) : (len += 1) {}
        if (len == 0) continue;

        const text = entry.fingerprint[0..len];
        var vec: [DIM]f64 = undefined;
        collapse_mod.textToVector(text, &vec);

        const sim = stabilise_mod.cosine(settled, &vec);
        scores[n] = .{ .score = sim, .idx = i };
        n += 1;
    }

    if (n == 0) {
        std.debug.print("  (no usable fingerprints)\n", .{});
        return;
    }

    // simple selection sort descending (n ≤ 32)
    var a: usize = 0;
    while (a < n) : (a += 1) {
        var best = a;
        var b = a + 1;
        while (b < n) : (b += 1) {
            if (scores[b].score > scores[best].score) best = b;
        }
        if (best != a) {
            const tmp = scores[a];
            scores[a] = scores[best];
            scores[best] = tmp;
        }
    }

    const show = @min(top_k, n);
    std.debug.print("  nearest past observations (decoded):\n", .{});
    var k: usize = 0;
    while (k < show) : (k += 1) {
        const entry = log_entries[scores[k].idx];
        var len: usize = 0;
        while (len < 48 and entry.fingerprint[len] != 0) : (len += 1) {}
        const fp = entry.fingerprint[0..len];
        std.debug.print("    [{d}] sim={d:.3}  strength={d:.2}  \"{s}\"\n", .{
            entry.sequence,
            scores[k].score,
            entry.strength,
            fp,
        });
    }
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

    // --- Decoding against the bounded log (early trajectory recovery) ---
    var buf: [LOG_CAPACITY]CollapseEntry = undefined;
    const n = f.recentCollapses(&buf);
    decodeNearest(&settled, buf[0..n], 5);
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
        var buf: [LOG_CAPACITY]CollapseEntry = undefined;
        const n = f.recentCollapses(&buf);
        std.debug.print("\n  recent collapses (oldest → newest):\n", .{});
        var i: usize = 0;
        while (i < n) : (i += 1) {
            const e = buf[i];
            var len: usize = 0;
            while (len < 48 and e.fingerprint[len] != 0) : (len += 1) {}
            const fp = e.fingerprint[0..len];
            std.debug.print("    [{d}] strength={d:.2}  \"{s}\"\n", .{ e.sequence, e.strength, fp });
        }
    }
}

fn cmdSleep(cycles: u32) !void {
    var f = try loadOrInit();
    if (f.log_len == 0) {
        std.debug.print("sleep: nothing in the collapse log yet\n", .{});
        return;
    }

    var buf: [LOG_CAPACITY]CollapseEntry = undefined;
    const n = f.recentCollapses(&buf);

    var c: u32 = 0;
    while (c < cycles) : (c += 1) {
        var i: usize = if (n > 6) n - 6 else 0;
        while (i < n) : (i += 1) {
            const e = buf[i];
            if (e.strength < 0.4) continue;
            var len: usize = 0;
            while (len < 48 and e.fingerprint[len] != 0) : (len += 1) {}
            const text = e.fingerprint[0..len];
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
