# Upgrade the IP .xci files in sim/ip to Vivado 2024.2 and generate xsim simulation models.
# Usage: vivado -mode batch -source gen_ip.tcl   (run from sim/)
set here [file normalize [file dirname [info script]]]
set out  $here/ip_gen
file delete -force $out
file mkdir $out
create_project -in_memory -part xc7z020clg484-1
foreach x [glob $here/ip/*.xci] {
    set n [file rootname [file tail $x]]
    file mkdir $out/$n
    file copy $x $out/$n/
    read_ip $out/$n/$n.xci
}
set ips [get_ips]
upgrade_ip $ips
# Rename outputs while enabled; Clock Wizard ignores disabled parameters.
set_property -dict [list CONFIG.CLK_OUT3_PORT {clk_out3} \
    CONFIG.CLK_OUT4_PORT {clk_out4} CONFIG.CLK_OUT5_PORT {clk_out5}] [get_ips clk_main]
# The core uses only 20 MHz (SIGNAL/output) and 120 MHz (DATA).
set_property -dict [list \
    CONFIG.CLK_OUT1_PORT {clk_20m} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {20.000} \
    CONFIG.CLK_OUT2_PORT {clk_120m} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {120.000} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT3_USED {false} \
    CONFIG.CLKOUT4_USED {false} \
    CONFIG.CLKOUT5_USED {false} \
    CONFIG.CLKOUT6_USED {false} \
    CONFIG.CLKOUT7_USED {false} \
    CONFIG.NUM_OUT_CLKS {2}] [get_ips clk_main]
# Invalidate compiled IP models after changing the generated products.
foreach marker [glob -nocomplain $here/build/*/ip.done] {
    file delete $marker
}
foreach ip $ips {
    set_property GENERATE_SYNTH_CHECKPOINT false [get_files [get_property IP_FILE $ip]]
    generate_target {simulation} [get_files [get_property IP_FILE $ip]]
}
export_simulation -of_objects $ips -simulator xsim -directory $out/export -force
foreach ip $ips {
    puts "IP $ip : [get_property IPDEF $ip]"
}
