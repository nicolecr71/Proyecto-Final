connect

targets -set -filter {name =~ "xc7a100t" && jtag_cable_serial =~ "*210292BB3406*"}
fpga -file Projects/el3313_proyecto2/el3313_proyecto2.runs/impl_1/system_io_wrapper.bit
puts "Bitstream master cargado."

after 4000

targets -set -filter {name =~ "Hart #0" && jtag_cable_serial =~ "*210292BB3406*"}
stop
rst -processor
dow artifacts/pong_app.elf
con
puts "ELF master cargado. Master corriendo."
