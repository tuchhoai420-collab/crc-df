# Integración de CRC-DF con llama.cpp / modelos locales

CRC-DF se expone como **sustrato de memoria geométrica exógena**.  
El modelo local (llama.cpp u otro) no "entiende" la memoria: solo emite observaciones y queries. La geometría hace el resto.

## 1. Compilar la biblioteca compartida

```bash
zig build -Doptimize=ReleaseFast
# produce:
#   zig-out/lib/libcrc_df.so   (Linux)
#   zig-out/lib/libcrc_df.dylib (macOS)
#   zig-out/bin/crc-df         (CLI)
```

Header público: `include/crc_df.h`

## 2. Uso desde C / C++ (llama.cpp tool / server hook)

```c
#include "crc_df.h"

void agent_on_resolution(const char *fix_text) {
    /* Las resoluciones se graban con strength alta */
    crc_observe(fix_text, 1.5);
}

void agent_before_answering(const char *user_query, char *memory_ctx, size_t n) {
    /* Recuperar trayectoria / hechos relevantes */
    int lines = crc_recall(user_query, memory_ctx, n, 4);
    if (lines > 0) {
        /* Prefijar el contexto del modelo con lo recuperado */
    }
}

void agent_idle() {
    /* Presión geométrica selectiva en background */
    crc_sleep(2);
}
```

## 3. Patrón de tool-calling (recomendado)

Definir dos tools para el modelo:

### Tool: `memory_observe`
```json
{
  "name": "memory_observe",
  "description": "Permanently store a fact, preference, diagnosis or resolution into long-term geometric memory. Use higher strength (1.5) for successful resolutions.",
  "parameters": {
    "text": "string",
    "strength": "number (default 1.0)"
  }
}
```

### Tool: `memory_recall`
```json
{
  "name": "memory_recall",
  "description": "Retrieve the most relevant past observations / resolution trajectories for a query.",
  "parameters": {
    "query": "string",
    "top_k": "integer (default 4)"
  }
}
```

El host (llama.cpp server, llama-cli con grammar, o un wrapper Python) implementa las tools llamando a `crc_observe` / `crc_recall`.

## 4. Wrapper Python mínimo (ctypes)

```python
import ctypes, os

lib = ctypes.CDLL("./zig-out/lib/libcrc_df.so")

lib.crc_observe.argtypes = [ctypes.c_char_p, ctypes.c_double]
lib.crc_recall.argtypes  = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_uint32]
lib.crc_recall.restype   = ctypes.c_int
lib.crc_sleep.argtypes   = [ctypes.c_uint32]
lib.crc_reset.argtypes   = []

def observe(text: str, strength: float = 1.0):
    lib.crc_observe(text.encode(), strength)

def recall(query: str, top_k: int = 4) -> list[str]:
    buf = ctypes.create_string_buffer(8192)
    n = lib.crc_recall(query.encode(), buf, 8192, top_k)
    if n <= 0:
        return []
    return buf.value.decode().strip().split("\n")

def sleep(cycles: int = 2):
    lib.crc_sleep(cycles)
```

Este wrapper se puede enganchar como tools de cualquier agente local (llama-cpp-python, oobabooga, text-generation-webui, etc.).

## 5. Mentalidad de integración (alien)

- El modelo **no** es el dueño de la memoria.
- El modelo es un emisor de deformaciones (observe) y de perturbaciones (recall).
- `strength` es presión selectiva, no "importancia subjetiva".
- `sleep` no es reflexión: es optimización de campo en background.
- Nunca se borra: solo se deja de reforzar lo débil (hambre geométrica).

## 6. Flujo típico con un modelo local

```
Usuario → modelo
         ↘ memory_recall(query)     → CRC-DF devuelve trayectoria/hechos
modelo usa el contexto recuperado
         ↘ (si resolvió algo) memory_observe(resolución, 1.5)
…
idle / entre turnos → crc_sleep(1..3)
```

Costo añadido por ciclo de memoria: ~6 µs. Irrelevante frente a cualquier forward pass de un LLM.
