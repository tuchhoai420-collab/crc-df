"""
High-level interface for the CRC-DF memory operator.
"""

from __future__ import annotations

from pathlib import Path
from core.field import ResonanceField
from core.collapse import collapse
from core.stabilise import stabilise, decode_proximity
from persistence.store import save_field, load_field


class Memory:
    def __init__(self, dim: int = 128, store_path: str | Path | None = None):
        self.store_path = Path(store_path) if store_path else Path("crc_df_field.json")
        loaded = load_field(self.store_path)
        self.field = loaded if loaded is not None else ResonanceField(dim=dim)
        self._candidates: list[str] = []

    def observe(self, text: str, strength: float = 1.0) -> None:
        """Irreversibly collapse the observation into the field."""
        collapse(self.field, text, strength=strength)
        if text not in self._candidates:
            self._candidates.append(text)
            if len(self._candidates) > 200:
                self._candidates = self._candidates[-150:]

    def recall(self, query: str, top_k: int = 3) -> list[tuple[str, float]]:
        """Stabilise the field under the query and return nearest candidates."""
        settled = stabilise(self.field, query)
        return decode_proximity(settled, self._candidates, self.field.dim, top_k=top_k)

    def feedback(self, text: str, positive: bool = True) -> None:
        """Local reinforcement: positive feedback strengthens the deformation."""
        strength = 0.35 if positive else 0.1
        collapse(self.field, text, strength=strength)

    def save(self) -> None:
        save_field(self.field, self.store_path)

    def stats(self) -> dict:
        return {
            "dim": self.field.dim,
            "collapse_count": self.field.collapse_count,
            "norm": self.field.norm(),
            "candidates": len(self._candidates),
        }
