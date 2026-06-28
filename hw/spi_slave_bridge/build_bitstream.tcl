# Síntesis + implementación + bitstream del slave tras aplicar el puente SPI.
set repo_root [file normalize [file join [file dirname [info script]] .. ..]]
open_project [file join $repo_root Projects el3313_proyecto2 el3313_proyecto2.xpr]

# Asegurar top = system_io_wrapper (acondiciona switches->INPUT_DRIVER e
# instancia system_wrapper; NO usar system_wrapper directo o INPUT_DRIVER[7:0]
# queda como puerto sin pin y falla el DRC).
set_property top system_io_wrapper [current_fileset]
update_compile_order -fileset sources_1

# Resetear runs (el BD cambió) y correr hasta bitstream.
reset_run synth_1
launch_runs synth_1 -jobs 6
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: synth_1 no llegó a 100%"
    puts [get_property STATUS [get_runs synth_1]]
    exit 2
}

launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: impl_1 no llegó a 100%"
    puts [get_property STATUS [get_runs impl_1]]
    exit 3
}

# Localizar y copiar el bitstream.
set bit [glob -nocomplain [file join $repo_root Projects el3313_proyecto2 el3313_proyecto2.runs impl_1 *.bit]]
puts "BITSTREAM: $bit"
file copy -force [lindex $bit 0] [file join $repo_root artifacts pong_slave.bit]

# Exportar XSA con bitstream para regenerar el BSP.
write_hw_platform -fixed -include_bit -force \
    [file join $repo_root artifacts el3313_proyecto2.xsa]

puts "================ BUILD OK ================"
puts "WNS: [get_property STATS.WNS [get_runs impl_1]]"
report_utilization -quiet
exit 0
