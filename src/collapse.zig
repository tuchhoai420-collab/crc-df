//! Irreversible collapse operators.
//! A collapse permanently deforms the field. There is no inverse.

const std = @import("std");
const field_mod = @import("field.zig");
const ResonanceField = field_mod.ResonanceField;
const DIM = field_mod.DIM;

/// Deterministic, allocation-free text → vector (character + bigram hashing).
pub fn textToVector(text: []const u8, out: *[DIM]f64) void {
    @memset(out, 0.0);
    if (text.len == 0) return;

    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        const ch = std.ascii.toLower(text[i]);
        const h = @as(usize, @intCast(ch)) % DIM;
        out[h] += 1.0;

        if (i + 1 < text.len) {
            const ch2 = std.ascii.toLower(text[i + 1]);
            const h2 = (@as(usize, @intCast(ch)) * 31 + @as(usize, @intCast(ch2))) % DIM;
            out[h2] += 0.6;
        }
    }

    var sum_sq: f64 = 0.0;
    for (out.*) |v| sum_sq += v * v;
    const n = @sqrt(sum_sq) + 1e-12;
    for (out) |*v| v.* /= n;
}

/// Irreversibly deform the field with the observation.
pub fn collapse(f: *ResonanceField, observation: []const u8, strength: f64) void {
    if (strength <= 0.0) return;

    var obs: [DIM]f64 = undefined;
    textToVector(observation, &obs);

    // direction = obs - proj_state(obs)
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
        const scale = strength * 0.15 / dir_norm;
        for (0..DIM) |i| {
            f.state[i] += scale * dir[i];
        }
        f.renormalise();
    }

    f.collapse_count += 1;
}
