# CRC-DF — Architecture & Roadmap

**Version:** 0.1  
**Status:** Active baseline  
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
│ ResonanceField · Collapse · Stabilise                        │
├──────────────────────────────────────────────────────────────┤
│ Persistence                                                  │
│ Binary field snapshot + compact collapse log                 │
│ (optional: high-relevance trajectory records)                │
└──────────────────────────────────────────────────────────────┘
```

**Strict rule:** The selective intelligence layer only *modulates* the magnitude and timing of collapses. It never alters the geometric rules of the core.

## 3. Required Capabilities (to be demonstrated)

1. **Trajectory recovery**  
   A complex problem solved once (e.g. OS dependency conflict) must be recoverable on the second occurrence with substantial reduction in steps and without repeating previous errors.

2. **Proactive context acquisition**  
   The system must detect that it lacks user preferences, environment details or available tools, and acquire that information actively (by asking or by autonomous verification).

3. **Impediment management**  
   On tool/command failures: diagnose, record cause + resolution path, and reuse that knowledge.

4. **Background optimisation (“sleep”)**  
   A low-priority loop that:
   - Reinforces deformations linked to successful outcomes.
   - Weakens information that showed no utility.
   - Surfaces recurring impediments and possible strategy improvements.

## 4. Development Phases

### Phase 1 — Core Foundation (current)
- Freeze current geometric core (fixed dimension, collapse, stabilisation).
- Formal specification of geometric invariants.
- Property-based test suite (irreversibility, bounded norm, determinism).
- Micro-benchmarks of cost on i7-10700 and Raspberry Pi 500+.
- Improved text→vector encoder (still without heavy external models).

**Exit criterion:** Reproducible property tests + cost numbers on both target machines.

### Phase 2 — Trajectory Memory & Serious Evaluation
- Representation of full resolution trajectories as structured deformations.
- CRC-Bench evaluation protocol (long-term retention, recovery of prior solutions, noise resistance).
- Quantitative comparison against existing approaches.
- First usable decoding head.

### Phase 3 — Proactivity & Optimisation Loop
- Context-gap detector.
- Acquisition policy (ask vs autonomous verification).
- Impediment + resolution recording.
- Sleep loop with selective reinforcement/weakening rules.
- End-to-end demonstration of the dependency-conflict scenario.

### Phase 4 — Exposure & Scalability
- Stable C-ABI.
- Official Python binding.
- Full MCP server (including relevance signals and sleep-loop control).
- Preparation for multi-field coupling and WASM Component.

### Phase 5 — Frontier
- Higher-order collapse dynamics.
- Inter-field coupling.
- Exploration of continuous / neuromorphic hardware mapping.

## 5. Superiority Metrics (mandatory)

| Metric | Description |
|--------|-------------|
| Trajectory savings | Steps / time on 2nd occurrence of a complex problem vs 1st |
| Autonomous impediment resolution rate | % of tool failures resolved without asking the user after having seen them once |
| Proactive context coverage | % of critical user/environment information acquired without explicit declaration |
| Sleep-loop effect | Change in recovery quality and field footprint after optimisation |
| Long-term RAM / disk footprint | After thousands of interactions |
| Cost per observe + recall | Deterministic, measured on both target machines |
| Determinism | Same inputs → bit-identical final state |

## 6. Governance

- The Zig geometric core is the single source of truth for dynamics.
- Any change to collapse or stabilisation rules requires:
  - Update of the formal specification.
  - New property tests.
  - Re-execution of the Phase-2 benchmark suite.
- Bindings and MCP layer contain no memory logic; they only translate.

## 7. Immediate Next Actions (Phase 1)

1. This document is the official architecture baseline.
2. Freeze current Zig core as `v0.1-core`.
3. Write formal geometric invariant specification.
4. Implement property test suite.
5. Instrument and publish first micro-benchmarks on i7-10700 and Raspberry Pi 500+.

Only after Phase 1 is closed with data do we advance to Phase 2.
