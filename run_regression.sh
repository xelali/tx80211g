#!/usr/bin/env bash
# run_regression.sh [rtl_dir]   (default: rtl)  -- runs the standard set of cases and prints a summary
ROOT=$(cd "$(dirname "$0")" && pwd); RTL=${1:-rtl}; TAG=$(basename $(realpath $RTL) | tr / _)
cd "$ROOT"
cases=(
  "len98    --len 98  --nframes 3"                     # (L+2)%3 == 2
  "len99    --len 99  --nframes 3"                     # (L+2)%3 == 0
  "len100   --len 100 --nframes 3"                     # (L+2)%3 == 1
  "leftover --len 0   --extra 7 --nframes 3"           # junk after the frame: core must drain it
  "len1500  --len 1500 --nframes 2"
  "awgn     --len 100 --snr '2 3 4 6'"
)
printf "%-10s %-6s %s\n" case BAD "RX result"
failed=0
for c in "${cases[@]}"; do
  set -- $c; name=$1; shift
  eval ./run_test.sh $RTL reg_${TAG}_$name "$@" > /dev/null 2>&1 || { printf "%-10s %s\n" $name "SIM FAILED"; failed=1; continue; }
  r=results/reg_${TAG}_$name/report.txt
  printf "%-10s %-6s %s\n" $name "$(grep -c '\[BAD\]' $r)" "$(grep 'RX summary' $r | sed 's/-- RX summary: //')"
  grep AWGN $r | sed 's/^/           /'
done
exit "$failed"
