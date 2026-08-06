#!/usr/bin/env python3
"""
CRC-DF × llama.cpp — real agent loop

The model does not "own" memory. It only emits observations and queries.
CRC-DF applies irreversible geometric pressure.

Requirements:
  pip install llama-cpp-python
  (and a GGUF model on disk)

Usage:
  python integrations/llama_crc_agent.py --model /path/to/model.gguf
  python integrations/llama_crc_agent.py --model /path/to/model.gguf --lib ./zig-out/lib/libcrc_df.so
"""

from __future__ import annotations

import argparse
import ctypes
import json
import os
import sys
from pathlib import Path
from typing import Optional


# ---------------------------------------------------------------------------
# CRC-DF C-API bindings
# ---------------------------------------------------------------------------

class CrcDF:
    def __init__(self, lib_path: str, store_path: str = "crc_df_field.bin"):
        self.lib = ctypes.CDLL(lib_path)

        self.lib.crc_set_store_path.argtypes = [ctypes.c_char_p]
        self.lib.crc_load.restype = ctypes.c_int
        self.lib.crc_save.restype = ctypes.c_int
        self.lib.crc_observe.argtypes = [ctypes.c_char_p, ctypes.c_double]
        self.lib.crc_recall.argtypes = [
            ctypes.c_char_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_uint32
        ]
        self.lib.crc_recall.restype = ctypes.c_int
        self.lib.crc_sleep.argtypes = [ctypes.c_uint32]
        self.lib.crc_reset.argtypes = []
        self.lib.crc_collapse_count.restype = ctypes.c_uint64
        self.lib.crc_log_len.restype = ctypes.c_uint32
        self.lib.crc_norm.restype = ctypes.c_double

        self.lib.crc_set_store_path(store_path.encode())
        self.lib.crc_load()  # ok if file missing

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


# ---------------------------------------------------------------------------
# Tool definitions for the model
# ---------------------------------------------------------------------------

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
                    "text": {"type": "string", "description": "The observation to store"},
                    "strength": {
                        "type": "number",
                        "description": "0.3–2.0, default 1.0",
                        "default": 1.0,
                    },
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
                "Retrieve the most relevant past observations and resolution trajectories "
                "for a query. Call this BEFORE answering questions about past incidents, "
                "preferences, or environment facts."
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
                "properties": {
                    "cycles": {"type": "integer", "default": 2},
                },
            },
        },
    },
]


def dispatch_tool(crc: CrcDF, name: str, arguments: dict) -> str:
    if name == "memory_observe":
        return crc.observe(arguments["text"], float(arguments.get("strength", 1.0)))
    if name == "memory_recall":
        return crc.recall(arguments["query"], int(arguments.get("top_k", 4)))
    if name == "memory_sleep":
        return crc.sleep(int(arguments.get("cycles", 2)))
    return f"unknown tool: {name}"


# ---------------------------------------------------------------------------
# Agent loop (llama-cpp-python)
# ---------------------------------------------------------------------------

SYSTEM = """You are a local technical assistant with access to an exogenous geometric memory (CRC-DF).

Rules:
- Before answering about past incidents, preferences, or environment: call memory_recall.
- After successfully solving a problem: call memory_observe with the resolution text and strength 1.5.
- Store stable facts/preferences with strength 1.0.
- You may call memory_sleep occasionally between tasks.
- Be concise. Prefer actions (tool calls) over speculation when memory can help.
"""


def run_loop(model_path: str, lib_path: str, n_ctx: int = 4096, n_gpu_layers: int = 0):
    try:
        from llama_cpp import Llama
    except ImportError:
        print("Install llama-cpp-python:  pip install llama-cpp-python", file=sys.stderr)
        sys.exit(1)

    crc = CrcDF(lib_path)
    print(f"[crc-df] lib={lib_path}  collapses={crc.collapse_count()}  log_len={crc.log_len()}")

    llm = Llama(
        model_path=model_path,
        n_ctx=n_ctx,
        n_gpu_layers=n_gpu_layers,
        verbose=False,
    )

    messages = [{"role": "system", "content": SYSTEM}]

    print("CRC-DF × llama.cpp agent ready. Commands: /reset /sleep /stats /quit")
    print("-" * 60)

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

        # Allow multi-step tool use
        for _ in range(6):
            response = llm.create_chat_completion(
                messages=messages,
                tools=TOOLS,
                tool_choice="auto",
                temperature=0.3,
                max_tokens=512,
            )
            msg = response["choices"][0]["message"]
            messages.append(msg)

            tool_calls = msg.get("tool_calls") or []
            if not tool_calls:
                content = msg.get("content") or ""
                print(f"\nassistant> {content}")
                break

            for tc in tool_calls:
                fn = tc["function"]["name"]
                try:
                    args = json.loads(tc["function"]["arguments"] or "{}")
                except json.JSONDecodeError:
                    args = {}
                print(f"  [tool] {fn}({args})")
                result = dispatch_tool(crc, fn, args)
                print(f"  [tool result] {result[:300]}")
                messages.append(
                    {
                        "role": "tool",
                        "tool_call_id": tc.get("id", "call"),
                        "content": result,
                    }
                )
        else:
            print("(tool loop limit reached)")


def main():
    p = argparse.ArgumentParser(description="CRC-DF × llama.cpp agent loop")
    p.add_argument("--model", required=True, help="Path to GGUF model")
    p.add_argument(
        "--lib",
        default=None,
        help="Path to libcrc_df.so (default: auto-detect zig-out/lib)",
    )
    p.add_argument("--n-ctx", type=int, default=4096)
    p.add_argument("--n-gpu-layers", type=int, default=0, help="GPU layers (0=CPU only)")
    args = p.parse_args()

    lib = args.lib
    if lib is None:
        candidates = [
            Path("zig-out/lib/libcrc_df.so"),
            Path("zig-out/lib/libcrc_df.dylib"),
            Path("./libcrc_df.so"),
        ]
        for c in candidates:
            if c.exists():
                lib = str(c.resolve())
                break
        if lib is None:
            print("libcrc_df not found. Run: zig build -Doptimize=ReleaseFast", file=sys.stderr)
            sys.exit(1)

    if not Path(args.model).exists():
        print(f"Model not found: {args.model}", file=sys.stderr)
        sys.exit(1)

    run_loop(args.model, lib, n_ctx=args.n_ctx, n_gpu_layers=args.n_gpu_layers)


if __name__ == "__main__":
    main()
