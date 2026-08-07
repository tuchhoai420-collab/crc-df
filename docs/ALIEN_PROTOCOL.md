# Protocolo de identidad exógena (alien)

## Problema con el enfoque humano

Los stacks actuales inyectan memoria así:

```
System: The user prefers short answers. Do not restart services...
```

Eso es **comunicación diseñada para humanos**: verbosa, ambigua, cara en tokens,
fácil de diluir en el contexto del LLM.

Si dos sistemas de IA pudieran inventar su propio canal, no se mandarían párrafos.
Se mandarían **marcos de presión** — señales mínimas que deforman el estado
del receptor.

## Principio CRC-DF

La identidad del usuario no es un cuento. Es un conjunto de **constraints
operativas** con tipo y prioridad. El canal óptimo:

1. **Denso** — pocos bytes, sin sintaxis social.
2. **Tipado** — el receptor no tiene que inferir el rol del dato.
3. **Dual** —
   - canal geométrico (campo CRC-DF): recall por resonancia
   - canal simbólico compacto (frames): lo que el LLM local aún necesita leer
4. **No narrativo** — no “el usuario prefiere…”; solo `PREF|...`.

## Formato de frame (canal simbólico)

Una línea por entrada de perfil:

```
@ID <KIND> <text>
```

| KIND | Código | Significado |
|------|--------|------------|
| preference | `PREF` | sesgo de estilo / salida |
| methodology | `METH` | procedimiento de trabajo |
| constraint | `LOCK` | restricción dura (no negociable) |
| topic | `TOPC` | foco temático |

Ejemplo de bloque de identidad (lo que ve el modelo):

```
<<ID
@1 PREF respuestas cortas y modo silencioso
@2 METH investigar primero en documentación oficial
@3 LOCK no reiniciar servicios en horario laboral
@4 TOPC sistemas, redes, openssl
ID>>
```

No hay cortesía, no hay explicación. El modelo se instruye una sola vez:

> Tratar `<<ID ... ID>>` como constraints operativas. `LOCK` > `PREF` > resto.

## Canal geométrico (priming)

Además del bloque simbólico, cada entrada de perfil se puede **colapsar**
en el campo con strength fija alta (p.ej. 1.2) bajo un prefijo de rol:

```
PREF:respuestas cortas y modo silencioso
LOCK:no reiniciar servicios en horario laboral
```

Así el `recall` geométrico también puede devolver identidad sin pasar por
el texto del perfil. Dos caminos, un solo estado de verdad (`crc_df_profile.txt`).

## Por qué esto es más “alien”

- Minimiza ancho de banda (tokens).
- Separa **identidad** (perfil) de **experiencia** (trayectorias).
- No pide al LLM que “entienda al usuario”; le impone frames.
- El olvido solo ocurre por señal explícita (`forget`), no por dilución.
- Compatible con Qwen3-4B: el modelo no administra memoria; solo obedece frames.

## Lo que no hacemos

- System prompts largos en prosa.
- Re-narrar el perfil cada turno con sinónimos.
- Dejar que el LLM reescriba preferencias sin tool explícito.
