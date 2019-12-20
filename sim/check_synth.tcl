# Standalone core synthesis; board-level timing requires the system constraints.
set here [file normalize [file dirname [info script]]]
set root [file dirname $here]
create_project -in_memory -part xc7z020clg484-1
foreach x [glob $here/ip_gen/*/*.xci] { read_ip $x }
generate_target synthesis [get_ips]
read_verilog [glob $root/rtl/*.v]
synth_design -mode out_of_context -top transmitter -part xc7z020clg484-1
create_clock -name input_clk -period 10.000 [get_ports clk]
create_clock -name fifo_wr_clk -period 8.000 [get_ports fifo_wr_clk]
file mkdir $root/results/synthesis
report_utilization -file $root/results/synthesis/utilization.txt
report_timing_summary -file $root/results/synthesis/timing.txt
report_drc -file $root/results/synthesis/drc.txt
write_checkpoint -force $root/results/synthesis/transmitter.dcp
