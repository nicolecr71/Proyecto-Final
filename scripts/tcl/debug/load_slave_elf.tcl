################################################################
# load_slave_elf.tcl
# Programa el bitstream esclavo y carga el ELF del firmware esclavo.
# Ajustar SERIAL_NUMBER con el número de la FPGA esclava.
################################################################

set BIT_FILE   "artifacts/pong_slave.bit"
set ELF_FILE   "workspace_new/pong_app_slave/Debug/pong_app_slave.elf"

# Cambiar por el serial de la FPGA esclava
set SERIAL_NUMBER "210319B3AEB3"

connect -url tcp:localhost:3121

open_hw_manager
connect_hw_server -url localhost:3121

open_hw_target [lindex [get_hw_targets *$SERIAL_NUMBER*] 0]
set device [lindex [get_hw_devices] 0]
current_hw_device $device

set_property PROGRAM.FILE $BIT_FILE $device
program_hw_devices $device
puts "=== Bitstream esclavo cargado ==="

after 1000

dow $ELF_FILE
puts "=== ELF esclavo cargado, iniciando ==="
con

close_hw_manager
