//! ResonanceField — fixed-dimension continuous state.
//! The entire memory is the geometry of this vector.
//! Capacity is topological richness, not number of discrete records.
//!
//! Phase 1+: carries a bounded collapse log (ring buffer) that records
//! recent high-value observations for future trajectory recovery.
//! The log is metadata; it does NOT grow the geometric state.

const std = @import("std");

pub const DIM: usize = 128;
pub const LOG_CAPACITY: usize = 32; // fixed, never grows with history
pub const FP_LEN: usize = 128; // fingerprint length — optimal for readability on desktop hardware

pub const CollapseEntry = struct {
    /// Truncated fingerprint of the observation text (null-padded)
    fingerprint: [FP_LEN]u8,
    strength: f32,
    /// Monotonic counter at the moment of collapse
    sequence: u64,
};

pub const ResonanceField = struct {
    state: [DIM]f64,
    collapse_count: u64,
    /// Bounded ring buffer of recent collapses (for trajectory foundations)
    log: [LOG_CAPACITY]CollapseEntry,
    log_len: usize, // how many slots are currently valid (0..LOG_CAPACITY)
    log_head: usize, // next write index

    pub fn init() ResonanceField {
        var f: ResonanceField = .{
            .state = undefined,
            .collapse_count = 0,
            .log = undefined,
            .log_len = 0,
            .log_head = 0,
        };
        // Deterministic small random initialisation (seed 42)
        var prng = std.Random.DefaultPrng.init(42);
        const rand = prng.random();
        var sum_sq: f64 = 0.0;
        for (&f.state) |*v| {
            v.* = rand.floatNorm(f64) * 0.01;
            sum_sq += v.* * v.*;
        }
        const n = @sqrt(sum_sq) + 1e-12;
        for (&f.state) |*v| {
            v.* /= n;
        }
        // zero the log
        for (&f.log) |*e| {
            e.* = .{
                .fingerprint = [_]u8{0} ** FP_LEN,
                .strength = 0,
                .sequence = 0,
            };
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

    /// Record a collapse into the bounded log (overwrites oldest when full).
    pub fn recordCollapse(self: *ResonanceField, text: []const u8, strength: f64) void {
        var entry: CollapseEntry = .{
            .fingerprint = [_]u8{0} ** FP_LEN,
            .strength = @floatCast(strength),
            .sequence = self.collapse_count,
        };
        const copy_len = @min(text.len, FP_LEN);
        @memcpy(entry.fingerprint[0..copy_len], text[0..copy_len]);

        self.log[self.log_head] = entry;
        self.log_head = (self.log_head + 1) % LOG_CAPACITY;
        if (self.log_len < LOG_CAPACITY) {
            self.log_len += 1;
        }
    }

    /// Iterate recent collapses from oldest to newest (for diagnostics / future sleep).
    pub fn recentCollapses(self: *const ResonanceField, out: *[LOG_CAPACITY]CollapseEntry) usize {
        if (self.log_len == 0) return 0;
        const start = if (self.log_len < LOG_CAPACITY) 0 else self.log_head;
        var i: usize = 0;
        while (i < self.log_len) : (i += 1) {
            const idx = (start + i) % LOG_CAPACITY;
            out[i] = self.log[idx];
        }
        return self.log_len;
    }
};
