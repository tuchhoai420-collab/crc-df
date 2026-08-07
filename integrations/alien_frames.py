"""
Alien identity frames for CRC-DF.

Dense, typed, non-narrative encoding of the persistent profile.
Readable by a small local LLM without anthropomorphic prose.
"""

from __future__ import annotations

from pathlib import Path

KIND_CODE = {
    "preference": "PREF",
    "methodology": "METH",
    "constraint": "LOCK",
    "topic": "TOPC",
}

# Priority for sorting inside the block (LOCK first)
KIND_PRIORITY = {"LOCK": 0, "PREF": 1, "METH": 2, "TOPC": 3}


def load_profile_entries(path: str | Path = "crc_df_profile.txt") -> list[tuple[int, str, str]]:
    """Return list of (id, kind, text)."""
    p = Path(path)
    if not p.exists():
        return []
    out: list[tuple[int, str, str]] = []
    for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("|", 2)
        if len(parts) != 3:
            continue
        kind, id_s, text = parts
        try:
            eid = int(id_s)
        except ValueError:
            continue
        out.append((eid, kind.strip(), text.strip()))
    return out


def encode_identity_block(entries: list[tuple[int, str, str]] | None = None,
                          path: str | Path = "crc_df_profile.txt") -> str:
    """
    Build the compact <<ID ... ID>> block.

    This is the symbolic half of the alien channel.
    Empty profile -> empty string (no noise).
    """
    if entries is None:
        entries = load_profile_entries(path)
    if not entries:
        return ""

    lines: list[tuple[int, str, int, str]] = []
    for eid, kind, text in entries:
        code = KIND_CODE.get(kind, "PREF")
        pri = KIND_PRIORITY.get(code, 9)
        lines.append((pri, code, eid, text))
    lines.sort(key=lambda x: (x[0], x[2]))

    body = "\n".join(f"@{eid} {code} {text}" for _, code, eid, text in lines)
    return f"<<ID\n{body}\nID>>"


def geometric_primers(entries: list[tuple[int, str, str]] | None = None,
                      path: str | Path = "crc_df_profile.txt") -> list[tuple[str, float]]:
    """
    Texts to collapse into CRC-DF for geometric identity resonance.
    strength: LOCK=1.4, PREF=1.2, METH=1.1, TOPC=1.0
    """
    if entries is None:
        entries = load_profile_entries(path)
    strength = {"constraint": 1.4, "preference": 1.2, "methodology": 1.1, "topic": 1.0}
    out: list[tuple[str, float]] = []
    for _, kind, text in entries:
        code = KIND_CODE.get(kind, "PREF")
        out.append((f"{code}:{text}", strength.get(kind, 1.0)))
    return out


# One-shot instruction for the local model (short, non-anthropomorphic).
ALIEN_SYSTEM = """You are a local operator bound to CRC-DF exogenous memory.

Identity arrives as frames:
  <<ID
  @id KIND text
  ID>>
KIND codes: LOCK=hard constraint, PREF=style bias, METH=procedure, TOPC=topic focus.
LOCK overrides PREF. Do not narrate the profile. Obey frames.

Experience arrives as geometric recall lines (past resolutions/facts).
Prefer recalled resolutions over re-deriving.

Memory tools (when available):
  memory_observe / memory_recall / memory_sleep
Profile changes only via explicit user request, never by inference alone.
Be concise."""
