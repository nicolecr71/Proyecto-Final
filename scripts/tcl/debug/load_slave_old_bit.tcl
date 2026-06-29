# Carga el bitstream VIEJO (15:20, sin timing violations) + ELF actual del esclavo.
# Util para verificar que la pantalla funciona mientras el rebuild corre.
# Ejecutar: xsct scripts/tcl/debug/load_slave_old_bit.tcl

set bit_old "artifacts/system_io_wrapper.bit"
set elf     "artifacts/pong_app_slave.elf"
set serial  "*210292BB3145*"

connect

# Programar FPGA esclava con el bitstream viejo
targets -set -filter {name =~ "xc7a100t" && jtag_cable_serial =~ $serial}
fpga -file $bit_old
puts "Bitstream viejo cargado: $bit_old"

after 4000

# Cargar ELF actual
targets -set -filter {name =~ "Hart #0" && jtag_cable_serial =~ $serial}
stop
rst -processor
dow $elf
con
puts "ELF cargado: $elf"
puts "Slave corriendo con bitstream viejo (pantalla deberia funcionar, MISO aun roto)."
