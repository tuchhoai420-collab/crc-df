# Perfil de usuario persistente (CRC-DF)

Capa de **identidad** separada del campo geom\u00e9trico.

## Reglas

- Persistente en `crc_df_profile.txt`
- **No** se borra con `crc-df reset` (el reset solo limpia el campo)
- **No** decae con `sleep`
- Solo se elimina con `profile forget <id>` (o pedido expl\u00edcito del usuario v\u00eda agente)
- Dedup: mismo kind + mismo texto reutiliza el id existente

## Kinds

| Kind | Uso |
|------|-----|
| `preference` | Gustos, tono, formato de respuesta |
| `methodology` | C\u00f3mo investigar / ejecutar |
| `constraint` | Restricciones operativas |
| `topic` | Temas preferidos o relevantes |

## CLI

```bash
./zig-out/bin/crc-df profile list
./zig-out/bin/crc-df profile add preference "respuestas cortas y modo silencioso"
./zig-out/bin/crc-df profile add methodology "investigar primero en documentaci\u00f3n oficial"
./zig-out/bin/crc-df profile add constraint "no reiniciar servicios en horario laboral"
./zig-out/bin/crc-df profile forget 2
```

## Con el agente (Qwen / llama-server)

El host debe inyectar el perfil en cada turno (texto corto) **antes** del recall geom\u00e9trico.
El modelo solo agrega preferencias nuevas v\u00eda tool/comando expl\u00edcito; no reescribe el perfil en silencio.
