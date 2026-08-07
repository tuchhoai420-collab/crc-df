#!/usr/bin/env python3
"""
CRC-DF × llama-server — real agent loop (dual mode)

Modes:
  auto  — try native tool_calls; if model emits text tool blocks, parse them too
  tools — OpenAI-style tools only
  text  — structured text tool calls only (works with almost any GGUF)

Host-side auto-recall:
  Before each user turn, CRC-DF recall is injected into context so memory
  works even if the model never calls tools.

Terminal A:
  ./llama-server -m /path/to/model.gguf --port 8080 -c 4096

Terminal B:
  python integrations/llama_server_agent.py
  python integrations/llama_server_agent.py --mode text
  python integrations/llama_server_agent.py --no-auto-recall
"""

from __future__ import annotations

import argparse
import ctypes
import json
import re
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
                "Store a fact, preference, diagnosis or successful resolution. "
                "strength 1.5 for resolutions, 1.0 for facts, 0.5 for uncertain notes."
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
            "description": "Retrieve relevant past observations / resolution trajectories.",
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
            "description": "Selective geometric consolidation.",
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


# Parse text-mode tool calls:
#   <tool>memory_recall
#   {"query": "...", "top_k": 4}
#   </tool>
TOOL_BLOCK = re.compile(
    r"<tool>\s*([a-zA-Z0-9_]+)\s*\n(.*?)\n\s*</tool>",
    re.DOTALL,
)


def parse_text_tools(content: str) -> list[tuple[str, dict]]:
    found: list[tuple[str, dict]] = []
    for m in TOOL_BLOCK.finditer(content or ""):
        name = m.group(1).strip()
        raw = m.group(2).strip()
        try:
            args = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            args = {"text": raw} if name == "memory_observe" else {"query": raw}
        found.append((name, args))
    return found


def strip_tool_blocks(content: str) -> str:
    return TOOL_BLOCK.sub("", content or "").strip()


# ---------------------------------------------------------------------------
# HTTP client
# ---------------------------------------------------------------------------

def chat_completion(base_url: str, payload: dict) -> dict:
    url = base_url.rstrip("/") + "/chat/completions"
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json"}, method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.URLError as e:
        raise SystemExit(
            f"Cannot reach llama-server at {url}\n"
            f"Start it first:\n"
            f"  ./llama-server -m model.gguf --port 8080 -c 4096\n\n"
            f"Error: {e}"
        ) from e


SYSTEM_TOOLS = """You are a local technical assistant with exogenous geometric memory (CRC-DF).

Rules:
- Before answering about past incidents/preferences/environment: call memory_recall.
- After solving something: memory_observe with strength 1.5 for resolutions, 1.0 for facts.
- Be concise.
"""

SYSTEM_TEXT = """You are a local technical assistant with exogenous geometric memory (CRC-DF).

To use memory, emit ONE or more blocks exactly like this:

<tool>memory_recall
{"query": "openssl dependency conflict", "top_k": 4}
</tool>

<tool>memory_observe
{"text": "resolution: pin openssl to 3.0.12 and rebuild container", "strength": 1.5}
</tool>

<tool>memory_sleep
{"cycles": 2}
</tool>

Rules:
- Before answering about past incidents/preferences/environment: call memory_recall first.
- After solving something: memory_observe with strength 1.5 for resolutions.
- After tool results are provided, give a concise final answer without tool blocks.
"""


def run(base_url: str, lib_path: str, model: str | None, mode: str, auto_recall: bool):
    crc = CrcDF(lib_path)
    print(f"[crc-df] collapses={crc.collapse_count()}  log_len={crc.log_len()}")
    print(f"[llama]  {base_url}")
    print(f"[mode]   {mode}   auto_recall={auto_recall}")
    print("Commands: /observe <text> | /recall <q> | /sleep [n] | /stats | /reset | /quit")
    print("-" * 60)

    system = SYSTEM_TOOLS if mode == "tools" else SYSTEM_TEXT
    if mode == "auto":
        system = SYSTEM_TEXT + "\n\nIf the runtime provides native function tools, you may use those instead of <tool> blocks."

    messages: list[dict[str, Any]] = [{"role": "system", "content": system}]

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
        if user.startswith("/observe "):
            text = user[len("/observe "):].strip()
            print(crc.observe(text, 1.0))
            continue
        if user.startswith("/recall "):
            q = user[len("/recall "):].strip()
            print(crc.recall(q))
            continue

        # Host-side auto-recall: memory works even if model ignores tools
        if auto_recall and crc.log_len() > 0:
            mem = crc.recall(user, top_k=4)
            if mem != "(no relevant memory)":
                print(f"  [auto-recall]\n{mem}")
                messages.append(
                    {
                        "role": "system",
                        "content": f"Relevant geometric memory for this turn:\n{mem}",
                    }
                )

        messages.append({"role": "user", "content": user})

        for _ in range(8):
            payload: dict[str, Any] = {
                "messages": messages,
                "temperature": 0.3,
                "max_tokens": 700,
            }
            if model:
                payload["model"] = model
            if mode in ("tools", "auto"):
                payload["tools"] = TOOLS
                payload["tool_choice"] = "auto"

            resp = chat_completion(base_url, payload)
            msg = resp["choices"][0]["message"]
            content = msg.get("content") or ""
            native_calls = msg.get("tool_calls") or []

            # Prefer native tool_calls; also accept text <tool> blocks
            text_calls = parse_text_tools(content) if mode in ("text", "auto") else []

            if native_calls:
                messages.append(msg)
                for tc in native_calls:
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
                continue

            if text_calls:
                messages.append({"role": "assistant", "content": content})
                for fn, args in text_calls:
                    print(f"  [tool] {fn}({args})")
                    result = dispatch(crc, fn, args)
                    print(f"  [tool→] {result[:400]}")
                    messages.append(
                        {
                            "role": "user",
                            "content": f"TOOL RESULT [{fn}]:\n{result}\n\nContinue. If you have enough, answer now without tool blocks.",
                        }
                    )
                continue

            # Final answer
            final = strip_tool_blocks(content) if content else ""
            messages.append({"role": "assistant", "content": content})
            print(f"\nassistant> {final}")
            break
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
    p = argparse.ArgumentParser(description="CRC-DF agent on llama-server")
    p.add_argument("--base-url", default="http://127.0.0.1:8080/v1")
    p.add_argument("--lib", default=None)
    p.add_argument("--model", default=None)
    p.add_argument("--mode", choices=("auto", "tools", "text"), default="auto",
                   help="auto=native tools + text blocks; text=works with any GGUF")
    p.add_argument("--no-auto-recall", action="store_true",
                   help="disable host-side recall injection each turn")
    args = p.parse_args()
    run(
        args.base_url,
        find_lib(args.lib),
        args.model,
        args.mode,
        auto_recall=not args.no_auto_recall,
    )


if __name__ == "__main__":
    main()
