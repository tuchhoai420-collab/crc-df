# Geometric Invariants — CRC-DF Core

**Status:** Phase 1 specification  
**Applies to:** `src/field.zig`, `src/collapse.zig`, `src/stabilise.zig`

## Invariant 1 — Fixed Dimension

- The active state is a vector of compile-time constant length `DIM` (default 128).
- No operation may allocate additional permanent state proportional to the number of observations.
- Capacity is expressed solely through the geometry of the existing vector.

## Invariant 2 — Irreversibility of Collapse

- There exists no sequence of public operations that restores a previous field state exactly once a collapse has been applied.
- Collapse is a one-way deformation.
- The only permitted way to influence future behaviour is through additional collapses (including those performed by the sleep loop with modulated strength).

## Invariant 3 — Bounded Norm

- After every collapse and after every stabilisation step the Euclidean norm of the field remains finite and is re-normalised to approximately 1.
- The implementation must prevent numerical explosion or collapse to the zero vector.

## Invariant 4 — Determinism

- Given identical initial seed (or loaded state) and identical sequence of observations and queries, the final field state and all intermediate stabilised states are bit-identical across runs and across the two target platforms (x86_64 and aarch64) when using the same Zig version and optimisation settings.

## Invariant 5 — Deterministic Cost

- Collapse is O(DIM).
- Stabilisation with `S` steps is O(S × DIM).
- Both `DIM` and `S` are fixed design constants. Cost does not grow with history length.

## Test Obligations (Phase 1)

Every invariant above must have at least one automated property test that fails if the invariant is violated.
