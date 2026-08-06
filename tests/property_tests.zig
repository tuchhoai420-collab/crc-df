//! Phase 1 property tests for geometric invariants.
//! These tests must fail if any core invariant is violated.

const std = @import("std");
const field_mod = @import("field");
const collapse_mod = @import("collapse");
const stabilise_mod = @import("stabilise");

const ResonanceField = field_mod.ResonanceField;
const DIM = field_mod.DIM;

test "Invariant 1 — fixed dimension" {
    // DIM is compile-time constant; this test simply documents the contract.
    try std.testing.expect(DIM == 128);
}

test "Invariant 3 — bounded norm after collapse" {
    var f = ResonanceField.init();
    const before = f.norm();
    try std.testing.expect(before > 0.9 and before < 1.1);

    collapse_mod.collapse(&f, "test observation about system dependencies", 1.0);
    const after = f.norm();
    try std.testing.expect(after > 0.9 and after < 1.1);
}

test "Invariant 3 — bounded norm after stabilisation" {
    var f = ResonanceField.init();
    collapse_mod.collapse(&f, "initial knowledge", 1.0);

    var settled: [DIM]f64 = undefined;
    stabilise_mod.stabilise(&f, "query about knowledge", 12, 0.08, &settled);

    var sum_sq: f64 = 0.0;
    for (settled) |v| sum_sq += v * v;
    const n = @sqrt(sum_sq);
    try std.testing.expect(n > 0.9 and n < 1.1);
}

test "Invariant 2 — collapse changes state (irreversibility support)" {
    var f1 = ResonanceField.init();
    var f2 = f1;

    collapse_mod.collapse(&f1, "unique observation that must alter geometry", 1.0);

    // After a non-zero strength collapse the state must differ.
    var identical = true;
    for (0..DIM) |i| {
        if (f1.state[i] != f2.state[i]) {
            identical = false;
            break;
        }
    }
    try std.testing.expect(!identical);
}

test "Invariant 4 — determinism of collapse sequence" {
    var f1 = ResonanceField.init();
    var f2 = ResonanceField.init();

    const observations = [_][]const u8{
        "first fact",
        "second fact about the environment",
        "third observation regarding user preference",
    };

    for (observations) |obs| {
        collapse_mod.collapse(&f1, obs, 1.0);
        collapse_mod.collapse(&f2, obs, 1.0);
    }

    for (0..DIM) |i| {
        try std.testing.expect(f1.state[i] == f2.state[i]);
    }
    try std.testing.expect(f1.collapse_count == f2.collapse_count);
}
