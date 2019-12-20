#!/usr/bin/env bash
# run_test.sh <rtl_dir> <name> [--len N] [--mbps R] [--extra N] [--nframes N] [--snr "a b"]
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
RTL=$1; NAME=$2; shift 2
LEN=100; MBPS=6; EXTRA=0; NF=1; SNR=""
while [ $# -gt 0 ]; do case $1 in
  --len) LEN=$2;; --mbps) MBPS=$2;; --extra) EXTRA=$2;; --nframes) NF=$2;; --snr) SNR=$2;;
  *) echo "bad arg $1"; exit 1;; esac; shift 2; done
OUT=$ROOT/results/$NAME
rm -rf "$OUT"; mkdir -p "$OUT"
SIGW=$(python3 $ROOT/model/harness.py stim --out "$OUT" --len $LEN --mbps $MBPS --extra $EXTRA)
$ROOT/sim/run_sim.sh "$RTL" "$OUT" "$OUT/fifo.hex" "$SIGW" "$NF"
python3 $ROOT/model/harness.py check --out "$OUT" ${SNR:+--snr $SNR} | tee "$OUT/report.txt"
# A successful simulator exit alone does not imply a valid waveform.
if grep -q '\[BAD\]' "$OUT/report.txt" ||
   ! grep -q "RX summary: $NF/$NF frames decoded" "$OUT/report.txt" ||
   ! grep -q 'holes in tx_valid inside frames: 0' "$OUT/report.txt"; then
    exit 1
fi
