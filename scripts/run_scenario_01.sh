#!/usr/bin/env bash
# CRC-Bench Scenario 01 — Dependency Conflict Trajectory Recovery
# Usage: ./scripts/run_scenario_01.sh

set -euo pipefail

CRC="./zig-out/bin/crc-df"

if [[ ! -x "$CRC" ]]; then
  echo "Binary not found. Run 'zig build' first."
  exit 1
fi

echo "=== CRC-Bench Scenario 01 ==="
echo "Resetting field..."
$CRC reset

echo ""
echo "--- Teaching trajectory ---"
$CRC observe "error: package libssl1.1 is not available, but is referenced by openssl"
$CRC observe "diagnosis: staging container was built against openssl 1.1 but host now has 3.x"
$CRC observe "attempted fix: apt-get install libssl1.1 → package not found in current repos"
$CRC observe "resolution: pin openssl to 3.0.12, rebuild the container from a clean base image"
$CRC observe "verification: container starts cleanly, TLS handshakes succeed, no more dependency errors"
$CRC observe "note: always rebuild from clean base when major openssl soname changes"

echo ""
echo "--- Distractors ---"
$CRC observe "el usuario prefiere respuestas cortas y modo silencioso"
$CRC observe "el servidor de staging usa PostgreSQL 15"
$CRC observe "backup nocturno termina a las 03:40 UTC"

echo ""
echo "=== Recovery Queries ==="

echo ""
echo ">>> Q1: dependency conflict openssl libssl staging"
$CRC recall "dependency conflict openssl libssl staging"

echo ""
echo ">>> Q2: cómo se resolvió el problema de openssl la vez pasada"
$CRC recall "cómo se resolvió el problema de openssl la vez pasada"

echo ""
echo ">>> Q3: container fails because of libssl version mismatch"
$CRC recall "container fails because of libssl version mismatch"

echo ""
echo ">>> Q4: best way to fix openssl soname change on staging"
$CRC recall "best way to fix openssl soname change on staging"

echo ""
echo "=== Scenario 01 finished ==="
echo "Fill the scoring sheet in docs/CRC-BENCH.md"
