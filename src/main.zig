//! CRC-DF CLI — Phase 2 foundation (trajectory-aware recall)
//! Requires Zig 0.16+ (process.Init / juicy main).

const std = @import("std");
const field_mod = @import("field");
const collapse_mod = @import("collapse");
const stabilise_mod = @import("stabilise");
const store_mod = @import("store");

const ResonanceField = field_mod.ResonanceField;
const DIM = field_mod.DIM;
const LOG_CAPACITY = field_mod.LOG_CAPACITY;
const FP_LEN = field_mod.FP_LEN;
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
        \\  observe "<text>" [strength]   irreversibly collapse observation
        \\  recall  "<query>"             stabilise + recover trajectory / nearest
        \\  stats                         field statistics + recent collapse log
        \\  sleep   [cycles]              selective geometric pressure
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

fn entryText(entry: CollapseEntry) []const u8 {
    var len: usize = 0;
    while (len < FP_LEN and entry.fingerprint[len] != 0) : (len += 1) {}
    return entry.fingerprint[0..len];
}

fn startsWithInsensitive(hay: []const u8, needle: []const u8) bool {
    if (hay.len < needle.len) return false;
    var i: usize = 0;
    while (i < needle.len) : (i += 1) {
        const a = std.ascii.toLower(hay[i]);
        const b = std.ascii.toLower(needle[i]);
        if (a != b) return false;
    }
    return true;
}

fn roleWeight(text: []const u8) f64 {
    if (startsWithInsensitive(text, "resolution")) return 0.08;
    if (startsWithInsensitive(text, "verification")) return 0.07;
    if (startsWithInsensitive(text, "note")) return 0.06;
    if (startsWithInsensitive(text, "diagnosis")) return 0.03;
    if (startsWithInsensitive(text, "attempted")) return 0.02;
    if (startsWithInsensitive(text, "error")) return 0.01;
    return 0.0;
}

fn isResolutionish(text: []const u8) bool {
    return startsWithInsensitive(text, "resolution") or
        startsWithInsensitive(text, "verification") or
        startsWithInsensitive(text, "note");
}

fn decodeTrajectory(settled: *const [DIM]f64, log_entries: []const CollapseEntry) void {
    if (log_entries.len == 0) {
        std.debug.print("  (no entries in collapse log)\n", .{});
        return;
    }

    var scores: [LOG_CAPACITY]struct { score: f64, idx: usize } = undefined;
    var n: usize = 0;

    for (log_entries, 0..) |entry, i| {
        const text = entryText(entry);
        if (text.len == 0) continue;
        var vec: [DIM]f64 = undefined;
        collapse_mod.textToVector(text, &vec);
        const sim = stabilise_mod.cosine(settled, &vec);
        const combined = sim + 0.02 * @as(f64, entry.strength) + roleWeight(text);
        scores[n] = .{ .score = combined, .idx = i };
        n += 1;
    }
    if (n == 0) {
        std.debug.print("  (no usable fingerprints — run reset + observe again)\n", .{});
        return;
    }

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

    var anchor_idx = scores[0].idx;
    const top_score = scores[0].score;
    var s: usize = 0;
    while (s < @min(n, 5)) : (s += 1) {
        const e = log_entries[scores[s].idx];
        const t = entryText(e);
        if (isResolutionish(t) and scores[s].score >= top_score - 0.05) {
            anchor_idx = scores[s].idx;
            break;
        }
    }
    const anchor_seq = log_entries[anchor_idx].sequence;

    var traj: [LOG_CAPACITY]usize = undefined;
    var traj_n: usize = 0;
    for (log_entries, 0..) |entry, i| {
        const seq = entry.sequence;
        if (seq + 4 < anchor_seq) continue;
        if (seq > anchor_seq + 2) continue;
        traj[traj_n] = i;
        traj_n += 1;
    }

    var i: usize = 0;
    while (i < traj_n) : (i += 1) {
        var best = i;
        var j = i + 1;
        while (j < traj_n) : (j += 1) {
            if (log_entries[traj[j]].sequence < log_entries[traj[best]].sequence) best = j;
        }
        if (best != i) {
            const tmp = traj[i];
            traj[i] = traj[best];
            traj[best] = tmp;
        }
    }

    std.debug.print("  recovered trajectory (chronological):\n", .{});
    if (traj_n == 0) {
        std.debug.print("    (empty)\n", .{});
    } else {
        var k: usize = 0;
        while (k < traj_n) : (k += 1) {
            const entry = log_entries[traj[k]];
            const fp = entryText(entry);
            var vec: [DIM]f64 = undefined;
            collapse_mod.textToVector(fp, &vec);
            const sim = stabilise_mod.cosine(settled, &vec);
            std.debug.print("    [{d}] sim={d:.3}  strength={d:.2}  \"{s}\"\n", .{
                entry.sequence,
                sim,
                entry.strength,
                fp,
            });
        }
    }

    std.debug.print("  top geometric hits:\n", .{});
    const show = @min(@as(usize, 3), n);
    var k: usize = 0;
    while (k < show) : (k += 1) {
        const entry = log_entries[scores[k].idx];
        const fp = entryText(entry);
        var vec: [DIM]f64 = undefined;
        collapse_mod.textToVector(fp, &vec);
        const sim = stabilise_mod.cosine(settled, &vec);
        std.debug.print("    [{d}] sim={d:.3}  strength={d:.2}  \"{s}\"\n", .{
            entry.sequence,
            sim,
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

    var buf: [LOG_CAPACITY]CollapseEntry = undefined;
    const n = f.recentCollapses(&buf);
    decodeTrajectory(&settled, buf[0..n]);
}

fn cmdStats() !void {
    const f = try loadOrInit();
    std.debug.print("CRC-DF field statistics\n", .{});
    std.debug.print("  dimension       = {d}\n", .{DIM});
    std.debug.print("  collapse_count  = {d}\n", .{f.collapse_count});
    std.debug.print("  norm            = {d:.6}\n", .{f.norm()});
    std.debug.print("  log capacity    = {d}\n", .{LOG_CAPACITY});
    std.debug.print("  log entries     = {d}\n", .{f.log_len});
    std.debug.print("  fingerprint len = {d}\n", .{FP_LEN});

    if (f.log_len > 0) {
        var buf: [LOG_CAPACITY]CollapseEntry = undefined;
        const n = f.recentCollapses(&buf);
        std.debug.print("\n  recent collapses (oldest → newest):\n", .{});
        var i: usize = 0;
        while (i < n) : (i += 1) {
            const e = buf[i];
            const fp = entryText(e);
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

    var reinforced: u32 = 0;
    var c: u32 = 0;
    while (c < cycles) : (c += 1) {
        var i: usize = 0;
        while (i < n) : (i += 1) {
            const e = buf[i];
            if (e.strength < 0.8) continue;
            const text = entryText(e);
            if (text.len == 0) continue;
            collapse_mod.collapse(&f, text, 0.10 * @as(f64, e.strength));
            reinforced += 1;
        }
    }

    try store_mod.save(&f, STORE_PATH);
    std.debug.print("sleep completed ({d} cycles, {d} reinforcements). collapse_count now = {d}\n", .{
        cycles,
        reinforced,
        f.collapse_count,
    });
}

fn cmdReset() !void {
    const f = ResonanceField.init();
    try store_mod.save(&f, STORE_PATH);
    std.debug.print("field reset to initial state\n", .{});
}
