//! ResonanceField — fixed-dimension continuous state.
//! The entire memory is the geometry of this vector.
//! Capacity is topological richness, not number of discrete records.

const std = @import("std");

pub const DIM: usize = 128;

pub const ResonanceField = struct {
    state: [DIM]f64,
    collapse_count: u64,

    pub fn init() ResonanceField {
        var f: ResonanceField = .{
            .state = undefined,
            .collapse_count = 0,
        };
        // Deterministic small seed so the field is not perfectly symmetric
        var prng = std.Random.DefaultPrng.init(42);
        const rand = prng.random();
        var sum_sq: f64 = 0.0;
        for (&f.state) |*v| {
            v.* = rand.floatNorm(f64) * 0.01;
            sum_sq += v.* * v.*;
        }
        const norm = @sqrt(sum_sq) + 1e-12;
        for (&f.state) |*v| {
            v.* /= norm;
        }
        return f;
    }

    pub fn norm(self: *const ResonanceField) f64 {
        var sum_sq: f64 = 0.0;
        for (self.state) |v| {
            sum_sq += v * v;
        }
        return @sqrt(sum_sq);
    }

    pub fn renormalise(self: *ResonanceField) void {
        const n = self.norm() + 1e-12;
        for (&self.state) |*v| {
            v.* /= n;
        }
    }
};
