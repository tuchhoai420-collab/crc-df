# CRC-DF — Campo de Resonancia Colapsable de Dimensión Fija

**Primary runtime:** Zig  
**Ontology:** exogenous, non-anthropic  
**Target hardware:** Intel i7-10700 (28 GB) + Raspberry Pi 500+ (16 GB)

Official architecture and roadmap: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)  
Geometric invariants: [`docs/INVARIANTS.md`](docs/INVARIANTS.md)

## What this is

CRC-DF is the memory and selective-learning substrate of an agent that:

- Evolves through interactions with the user and the execution environment.
- Selectively retains only information that demonstrates real value.
- Recovers complete problem-solving trajectories.
- Operates proactively (detects knowledge gaps, acquires context, manages impediments).
- Possesses a background optimisation loop (“sleep”).

The geometric core remains:

- Fixed-dimension continuous state
- Irreversible collapse
- Inference by stabilisation
- Deterministic, bounded cost

## Current status (2026-08-06)

**Phase 1 — Core Foundation** (functional base planted)

- ✅ Geometric core implemented in Zig
- ✅ Official architecture document published
- ✅ Invariant specification published
- ✅ Property tests covering all four invariants + log bounds
- ✅ Improved deterministic text→vector encoder (char n-grams + word hashes)
- ✅ Bounded collapse log (ring buffer of 32) — seed for trajectory recovery
- ✅ Binary persistence v2 (state + log)
- ✅ CLI with observe / recall / stats / sleep / reset
- ✅ Micro-benchmarks scaffold

## Build & run

Requires Zig 0.13+ (or current stable).

```bash
zig build

./zig-out/bin/crc-df observe "the staging server uses PostgreSQL 15"
./zig-out/bin/crc-df observe "user prefers quiet mode and short answers" 1.4
./zig-out/bin/crc-df recall "what database is on staging"
./zig-out/bin/crc-df stats
./zig-out/bin/crc-df sleep 3
./zig-out/bin/crc-df reset
```

Run tests:

```bash
zig build test
```

Run micro-benchmarks:

```bash
zig build bench
```

Cross-compile for Raspberry Pi 500+:

```bash
zig build -Dtarget=aarch64-linux
```

## Repository layout

```
src/           Geometric core + CLI (Zig)
docs/          Architecture, invariants, future design docs
tests/         Property tests (Phase 1+)
build.zig
```

## Design principles in force

1. The active state never grows with history (fixed DIM).
2. Every observation is irreversible.
3. Queries are answered by letting the field settle.
4. Cost is constant, independent of the number of past interactions.
5. The collapse log is deliberately bounded; it is a trajectory *seed*, not a full history store.
