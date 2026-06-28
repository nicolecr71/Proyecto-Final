connect

targets -set -filter {name =~ "xc7a100t" && jtag_cable_serial =~ "*210292BB3145*"}
fpga -file artifacts/pong_slave.bit
puts "Bitstream NUEVO esclavo cargado (BRAM fix, WNS=+0.87ns)."

after 4000

targets -set -filter {name =~ "Hart #0" && jtag_cable_serial =~ "*210292BB3145*"}
stop
rst -processor
dow artifacts/pong_app_slave.elf
con
puts "ELF cargado. Slave corriendo."
