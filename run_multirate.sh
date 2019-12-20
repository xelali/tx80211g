#!/usr/bin/env bash
# All rates, short/long frames and rate changes without resetting the core.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"
OUT=$ROOT/results/multirate
mkdir -p "$OUT"
: > "$OUT/vectors.txt"
count=0
for len in 0 100 1500; do
    for rate in 6 9 12 18 24 36 48 54; do
        dir=$OUT/rate${rate}_len${len}
        mkdir -p "$dir"
        sig=$(python3 model/harness.py stim --out "$dir" --len "$len" --mbps "$rate")
        printf '%s %s %s\n' "$dir/fifo.hex" "$sig" "$dir" >> "$OUT/vectors.txt"
        count=$((count + 1))
    done
done
./sim/run_sim.sh "${1:-rtl}" "$OUT" "$OUT/rate6_len0/fifo.hex" 0 "$count" "$OUT/vectors.txt"
failed=0
: > "$OUT/summary.txt"
for dir in "$OUT"/rate*; do
    python3 model/harness.py check --out "$dir" > "$dir/report.txt"
    if grep -q '\[BAD\]' "$dir/report.txt" ||
       ! grep -q 'RX summary: 1/1 frames decoded' "$dir/report.txt" ||
       ! grep -q 'holes in tx_valid inside frames: 0' "$dir/report.txt"; then
        echo "FAIL $(basename "$dir")" | tee -a "$OUT/summary.txt"
        failed=1
    else
        echo "PASS $(basename "$dir")" | tee -a "$OUT/summary.txt"
    fi
done
exit "$failed"
