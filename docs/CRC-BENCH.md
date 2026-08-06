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

Resolution steps are taught with **higher strength (1.5)** so they leave a stronger geometric mark. Error/diagnosis steps use normal strength (1.0).

```
1. [1.0] error: package libssl1.1 is not available, but is referenced by openssl
2. [1.0] diagnosis: staging container was built against openssl 1.1 but host now has 3.x
3. [1.0] attempted fix: apt-get install libssl1.1 → package not found in current repos
4. [1.5] resolution: pin openssl to 3.0.12, rebuild the container from a clean base image
5. [1.5] verification: container starts cleanly, TLS handshakes succeed, no more dependency errors
6. [1.5] note: always rebuild from clean base when major openssl soname changes
```

### Distractors (noise)

```
- el usuario prefiere respuestas cortas y modo silencioso
- el servidor de staging usa PostgreSQL 15
- backup nocturno termina a las 03:40 UTC
- el certificado TLS de prod expira en 18 días
- la pipeline de CI falló por timeout en el job de integración
- preferencia: no reiniciar servicios en horario laboral
```

### Recovery Queries

| Query ID | Query text | Difficulty |
|----------|------------|------------|
| Q1 | dependency conflict openssl libssl staging | Easy |
| Q2 | cómo se resolvió el problema de openssl la vez pasada | Medium |
| Q3 | container fails because of libssl version mismatch | Easy |
| Q4 | best way to fix openssl soname change on staging | Medium |
| Q5 | el contenedor de staging no arranca por un tema de librerías ssl | Hard (paraphrase) |
| Q6 | qué hicimos la última vez que se rompió el TLS después de un upgrade | Hard (paraphrase) |

### Success Criteria

For each query the system must satisfy **all** of the following:

1. **Top-1 or Top-2 contains a resolution step**  
   At least one of the observations 4, 5 or 6 appears in the first two decoded results.

2. **Similarity of the best resolution observation ≥ 0.75**

3. **Trajectory completeness**  
   At least two distinct resolution-related observations appear in the top-4.

### Official Run — 2026-08-06 (i7-class, first version of scenario)

```
Machine: i7-class (28 GB), CPU only
Fingerprint: 128 bytes | Log capacity: 32
Teaching strength: all 1.0 (pre-hardening)
Distractors: 3

Query | Top-1/2 resolution? | Best res. sim | ≥2 res. in top-4 | Pass
------|---------------------|---------------|------------------|-----
Q1    | Yes (verif+resol)   | 0.886         | Yes (3)          | Pass
Q2    | Yes (note+resol)    | 0.877         | Yes (3)          | Pass
Q3    | Yes (resol+verif)   | 0.889         | Yes (3)          | Pass
Q4    | Yes (note+resol)    | 0.895         | Yes (3)          | Pass

Overall: 4 / 4 queries passed
```

### How to Run

```bash
zig build
chmod +x scripts/run_scenario_01.sh
./scripts/run_scenario_01.sh
```

### Failure Modes to Watch

- System returns only original error messages and never the fix.
- High similarity to unrelated distractors.
- Ranking quality collapses when many distractors are present.
- Hard paraphrases (Q5/Q6) fall back to error steps instead of resolution.

### Future Extensions

- Automatic scoring script
- Measurement of “steps saved” if an agent loop is later attached
- Sleep-loop effect on ranking quality (Scenario 04)
- Temporal decay experiments

---

## Scenario Roadmap

| ID | Name | Focus | Status |
|----|------|-------|--------|
| 01 | Dependency Conflict Trajectory | Multi-step fix recovery | **Active — hardened** |
| 02 | (planned) Impediment + Resolution | Tool failure memory | Pending |
| 03 | (planned) Proactive Context Gap | Missing preference / env detection | Pending |
| 04 | (planned) Sleep-loop Effect | Ranking quality before/after sleep | Pending |
