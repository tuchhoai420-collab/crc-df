//! C-ABI for CRC-DF
//! Exogenous memory substrate — callable from llama.cpp, Python, any C host.
//!
//! Design stance (alien):
//! - No understanding, no narrative, no self.
//! - Only irreversible geometric deformation + selective pressure.
//! - The host model is just another source of observations and queries.

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

var g_field: ResonanceField = undefined;
var g_initialised: bool = false;
var g_store_path: [512]u8 = undefined;
var g_store_path_len: usize = 0;

fn ensureInit() void {
    if (!g_initialised) {
        g_field = ResonanceField.init();
        g_initialised = true;
        // default path
        const default = "crc_df_field.bin";
        @memcpy(g_store_path[0..default.len], default);
        g_store_path_len = default.len;
    }
}

fn storePath() []const u8 {
    return g_store_path[0..g_store_path_len];
}

fn persist() void {
    store_mod.save(&g_field, storePath()) catch {};
}

fn reload() void {
    g_field = store_mod.load(storePath()) catch ResonanceField.init();
    g_initialised = true;
}

// ---------------------------------------------------------------------------
// Public C API
// ---------------------------------------------------------------------------

export fn crc_set_store_path(path: [*:0]const u8) void {
    ensureInit();
    const span = std.mem.span(path);
    const n = @min(span.len, g_store_path.len - 1);
    @memcpy(g_store_path[0..n], span[0..n]);
    g_store_path_len = n;
    g_store_path[n] = 0;
}

export fn crc_load() i32 {
    ensureInit();
    g_field = store_mod.load(storePath()) catch {
        g_field = ResonanceField.init();
        return -1;
    };
    return 0;
}

export fn crc_save() i32 {
    ensureInit();
    store_mod.save(&g_field, storePath()) catch return -1;
    return 0;
}

/// Irreversible observation. strength typically 0.3–2.0
export fn crc_observe(text: [*:0]const u8, strength: f64) void {
    ensureInit();
    const span = std.mem.span(text);
    collapse_mod.collapse(&g_field, span, strength);
    persist();
}

/// Recall: stabilise under query and write top-k decoded observations
/// into out_buf as newline-separated text. Returns number of lines written.
/// out_buf_len is capacity in bytes.
export fn crc_recall(query: [*:0]const u8, out_buf: [*]u8, out_buf_len: usize, top_k: u32) i32 {
    ensureInit();
    const q = std.mem.span(query);

    var settled: [DIM]f64 = undefined;
    _ = stabilise_mod.stabiliseWithMetrics(&g_field, q, 16, 0.07, &settled);

    var log_buf: [LOG_CAPACITY]CollapseEntry = undefined;
    const nlog = g_field.recentCollapses(&log_buf);
    if (nlog == 0) return 0;

    // score entries
    var scores: [LOG_CAPACITY]struct { score: f64, idx: usize } = undefined;
    var n: usize = 0;
    for (log_buf[0..nlog], 0..) |entry, i| {
        var len: usize = 0;
        while (len < FP_LEN and entry.fingerprint[len] != 0) : (len += 1) {}
        if (len == 0) continue;
        const text = entry.fingerprint[0..len];
        var vec: [DIM]f64 = undefined;
        collapse_mod.textToVector(text, &vec);
        const sim = stabilise_mod.cosine(&settled, &vec);
        const combined = sim + 0.02 * @as(f64, entry.strength);
        scores[n] = .{ .score = combined, .idx = i };
        n += 1;
    }
    if (n == 0) return 0;

    // sort desc
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

    const show = @min(@as(usize, top_k), n);
    var written: usize = 0;
    var lines: i32 = 0;
    var k: usize = 0;
    while (k < show) : (k += 1) {
        const entry = log_buf[scores[k].idx];
        var len: usize = 0;
        while (len < FP_LEN and entry.fingerprint[len] != 0) : (len += 1) {}
        const fp = entry.fingerprint[0..len];

        // need space for text + newline + null safety
        if (written + len + 1 >= out_buf_len) break;
        @memcpy(out_buf[written .. written + len], fp);
        written += len;
        out_buf[written] = '
';
        written += 1;
        lines += 1;
    }
    if (written < out_buf_len) out_buf[written] = 0;
    return lines;
}

/// Alien sleep: selective geometric pressure.
/// - High-strength recent collapses are reinforced (useful deformations deepen).
/// - Low-strength items are ignored (starved of energy).
/// No anthropomorphic reflection. Only differential reinforcement.
export fn crc_sleep(cycles: u32) void {
    ensureInit();
    if (g_field.log_len == 0) return;

    var log_buf: [LOG_CAPACITY]CollapseEntry = undefined;
    const n = g_field.recentCollapses(&log_buf);

    var c: u32 = 0;
    while (c < cycles) : (c += 1) {
        // Reinforce the strongest recent entries
        var i: usize = 0;
        while (i < n) : (i += 1) {
            const e = log_buf[i];
            if (e.strength < 0.8) continue; // starve weak observations
            var len: usize = 0;
            while (len < FP_LEN and e.fingerprint[len] != 0) : (len += 1) {}
            if (len == 0) continue;
            const text = e.fingerprint[0..len];
            // mild but repeated pressure
            collapse_mod.collapse(&g_field, text, 0.10 * @as(f64, e.strength));
        }
    }
    persist();
}

export fn crc_reset() void {
    g_field = ResonanceField.init();
    g_initialised = true;
    persist();
}

export fn crc_collapse_count() u64 {
    ensureInit();
    return g_field.collapse_count;
}

export fn crc_log_len() u32 {
    ensureInit();
    return @intCast(g_field.log_len);
}

export fn crc_norm() f64 {
    ensureInit();
    return g_field.norm();
}
