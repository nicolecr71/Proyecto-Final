# Rebuild esclavo con fix BRAM en video_vram_axi_core y Master_mode=1 en axi_quad_spi_0.
# Ejecutar desde la raiz del proyecto:
#   vivado -mode batch -source scripts/tcl/rebuild_slave_bram_fix.tcl

set project_path  [file normalize "Projects/pong_slave/pong_slave.xpr"]
set bitstream_src "Projects/pong_slave/pong_slave.runs/impl_1/system_io_wrapper.bit"
set bitstream_dst "artifacts/pong_slave.bit"

open_project $project_path

# Borrar cache completo de IPs para forzar re-sintesis desde fuentes.
# El cache-ID se calcula desde el XCI (parametros), no desde los .v, por eso
# cambios en vram_dual_port.v no invalidan el cache automaticamente.
set ip_cache_dir "Projects/pong_slave/pong_slave.cache/ip"
if {[file exists $ip_cache_dir]} {
    file delete -force $ip_cache_dir
    puts "Cache IP completo borrado: $ip_cache_dir"
}

# Forzar re-sintesis del IP de video
set video_ip_run "system_video_vram_axi_core_0_0_synth_1"
if {[get_runs $video_ip_run] ne ""} {
    reset_run $video_ip_run
    puts "Reset run: $video_ip_run"
}
# Lanzar explicitamente el OOC run del IP de video y esperar a que complete.
# Con el cache borrado, esto re-sintetiza desde los fuentes actualizados.
set video_ip_run "system_video_vram_axi_core_0_0_synth_1"
launch_runs $video_ip_run -jobs 4
wait_on_run $video_ip_run
if {[get_property PROGRESS [get_runs $video_ip_run]] != "100%"} {
    puts "ERROR: IP synthesis failed."
    close_project
    exit 1
}
puts "IP video_vram_axi_core re-sintetizado desde fuentes."

# Generar targets del BD (wrapper y cabeceras)
generate_target all [get_bd_designs]

# Reset y launch synthesis + implementation completos
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed."
    close_project
    exit 1
}

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed. Revisar logs en pong_slave.runs/impl_1/runme.log"
    close_project
    exit 1
}

# Copiar bitstream a artifacts/
file copy -force $bitstream_src $bitstream_dst
puts "Bitstream copiado a $bitstream_dst"

# Verificar timing
open_run impl_1
set wns [get_property STATS.WNS [get_runs impl_1]]
puts "WNS final: ${wns} ns"
if {$wns < 0} {
    puts "ADVERTENCIA: Timing no cerrado (WNS=${wns}). Revisar timing summary."
} else {
    puts "OK: Timing cerrado."
}

close_project
