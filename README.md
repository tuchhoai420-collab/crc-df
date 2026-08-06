# CRC-DF — Campo de Resonancia Colapsable de Dimensión Fija

**Primary runtime:** Zig  
**Ontology:** exogenous, non-anthropic  
**Target hardware:** Intel i7-10700 (28 GB) + Raspberry Pi 500+ (16 GB, aarch64)

## Core idea

Memory is a continuous field of **fixed dimension**.  
Every interaction irreversibly deforms the field.  
Inference is stabilisation after perturbation.  
No discrete Facts, no growing indexes, no quadratic attention.

## Why Zig

- Zero runtime overhead
- Explicit memory layout for a fixed-size state
- Cross-compiles cleanly to x86_64 and aarch64 (Pi 500+)
- Binary size and RAM footprint remain minimal
- Direct path to WASM Component Model for future scaling

Python is kept only as an optional thin layer for rapid experimentation on the i7.

## Structure

```
src/
├── field.zig        # ResonanceField (fixed-dim state)
├── collapse.zig     # irreversible deformation operators
├── stabilise.zig    # dynamical settling
├── store.zig        # binary persistence
└── main.zig         # minimal CLI (observe / recall / stats)
build.zig
```

## Build & run

Requires Zig 0.13+ (or current stable).

```bash
zig build

# observe
./zig-out/bin/crc-df observe "the staging server uses PostgreSQL 15"

# recall
./zig-out/bin/crc-df recall "what database is on staging"

# stats
./zig-out/bin/crc-df stats
```

Cross-compile for the Raspberry Pi 500+:

```bash
zig build -Dtarget=aarch64-linux
```

## Design invariants

- Dimension is compile-time constant (default 128).
- Collapse is irreversible (no inverse operation exists).
- Stabilisation runs a fixed number of steps (deterministic cost).
- Persistence stores only the field state + compact metadata.
