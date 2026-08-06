# CRC-DF Micro-Benchmarks

**Phase 1 deliverable**

## Purpose

Measure the deterministic cost of the two core operations:

- `collapse` (irreversible observation)
- `stabilise` (inference)

on the two target platforms:

- Intel i7-10700 (28 GB RAM)
- Raspberry Pi 500+ (16 GB, aarch64)

## How to run

```bash
zig build bench
```

This builds with `ReleaseFast` and prints wall-clock nanoseconds / microseconds per operation.

Cross-compile for the Pi:

```bash
zig build bench -Dtarget=aarch64-linux
# then copy zig-out/bin/crc-df-bench to the Pi and run it there
```

## What is measured

| Operation              | Description                              |
|------------------------|------------------------------------------|
| collapse               | Single irreversible field deformation    |
| stabilise (12 steps)   | Full stabilisation dynamics              |
| collapse + stabilise   | Combined cost of one observe+recall cycle|

All measurements use a fixed number of iterations (5000) and report average time per operation.

## Expected characteristics

- Cost must remain **independent of history length** (fixed dimension).
- Numbers should be reproducible across runs on the same machine.
- Results on the Pi will be slower than on the i7; the important property is that both stay in the low-microsecond or sub-microsecond range for the core operations.

## Recording results

After running on both machines, record the numbers in this file under a dated section so Phase 1 can be closed with evidence.

### Template

```
### YYYY-MM-DD — i7-10700
collapse:            X.XXX µs
stabilise (12 steps): X.XXX µs
combined:             X.XXX µs

### YYYY-MM-DD — Raspberry Pi 500+
collapse:            X.XXX µs
stabilise (12 steps): X.XXX µs
combined:             X.XXX µs
```
