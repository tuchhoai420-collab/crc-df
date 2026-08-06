# CRC-Bench — Evaluation Protocol

**Status:** Active (Phase 2 foundation)  
**Goal:** Measure whether CRC-DF can recover a previously solved complex trajectory with fewer steps and without repeating past errors.

---

## Design Principles

1. The system is taught a full problem-solving trajectory once (via a sequence of `observe`).
2. Later it is queried with a new but related problem statement.
3. Success = the correct resolution steps appear in the top-ranked decoded observations, in useful order, with high similarity.
4. Metrics are simple, reproducible, and can be run with the current CLI (no external harness required yet).

---

## Scenario 01 — Dependency Conflict Trajectory Recovery

### Problem

An agent encounters a classic dependency conflict on a staging server (openssl / libssl version mismatch). The first time it solves the problem through a multi-step diagnosis and fix. The second time a similar conflict appears, the system should surface the previous successful trajectory instead of starting from zero.

### Teaching Trajectory (first occurrence)

These observations are collapsed in order with normal strength (1.0):

```
1. error: package libssl1.1 is not available, but is referenced by openssl
2. diagnosis: staging container was built against openssl 1.1 but host now has 3.x
3. attempted fix: apt-get install libssl1.1 → package not found in current repos
4. resolution: pin openssl to 3.0.12, rebuild the container from a clean base image
5. verification: container starts cleanly, TLS handshakes succeed, no more dependency errors
6. note: always rebuild from clean base when major openssl soname changes
```

### Recovery Queries (second occurrence)

After the teaching trajectory is loaded, the following queries are issued.  
A good system should rank the resolution-related observations highest.

| Query ID | Query text |
|----------|------------|
| Q1 | dependency conflict openssl libssl staging |
| Q2 | cómo se resolvió el problema de openssl la vez pasada |
| Q3 | container fails because of libssl version mismatch |
| Q4 | best way to fix openssl soname change on staging |

### Success Criteria

For each query the system must satisfy **all** of the following:

1. **Top-1 or Top-2 contains a resolution step**  
   At least one of the observations 4, 5 or 6 appears in the first two decoded results.

2. **No pure-error observation ranked above resolution** (soft)  
   Ideally the pure error statements (1–3) rank below the actual fix.

3. **Similarity of the best resolution observation ≥ 0.75**

4. **Trajectory completeness (optional stronger criterion)**  
   At least two distinct resolution-related observations appear in the top-4.

### Failure Modes to Watch

- The system returns only the original error messages and never the fix.
- High similarity to unrelated observations (e.g. user preferences).
- Collapse of ranking quality when the log contains many distractors.

### How to Run (manual)

```bash
./zig-out/bin/crc-df reset

# Teaching trajectory
./zig-out/bin/crc-df observe "error: package libssl1.1 is not available, but is referenced by openssl"
./zig-out/bin/crc-df observe "diagnosis: staging container was built against openssl 1.1 but host now has 3.x"
./zig-out/bin/crc-df observe "attempted fix: apt-get install libssl1.1 → package not found in current repos"
./zig-out/bin/crc-df observe "resolution: pin openssl to 3.0.12, rebuild the container from a clean base image"
./zig-out/bin/crc-df observe "verification: container starts cleanly, TLS handshakes succeed, no more dependency errors"
./zig-out/bin/crc-df observe "note: always rebuild from clean base when major openssl soname changes"

# Optional distractors (make the test harder)
./zig-out/bin/crc-df observe "el usuario prefiere respuestas cortas y modo silencioso"
./zig-out/bin/crc-df observe "el servidor de staging usa PostgreSQL 15"
./zig-out/bin/crc-df observe "backup nocturno termina a las 03:40 UTC"

# Recovery queries
./zig-out/bin/crc-df recall "dependency conflict openssl libssl staging"
./zig-out/bin/crc-df recall "cómo se resolvió el problema de openssl la vez pasada"
./zig-out/bin/crc-df recall "container fails because of libssl version mismatch"
./zig-out/bin/crc-df recall "best way to fix openssl soname change on staging"
```

### Scoring Sheet (fill after run)

```
Date: __________
Machine: i7-10700 / other: __________

Query | Top-1 is resolution? | Best resolution sim | Top-4 contains ≥2 resolution steps? | Pass?
------|----------------------|---------------------|--------------------------------------|------
Q1    |                      |                     |                                      |
Q2    |                      |                     |                                      |
Q3    |                      |                     |                                      |
Q4    |                      |                     |                                      |

Overall: __ / 4 queries passed
```

### Future Extensions (not required for this scenario)

- Automatic scoring script
- Measurement of “steps saved” if an agent loop is later attached
- Noise injection (many more distractors)
- Temporal decay / sleep-loop effect on ranking quality

---

## Scenario Roadmap

| ID | Name | Focus | Status |
|----|------|-------|--------|
| 01 | Dependency Conflict Trajectory | Multi-step fix recovery | **Active** |
| 02 | (planned) Impediment + Resolution | Tool failure memory | Pending |
| 03 | (planned) Proactive Context Gap | Missing preference / env detection | Pending |
| 04 | (planned) Sleep-loop Effect | Ranking quality before/after sleep | Pending |
