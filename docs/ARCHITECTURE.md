# CRC-DF — Architecture & Roadmap

**Version:** 0.2  
**Status:** Active baseline — Phase 1 functional foundations planted  
**Repository:** https://github.com/tuchhoai420-collab/crc-df

## 1. System Definition

CRC-DF (Campo de Resonancia Colapsable de Dimensión Fija) is the memory and selective-learning substrate of an agent that:

- Evolves through interactions with the user and the execution environment.
- Selectively retains only information that demonstrates real value.
- Recovers complete problem-solving trajectories (not isolated facts).
- Operates proactively: detects knowledge gaps, acquires necessary information, and verifies its environment.
- Possesses a background optimisation loop (“sleep”) that reinforces useful deformations, weakens irrelevant ones, and identifies recurring impediments.

### Geometric Core Invariants (non-negotiable)

1. **Fixed dimension** — The active state never grows with the number of interactions. Capacity is expressed as geometric richness of the field.
2. **Irreversible collapse** — Every observation produces a permanent deformation. No inverse operation exists.
3. **Inference by stabilisation** — A query is a perturbation. The answer is the state to which the field converges after a fixed number of steps.
4. **Deterministic cost** — Both collapse and stabilisation have complexity bounded by constants (dimension D and number of stabilisation steps).

## 2. Layered Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ Agent / Consumption Layer                                    │
│ CLI · C-ABI · Python binding · MCP · Model integration       │
├──────────────────────────────────────────────────────────────┤
│ Selective & Proactive Intelligence Layer                     │
│ · Gap detector (user + environment + tools)                  │
│ · Relevance & trajectory manager                             │
│ · Acquisition policy (ask vs autonomous verification)        │
│ · Background optimisation loop (“sleep”)                     │
├──────────────────────────────────────────────────────────────┤
│ Geometric Core (Zig)                                         │
│ ResonanceField · Collapse · Stabilise · Bounded Collapse Log │
├──────────────────────────────────────────────────────────────┤
│ Persistence                                                  │
│ Binary field snapshot + compact collapse log                 │
│ (optional: high-relevance trajectory records)                │
└──────────────────────────────────────────────────────────────┘
```

**Strict rule:** The selective intelligence layer only *modulates* the magnitude and timing of collapses. It never alters the geometric rules of the core.

## 3. Current Implementation Status (Phase 1+)

### Implemented

| Component | Status | Notes |
|-----------|--------|-------|
| Fixed-dimension ResonanceField | ✅ | DIM = 128 |
| Irreversible collapse | ✅ | Orthogonal projection + novelty-scaled update |
| Stabilisation dynamics | ✅ | Fixed-step with contraction + metrics |
| Deterministic text→vector | ✅ | Char n-grams + word hashes (FNV) |
| Bounded collapse log | ✅ | Ring buffer of 32 recent observations |
| Binary persistence (v2) | ✅ | State + log, forward-compatible |
| CLI (observe/recall/stats/sleep/reset) | ✅ | Strength parameter, diagnostics |
| Property test suite | ✅ | All 4 invariants + log bounds |
| Micro-benchmarks | ✅ | collapse / stabilise / combined |

### Sleep Loop (foundation)

A minimal `sleep` command already exists. It performs mild re-collapse of the most recent high-strength entries. This is the seed of the future background optimisation loop.

## 4. Required Capabilities (to be demonstrated)

1. **Trajectory recovery**  
   A complex problem solved once must be recoverable on the second occurrence with substantial reduction in steps.

2. **Proactive context acquisition**  
   Detect missing user preferences / environment details / tools and acquire them.

3. **Impediment management**  
   On tool/command failures: diagnose, record cause + resolution path, reuse knowledge.

4. **Background optimisation (“sleep”)**  
   Reinforce useful deformations, weaken irrelevant ones, surface recurring impediments.

## 5. Development Phases

### Phase 1 — Core Foundation (current — functional base planted)
- ✅ Geometric core frozen (fixed dimension, collapse, stabilisation)
- ✅ Formal specification of geometric invariants
- ✅ Property-based test suite
- ✅ Micro-benchmarks scaffold
- ✅ Improved text→vector encoder
- ✅ Bounded collapse log (trajectory seed)
- ✅ Richer CLI + sleep stub

**Exit criterion:** Reproducible property tests + cost numbers on both target machines.

### Phase 2 — Trajectory Memory & Serious Evaluation
- Representation of full resolution trajectories as structured deformations
- CRC-Bench evaluation protocol
- Quantitative comparison against existing approaches
- First usable decoding head (or projection back to text)

### Phase 3 — Proactivity & Optimisation Loop
- Context-gap detector
- Acquisition policy
- Impediment + resolution recording
- Full sleep loop with selective reinforcement/weakening rules
- End-to-end demonstration of the dependency-conflict scenario

### Phase 4 — Exposure & Scalability
- Stable C-ABI
- Official Python binding
- Full MCP server
- Multi-field coupling preparation + WASM Component

### Phase 5 — Frontier
- Higher-order collapse dynamics
- Inter-field coupling
- Continuous / neuromorphic hardware mapping

## 6. Superiority Metrics (mandatory)

| Metric | Description |
|--------|-------------|
| Trajectory savings | Steps / time on 2nd occurrence of a complex problem vs 1st |
| Autonomous impediment resolution rate | % of tool failures resolved without asking after having seen them once |
| Proactive context coverage | % of critical user/environment information acquired without explicit declaration |
| Sleep-loop effect | Change in recovery quality and field footprint after optimisation |
| Long-term RAM / disk footprint | After thousands of interactions |
| Cost per observe + recall | Deterministic, measured on both target machines |
| Determinism | Same inputs → bit-identical final state |

## 7. Governance

- The Zig geometric core is the single source of truth for dynamics.
- Any change to collapse or stabilisation rules requires:
  - Update of the formal specification.
  - New property tests.
  - Re-execution of the Phase-2 benchmark suite.
- Bindings and MCP layer contain no memory logic; they only translate.

## 8. Immediate Next Actions

1. Run property tests and micro-benchmarks on i7-10700 and Raspberry Pi 500+.
2. Collect first cost numbers and publish them in `docs/BENCHMARKS.md`.
3. Design CRC-Bench scenarios (trajectory recovery focus).
4. Begin lightweight decoding experiments (project settled state back toward recent log fingerprints).

Only after Phase 1 is closed with measured data do we advance to Phase 2.
