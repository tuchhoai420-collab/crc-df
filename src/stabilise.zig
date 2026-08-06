//! Stabilisation dynamics.
//! A query perturbs the field. We let it settle for a fixed number of steps.
//! The settled geometry is the answer.

const field_mod = @import("field");
const collapse_mod = @import("collapse");
const ResonanceField = field_mod.ResonanceField;
const DIM = field_mod.DIM;

pub fn stabilise(f: *const ResonanceField, query: []const u8, steps: u32, step_size: f64, out: *[DIM]f64) void {
    var q: [DIM]f64 = undefined;
    collapse_mod.textToVector(query, &q);

    // work on a copy
    @memcpy(out, &f.state);

    var s: u32 = 0;
    while (s < steps) : (s += 1) {
        var dot: f64 = 0.0;
        for (0..DIM) |i| {
            dot += out[i] * q[i];
        }

        var sum_sq: f64 = 0.0;
        for (0..DIM) |i| {
            out[i] += step_size * (q[i] - dot * out[i]);
            out[i] *= 0.995; // mild contraction
            sum_sq += out[i] * out[i];
        }
        const n = @sqrt(sum_sq) + 1e-12;
        for (0..DIM) |i| {
            out[i] /= n;
        }
    }
}

/// Cosine similarity between two unit-ish vectors.
pub fn cosine(a: *const [DIM]f64, b: *const [DIM]f64) f64 {
    var dot: f64 = 0.0;
    var na: f64 = 0.0;
    var nb: f64 = 0.0;
    for (0..DIM) |i| {
        dot += a[i] * b[i];
        na += a[i] * a[i];
        nb += b[i] * b[i];
    }
    return dot / (@sqrt(na) * @sqrt(nb) + 1e-12);
}
