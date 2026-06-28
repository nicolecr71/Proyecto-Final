open_hw_manager
connect_hw_server

set target_name "localhost:3121/xilinx_tcf/Digilent/210292BB3406A"

current_hw_target [get_hw_targets $target_name]
open_hw_target

set dev [lindex [get_hw_devices] 0]

set_property PROGRAM.FILE {/home/leandro/el3313_proyecto2/Projects/el3313_proyecto2/el3313_proyecto2.runs/impl_1/system_io_wrapper.bit} $dev
program_hw_devices $dev
refresh_hw_device $dev

puts "=== FPGA MAESTRO 3406 PROGRAMADA CON FRAME_COUNTER ==="

close_hw_manager
exit
