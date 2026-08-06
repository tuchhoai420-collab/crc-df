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

## Current status

**Phase 1 — Core Foundation** (in progress)

- Geometric core implemented in Zig
- Official architecture document published
- Invariant specification published
- Property tests and micro-benchmarks under construction

## Build & run

Requires Zig 0.13+ (or current stable).

```bash
zig build

./zig-out/bin/crc-df observe "the staging server uses PostgreSQL 15"
./zig-out/bin/crc-df recall "what database is on staging"
./zig-out/bin/crc-df stats
```

Cross-compile for Raspberry Pi 500+:

```bash
zig build -Dtarget=aarch64-linux
```

## Repository layout

```
src/           Geometric core (Zig)
docs/          Architecture, invariants, future design docs
tests/         Property tests (Phase 1)
build.zig
```
