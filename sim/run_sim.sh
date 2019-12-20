#!/usr/bin/env bash
# Run the transmitter testbench in Vivado xsim with the real Xilinx IP models.
#   run_sim.sh <rtl_dir> <out_dir> <fifo.hex> <signal_hex> [nframes]
# The IP models (sim/ip_gen, produced by gen_ip.tcl) are compiled once per rtl build dir.
set -euo pipefail
SIM=$(cd "$(dirname "$0")" && pwd)
RTL=$(cd "$1" && pwd); OUT=$(mkdir -p "$2" && cd "$2" && pwd); FIFO=$(realpath "$3"); SIGW=$4; NF=${5:-1}; VECTORS=${6:-}
# Vivado: $VIVADO_SETTINGS if set, else xsim already on PATH, else a standard install.
if [ -n "${VIVADO_SETTINGS:-}" ]; then
    source "$VIVADO_SETTINGS" >/dev/null
elif ! command -v xsim >/dev/null; then
    for s in /opt/Xilinx*/Vivado/2024.2/settings64.sh /tools/Xilinx/Vivado/2024.2/settings64.sh; do
        if [ -f "$s" ]; then source "$s" >/dev/null; break; fi
    done
fi
command -v xsim >/dev/null || { echo "xsim not found: set VIVADO_SETTINGS to Vivado 2024.2 settings64.sh" >&2; exit 1; }
BUILD=$SIM/build/$(echo "$RTL" | md5sum | cut -c1-8)
mkdir -p "$BUILD"; cd "$BUILD"
IPG=$SIM/ip_gen
if [ ! -f ip.done ]; then
  xvlog -nolog -work xil_defaultlib \
     $IPG/blk_mem_interleaver/sim/blk_mem_interleaver.v $IPG/blk_mem_itv_2/sim/blk_mem_itv_2.v \
     $IPG/blk_mem_pilot/sim/blk_mem_pilot.v $IPG/fifo_transmitter/sim/fifo_transmitter.v \
     $IPG/clk_main/clk_main_clk_wiz.v $IPG/clk_main/clk_main.v \
     $XILINX_VIVADO/data/verilog/src/glbl.v > ip_compile.log
  xvhdl -nolog -work xil_defaultlib $IPG/xfft_0/sim/xfft_0.vhd >> ip_compile.log
  touch ip.done
fi
xvlog -nolog -work xil_defaultlib $(ls $RTL/*.v | grep -v Tx80211_v1_0) $SIM/tb_tx80211.v > rtl_compile.log || { cat rtl_compile.log; exit 1; }
LIBS="-L xil_defaultlib -L xbip_utils_v3_0_14 -L axi_utils_v2_0_10 -L c_reg_fd_v12_0_10 -L xbip_dsp48_wrapper_v3_0_6 \
 -L xbip_pipe_v3_0_10 -L c_addsub_v12_0_19 -L c_shift_ram_v12_0_18 -L mult_gen_v12_0_22 -L floating_point_v7_1_19 \
 -L cmpy_v6_0_25 -L floating_point_v7_0_24 -L xfft_v9_1_13 -L blk_mem_gen_v8_4_9 -L fifo_generator_v13_2_11 \
 -L unisims_ver -L unimacro_ver -L secureip -L xpm"
xelab -nolog --relax --mt 8 $LIBS --snapshot tb xil_defaultlib.tb_tx80211 xil_defaultlib.glbl > elab.log || { tail -30 elab.log; exit 1; }
EXTRA=()
if [ -n "$VECTORS" ]; then EXTRA=(-testplusarg "vectors=$VECTORS"); fi
xsim tb -nolog -R -testplusarg "fifo=$FIFO" -testplusarg "signal=$SIGW" -testplusarg "out=$OUT" \
    -testplusarg "nframes=$NF" "${EXTRA[@]}" > "$OUT/xsim.log" 2>&1 || { tail -30 "$OUT/xsim.log"; exit 1; }
grep "\[tb\]" "$OUT/xsim.log"
