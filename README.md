# CRC-DF — Campo de Resonancia Colapsable de Dimensión Fija

**Ontology:** exogenous, non-anthropic  
**Target hardware:** Intel i7-10700 (28 GB RAM) + Raspberry Pi 500+ (16 GB)

## What this is

A memory operator that rejects the paradigm of ever-growing parameter counts and discrete entity stores.

### Core principles

1. **Fixed dimension** — the active state never grows. Capacity is geometric richness of deformations, not number of stored objects.
2. **Irreversible collapse** — every interaction permanently deforms the field. There is no delete or overwrite of past structure.
3. **Inference by stabilisation** — a query is a perturbation. The field settles. The settled pattern *is* the answer.
4. **Local deformation only** — updates are cheap. No global backpropagation, no full reindexing.

This is not an imitation of a biological brain. It is an efficiency-first operator designed for predictable, low resource use while preserving long-term consistency.

## Structure

```
crc-df/
├── core/
│   ├── field.py          # ResonanceField — fixed-dimension state
│   ├── collapse.py       # irreversible update operators
│   └── stabilise.py      # dynamical settling / inference
├── persistence/
│   └── store.py          # load / save (lightweight)
├── api/
│   └── interface.py      # high-level observe / recall / feedback
├── tests/
│   └── test_basic.py
├── requirements.txt
└── README.md
```

## Quick start

```bash
pip install -r requirements.txt

python -c "
from api.interface import Memory
m = Memory(dim=128)
m.observe('the staging server uses PostgreSQL 15')
m.observe('PostgreSQL 15 is running on port 5432')
print(m.recall('what database is on staging'))
m.save()
"
```

## Design notes

- The field is a continuous vector of fixed length `D` (default 128).
- Collapse projects an observation and applies a low-rank irreversible update.
- Stabilisation runs a short fixed number of dynamical steps (cheap on both target machines).
- Feedback only modulates local deformation strength.
- Persistence stores only the current field state + a compact collapse log.

Legacy discrete-entity concepts (Facts, Beliefs, BM25 indexes, explicit graphs, HOT/WARM/COLD tiers) were discarded.  
Concepts retained in transformed form: irreversibility, usage-based reinforcement, resource boundedness, pure-Python portability.
