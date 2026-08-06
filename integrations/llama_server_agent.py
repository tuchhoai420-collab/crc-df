#!/usr/bin/env python3
"""
CRC-DF × llama-server — real agent loop

Uses your already-compiled llama-server (OpenAI-compatible API).
CRC-DF is bound as tools via the C shared library.

1) Terminal A — start the server:
   ./llama-server -m /path/to/model.gguf --port 8080 -c 4096

2) Terminal B — run the agent:
   python integrations/llama_server_agent.py
   python integrations/llama_server_agent.py --base-url http://127.0.0.1:8080/v1
"""

from __future__ import annotations

import argparse
import ctypes
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


# ---------------------------------------------------------------------------
# CRC-DF bindings
# ---------------------------------------------------------------------------

class CrcDF:
    def __init__(self, lib_path: str, store_path: str = "crc_df_field.bin"):
        self.lib = ctypes.CDLL(lib_path)
        self.lib.crc_set_store_path.argtypes = [ctypes.c_char_p]
        self.lib.crc_load.restype = ctypes.c_int
        self.lib.crc_observe.argtypes = [ctypes.c_char_p, ctypes.c_double]
        self.lib.crc_recall.argtypes = [
            ctypes.c_char_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_uint32
        ]
        self.lib.crc_recall.restype = ctypes.c_int
        self.lib.crc_sleep.argtypes = [ctypes.c_uint32]
        self.lib.crc_reset.argtypes = []
        self.lib.crc_collapse_count.restype = ctypes.c_uint64
        self.lib.crc_log_len.restype = ctypes.c_uint32

        self.lib.crc_set_store_path(store_path.encode())
        self.lib.crc_load()

    def observe(self, text: str, strength: float = 1.0) -> str:
        self.lib.crc_observe(text.encode("utf-8"), float(strength))
        return f"observed (strength={strength:.2f}, collapses={self.collapse_count()})"

    def recall(self, query: str, top_k: int = 4) -> str:
        buf = ctypes.create_string_buffer(16384)
        n = self.lib.crc_recall(query.encode("utf-8"), buf, 16384, int(top_k))
        if n <= 0:
            return "(no relevant memory)"
        lines = buf.value.decode("utf-8", errors="replace").strip().split("\n")
        return "\n".join(f"- {line}" for line in lines if line)

    def sleep(self, cycles: int = 2) -> str:
        self.lib.crc_sleep(int(cycles))
        return f"sleep done ({cycles} cycles)"

    def reset(self) -> str:
        self.lib.crc_reset()
        return "field reset"

    def collapse_count(self) -> int:
        return int(self.lib.crc_collapse_count())

    def log_len(self) -> int:
        return int(self.lib.crc_log_len())


TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "memory_observe",
            "description": (
                "Permanently store a fact, preference, diagnosis or successful resolution "
                "into long-term geometric memory. Use strength 1.5 for resolutions that worked, "
                "1.0 for normal facts, 0.5 for uncertain notes."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "text": {"type": "string"},
                    "strength": {"type": "number", "default": 1.0},
                },
                "required": ["text"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "memory_recall",
            "description": (
                "Retrieve the most relevant past observations and resolution trajectories. "
                "Call this BEFORE answering about past incidents, preferences, or environment."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"},
                    "top_k": {"type": "integer", "default": 4},
                },
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "memory_sleep",
            "description": "Run selective geometric consolidation (reinforce high-value memories).",
            "parameters": {
                "type": "object",
                "properties": {"cycles": {"type": "integer", "default": 2}},
            },
        },
    },
]


def dispatch(crc: CrcDF, name: str, arguments: dict) -> str:
    if name == "memory_observe":
        return crc.observe(arguments.get("text", ""), float(arguments.get("strength", 1.0)))
    if name == "memory_recall":
        return crc.recall(arguments.get("query", ""), int(arguments.get("top_k", 4)))
    if name == "memory_sleep":
        return crc.sleep(int(arguments.get("cycles", 2)))
    return f"unknown tool: {name}"


# ---------------------------------------------------------------------------
# Minimal OpenAI-compatible client (stdlib only)
# ---------------------------------------------------------------------------

def chat_completion(base_url: str, payload: dict) -> dict:
    url = base_url.rstrip("/") + "/chat/completions"
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.URLError as e:
        raise SystemExit(
            f"Cannot reach llama-server at {url}\n"
            f"Start it first, e.g.:\n"
            f"  ./llama-server -m model.gguf --port 8080 -c 4096\n\n"
            f"Error: {e}"
        ) from e


SYSTEM = """You are a local technical assistant with access to an exogenous geometric memory (CRC-DF).

Rules:
- Before answering about past incidents, preferences, or environment: call memory_recall.
- After successfully solving a problem: call memory_observe with the resolution and strength 1.5.
- Store stable facts/preferences with strength 1.0.
- You may call memory_sleep between tasks.
- Be concise. Prefer tool calls over speculation when memory can help.
"""


def run(base_url: str, lib_path: str, model: str | None):
    crc = CrcDF(lib_path)
    print(f"[crc-df] collapses={crc.collapse_count()}  log_len={crc.log_len()}")
    print(f"[llama]  {base_url}")
    print("Commands: /reset /sleep /stats /quit")
    print("-" * 60)

    messages: list[dict[str, Any]] = [{"role": "system", "content": SYSTEM}]

    while True:
        try:
            user = input("\nyou> ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nbye")
            break

        if not user:
            continue
        if user in ("/quit", "/exit", "q"):
            break
        if user == "/reset":
            print(crc.reset())
            continue
        if user.startswith("/sleep"):
            parts = user.split()
            cycles = int(parts[1]) if len(parts) > 1 else 2
            print(crc.sleep(cycles))
            continue
        if user == "/stats":
            print(f"collapses={crc.collapse_count()}  log_len={crc.log_len()}")
            continue

        messages.append({"role": "user", "content": user})

        for _ in range(8):
            payload: dict[str, Any] = {
                "messages": messages,
                "tools": TOOLS,
                "tool_choice": "auto",
                "temperature": 0.3,
                "max_tokens": 512,
            }
            if model:
                payload["model"] = model

            resp = chat_completion(base_url, payload)
            msg = resp["choices"][0]["message"]
            messages.append(msg)

            tool_calls = msg.get("tool_calls") or []
            if not tool_calls:
                content = msg.get("content") or ""
                print(f"\nassistant> {content}")
                break

            for tc in tool_calls:
                fn = tc["function"]["name"]
                raw_args = tc["function"].get("arguments") or "{}"
                try:
                    args = json.loads(raw_args) if isinstance(raw_args, str) else raw_args
                except json.JSONDecodeError:
                    args = {}
                print(f"  [tool] {fn}({args})")
                result = dispatch(crc, fn, args)
                print(f"  [tool→] {result[:400]}")
                messages.append(
                    {
                        "role": "tool",
                        "tool_call_id": tc.get("id", "call"),
                        "content": result,
                    }
                )
        else:
            print("(tool loop limit reached)")


def find_lib(explicit: str | None) -> str:
    if explicit:
        return explicit
    for c in [
        Path("zig-out/lib/libcrc_df.so"),
        Path("zig-out/lib/libcrc_df.dylib"),
        Path("./libcrc_df.so"),
    ]:
        if c.exists():
            return str(c.resolve())
    raise SystemExit("libcrc_df not found. Run: zig build -Doptimize=ReleaseFast")


def main():
    p = argparse.ArgumentParser(description="CRC-DF agent on top of llama-server")
    p.add_argument("--base-url", default="http://127.0.0.1:8080/v1",
                   help="llama-server OpenAI base URL")
    p.add_argument("--lib", default=None, help="path to libcrc_df.so")
    p.add_argument("--model", default=None,
                   help="model name to send (optional; some servers ignore it)")
    args = p.parse_args()
    run(args.base_url, find_lib(args.lib), args.model)


if __name__ == "__main__":
    main()
