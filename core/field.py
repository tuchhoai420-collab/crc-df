"""
ResonanceField — fixed-dimension continuous state.

The entire memory is the geometry of this vector.
It never grows. Capacity is expressed as topological richness of deformations,
not as a count of discrete records.
"""

from __future__ import annotations

import numpy as np
from dataclasses import dataclass, field


@dataclass
class ResonanceField:
    dim: int = 128
    state: np.ndarray = field(init=False)
    collapse_count: int = 0
    magnitude_log: list[float] = field(default_factory=list)

    def __post_init__(self) -> None:
        if self.dim < 8:
            raise ValueError("dim must be >= 8")
        rng = np.random.default_rng(42)
        self.state = rng.normal(0.0, 0.01, size=self.dim).astype(np.float64)
        self.state /= np.linalg.norm(self.state) + 1e-12

    def copy(self) -> "ResonanceField":
        f = ResonanceField(dim=self.dim)
        f.state = self.state.copy()
        f.collapse_count = self.collapse_count
        f.magnitude_log = list(self.magnitude_log)
        return f

    def norm(self) -> float:
        return float(np.linalg.norm(self.state))

    def project(self, vec: np.ndarray) -> np.ndarray:
        """Project an external vector into the field dimension."""
        if vec.shape[0] == self.dim:
            return vec.astype(np.float64)
        out = np.zeros(self.dim, dtype=np.float64)
        n = min(len(vec), self.dim)
        out[:n] = vec[:n]
        if len(vec) > self.dim:
            extra = vec[self.dim:]
            for i, v in enumerate(extra):
                out[i % self.dim] += v * 0.1
        norm = np.linalg.norm(out)
        if norm > 1e-12:
            out /= norm
        return out
