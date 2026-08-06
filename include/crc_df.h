/**
 * CRC-DF — C API
 * Campo de Resonancia Colapsable de Dimensión Fija
 *
 * Exogenous geometric memory substrate.
 * Safe to call from llama.cpp tool loops, Python ctypes, etc.
 *
 * Thread-safety: single global field. Not thread-safe yet.
 */
#ifndef CRC_DF_H
#define CRC_DF_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stddef.h>

/** Set persistent store path (default: "crc_df_field.bin"). */
void crc_set_store_path(const char *path);

/** Load field from store. Returns 0 on success, -1 if file missing/invalid. */
int crc_load(void);

/** Save field to store. Returns 0 on success, -1 on error. */
int crc_save(void);

/**
 * Irreversibly collapse an observation into the field.
 * @param text      UTF-8 observation
 * @param strength  typically 0.3 (weak) … 1.0 (normal) … 1.5–2.0 (important)
 */
void crc_observe(const char *text, double strength);

/**
 * Stabilise under query and decode top-k nearest past observations.
 * Writes newline-separated results into out_buf.
 * @return number of lines written (0 if nothing recalled)
 */
int crc_recall(const char *query, char *out_buf, size_t out_buf_len, uint32_t top_k);

/**
 * Alien sleep: selective geometric pressure.
 * Reinforces high-strength recent collapses; starves low-value ones.
 */
void crc_sleep(uint32_t cycles);

/** Reset field to initial state and persist. */
void crc_reset(void);

/** Diagnostics */
uint64_t crc_collapse_count(void);
uint32_t crc_log_len(void);
double   crc_norm(void);

#ifdef __cplusplus
}
#endif

#endif /* CRC_DF_H */
