//! Irreversible collapse operators.
//! A collapse permanently deforms the field. There is no inverse.
//!
//! Phase 1+ improvements:
//! - Richer deterministic text→vector encoder (word hashes + char n-grams)
//! - Optional strength modulation
//! - Automatic recording into the bounded collapse log

const std = @import("std");
const field_mod = @import("field");
const ResonanceField = field_mod.ResonanceField;
const DIM = field_mod.DIM;

/// Improved deterministic, allocation-free text → vector.
/// Mixes:
///   - character unigrams
///   - character bigrams
///   - word-level hashes (split on whitespace/punctuation)
/// Still pure, no external models, fully deterministic.
pub fn textToVector(text: []const u8, out: *[DIM]f64) void {
    @memset(out, 0.0);
    if (text.len == 0) return;

    // Character unigrams + bigrams
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        const ch = std.ascii.toLower(text[i]);
        if (ch < 32) continue; // skip control

        const h1 = @as(usize, @intCast(ch)) % DIM;
        out[h1] += 1.0;

        if (i + 1 < text.len) {
            const ch2 = std.ascii.toLower(text[i + 1]);
            const h2 = (@as(usize, @intCast(ch)) * 31 +% @as(usize, @intCast(ch2))) % DIM;
            out[h2] += 0.55;
        }
        if (i + 2 < text.len) {
            const ch3 = std.ascii.toLower(text[i + 2]);
            const h3 = (@as(usize, @intCast(ch)) * 37 +% @as(usize, @intCast(ch2)) * 13 +% @as(usize, @intCast(ch3))) % DIM;
            out[h3] += 0.30;
        }
    }

    // Word-level hashing (simple whitespace / punctuation split)
    var start: usize = 0;
    var pos: usize = 0;
    while (pos <= text.len) : (pos += 1) {
        const at_end = pos == text.len;
        const is_sep = if (at_end) true else blk: {
            const c = text[pos];
            break :blk std.ascii.isWhitespace(c) or c == ',' or c == '.' or c == ';' or c == ':' or c == '!' or c == '?' or c == '"' or c == '\'';
        };
        if (is_sep) {
            if (pos > start) {
                const word = text[start..pos];
                if (word.len >= 2) {
                    var hash: u64 = 14695981039346656037; // FNV-1a offset
                    for (word) |b| {
                        const lb = std.ascii.toLower(b);
                        hash ^= lb;
                        hash *%= 1099511628211;
                    }
                    const h = @as(usize, @truncate(hash)) % DIM;
                    out[h] += 1.8; // words weigh more than single chars
                    // also hash the reversed word lightly for morphology robustness
                    var rhash: u64 = 14695981039346656037;
                    var k: usize = word.len;
                    while (k > 0) {
                        k -= 1;
                        const lb = std.ascii.toLower(word[k]);
                        rhash ^= lb;
                        rhash *%= 1099511628211;
                    }
                    const rh = @as(usize, @truncate(rhash)) % DIM;
                    out[rh] += 0.6;
                }
            }
            start = pos + 1;
        }
    }

    // L2 normalise
    var sum_sq: f64 = 0.0;
    for (out.*) |v| sum_sq += v * v;
    const n = @sqrt(sum_sq) + 1e-12;
    for (out) |*v| v.* /= n;
}

/// Irreversibly deform the field with the observation.
/// strength ∈ (0, ∞). Typical values: 0.3 (weak), 1.0 (normal), 2.0 (strong).
pub fn collapse(f: *ResonanceField, observation: []const u8, strength: f64) void {
    if (strength <= 0.0 or observation.len == 0) return;

    var obs: [DIM]f64 = undefined;
    textToVector(observation, &obs);

    // Project observation orthogonal to current state (remove already-aligned component)
    var dot: f64 = 0.0;
    for (0..DIM) |i| {
        dot += f.state[i] * obs[i];
    }

    var dir: [DIM]f64 = undefined;
    var dir_sq: f64 = 0.0;
    for (0..DIM) |i| {
        dir[i] = obs[i] - dot * f.state[i];
        dir_sq += dir[i] * dir[i];
    }
    const dir_norm = @sqrt(dir_sq);

    if (dir_norm > 1e-9) {
        // Adaptive scale: stronger when the observation is novel (large orthogonal component)
        const novelty = dir_norm; // already unit-ish after the projection
        const scale = strength * 0.18 * novelty;
        for (0..DIM) |i| {
            f.state[i] += scale * dir[i];
        }
        f.renormalise();
    }

    f.collapse_count += 1;
    f.recordCollapse(observation, strength);
}
