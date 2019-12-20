# Out-of-context implementation of the synthesized core, without board pinout.
set here [file normalize [file dirname [info script]]]
set out [file dirname $here]/results/synthesis
cd $out
open_checkpoint $out/transmitter.dcp
opt_design
place_design
phys_opt_design
route_design
report_timing_summary -file $out/routed_timing.txt
report_route_status -file $out/route_status.txt
write_checkpoint -force $out/transmitter_routed.dcp
