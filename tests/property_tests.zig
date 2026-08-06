//! Phase 1+ property tests for geometric invariants.

const std = @import("std");
const field_mod = @import("field");
const collapse_mod = @import("collapse");
const stabilise_mod = @import("stabilise");

const ResonanceField = field_mod.ResonanceField;
const DIM = field_mod.DIM;
const LOG_CAPACITY = field_mod.LOG_CAPACITY;

test "Invariant 1 — fixed dimension" {
    try std.testing.expect(DIM == 128);
    try std.testing.expect(LOG_CAPACITY == 32);
}

test "Invariant 3 — bounded norm after collapse" {
    var f = ResonanceField.init();
    const before = f.norm();
    try std.testing.expect(before > 0.9 and before < 1.1);

    collapse_mod.collapse(&f, "test observation about system dependencies and package versions", 1.0);
    const after = f.norm();
    try std.testing.expect(after > 0.9 and after < 1.1);
}

test "Invariant 3 — bounded norm after many collapses" {
    var f = ResonanceField.init();
    var i: u32 = 0;
    while (i < 200) : (i += 1) {
        collapse_mod.collapse(&f, "repeated observation that must not explode the norm", 1.0);
    }
    const n = f.norm();
    try std.testing.expect(n > 0.9 and n < 1.1);
}

test "Invariant 3 — bounded norm after stabilisation" {
    var f = ResonanceField.init();
    collapse_mod.collapse(&f, "initial knowledge about the environment", 1.0);

    var settled: [DIM]f64 = undefined;
    stabilise_mod.stabilise(&f, "query about knowledge", 16, 0.07, &settled);

    var sum_sq: f64 = 0.0;
    for (settled) |v| sum_sq += v * v;
    const n = @sqrt(sum_sq);
    try std.testing.expect(n > 0.9 and n < 1.1);
}

test "Invariant 2 — collapse changes state" {
    var f1 = ResonanceField.init();
    const f2 = f1; // copy

    collapse_mod.collapse(&f1, "unique observation that must alter geometry permanently", 1.0);

    var identical = true;
    for (0..DIM) |i| {
        if (f1.state[i] != f2.state[i]) {
            identical = false;
            break;
        }
    }
    try std.testing.expect(!identical);
    try std.testing.expect(f1.collapse_count == 1);
    try std.testing.expect(f2.collapse_count == 0);
}

test "Invariant 2 — no exact inverse by stabilisation" {
    var f = ResonanceField.init();
    const original = f;

    collapse_mod.collapse(&f, "irreversible knowledge injection", 1.5);

    var settled: [DIM]f64 = undefined;
    stabilise_mod.stabilise(&f, "try to undo", 32, 0.1, &settled);

    // The settled state must not restore the pre-collapse geometry exactly
    var restored = true;
    for (0..DIM) |i| {
        if (@abs(settled[i] - original.state[i]) > 1e-9) {
            restored = false;
            break;
        }
    }
    try std.testing.expect(!restored);
}

test "Invariant 4 — determinism of collapse sequence" {
    var f1 = ResonanceField.init();
    var f2 = ResonanceField.init();

    const observations = [_][]const u8{
        "first fact about staging database",
        "second fact about the environment and network topology",
        "third observation regarding user preference for quiet mode",
        "dependency conflict resolution path",
    };

    for (observations) |obs| {
        collapse_mod.collapse(&f1, obs, 1.0);
        collapse_mod.collapse(&f2, obs, 1.0);
    }

    for (0..DIM) |i| {
        try std.testing.expect(f1.state[i] == f2.state[i]);
    }
    try std.testing.expect(f1.collapse_count == f2.collapse_count);
    try std.testing.expect(f1.log_len == f2.log_len);
}

test "Invariant 4 — textToVector is deterministic" {
    var v1: [DIM]f64 = undefined;
    var v2: [DIM]f64 = undefined;
    collapse_mod.textToVector("the same deterministic text", &v1);
    collapse_mod.textToVector("the same deterministic text", &v2);
    for (0..DIM) |i| {
        try std.testing.expect(v1[i] == v2[i]);
    }
}

test "collapse log stays bounded" {
    var f = ResonanceField.init();
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        collapse_mod.collapse(&f, "filling the ring buffer with observations", 0.8);
    }
    try std.testing.expect(f.log_len == LOG_CAPACITY);
    try std.testing.expect(f.collapse_count == 100);
}

test "recentCollapses returns chronological order" {
    var f = ResonanceField.init();
    collapse_mod.collapse(&f, "alpha", 1.0);
    collapse_mod.collapse(&f, "beta", 1.0);
    collapse_mod.collapse(&f, "gamma", 1.0);

    var buf: [LOG_CAPACITY]field_mod.CollapseEntry = undefined;
    const n = f.recentCollapses(&buf);
    try std.testing.expect(n == 3);

    // fingerprints should contain the texts in order
    try std.testing.expect(std.mem.startsWith(u8, buf[0].fingerprint[0..], "alpha"));
    try std.testing.expect(std.mem.startsWith(u8, buf[1].fingerprint[0..], "beta"));
    try std.testing.expect(std.mem.startsWith(u8, buf[2].fingerprint[0..], "gamma"));
}
