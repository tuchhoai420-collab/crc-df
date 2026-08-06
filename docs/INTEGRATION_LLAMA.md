# Integración real CRC-DF × llama.cpp

## Compilar la memoria

```bash
zig build -Doptimize=ReleaseFast
# genera:
#   zig-out/bin/crc-df
#   zig-out/lib/libcrc_df.so   (+ include/crc_df.h)
```

## Opción A — Loop real con llama-cpp-python (recomendado)

```bash
pip install llama-cpp-python

python integrations/llama_crc_agent.py \
  --model /ruta/a/tu/modelo.gguf \
  --n-gpu-layers 0
```

El agente expone tres tools al modelo:

| Tool | Función |
|------|--------|
| `memory_observe` | Colapsa un hecho/resolución en el campo (strength configurable) |
| `memory_recall`  | Estabiliza + decodifica las observaciones más cercanas |
| `memory_sleep`   | Presión geométrica selectiva (solo refuerza lo fuerte) |

Comandos locales del loop:
- `/stats` — estado del campo
- `/sleep [n]` — consolidación manual
- `/reset` — borra el campo
- `/quit`

### Ejemplo de sesión

```
you> el servidor de staging usa PostgreSQL 15
  [tool] memory_observe({'text': '...', 'strength': 1.0})

you> hubo un conflicto openssl y se resolvió pineando 3.0.12 y rebuild
  [tool] memory_observe({'text': 'resolution: ...', 'strength': 1.5})

you> cómo resolvimos lo de openssl?
  [tool] memory_recall({'query': 'openssl conflicto resolución'})
  assistant> La vez pasada se pineó openssl a 3.0.12 y se reconstruyó el contenedor...
```

## Opción B — llama-server + tools externas

1. Levantá el server:
```bash
./llama-server -m model.gguf --port 8080
```

2. Usá el mismo `CrcDF` (ctypes) desde cualquier cliente que hable OpenAI-compatible y soporte tool calls (incluyendo el propio client de llama.cpp si está habilitado).

El binding C es idéntico al del agente Python.

## Opción C — Solo C/C++ (sin Python)

```c
#include "crc_df.h"

// en tu hook de tool de llama.cpp:
crc_observe(resolution_text, 1.5);
char buf[8192];
int n = crc_recall(user_query, buf, sizeof buf, 4);
```

Link: `-Lzig-out/lib -lcrc_df`

## Principios de integración (alien)

- El modelo **emite** deformaciones y queries. No interpreta la geometría.
- `strength` es presión selectiva, no opinión.
- `sleep` no es reflexión: es optimización de campo.
- Costo de memoria por ciclo: ~6 µs. Irrelevante frente al forward del LLM.
