# Reconstruye el slave tomando la fuente nueva del video core (ya re-empaquetada).
# Resuelve el lock del IP con upgrade_ip y fuerza la regeneración para que ipshared
# tome el vram_dual_port.v con block RAM (2 ciclos consistentes).
set repo_root [file normalize [file join [file dirname [info script]] .. ..]]
open_project [file join $repo_root Projects el3313_proyecto2 el3313_proyecto2.xpr]

update_ip_catalog -rebuild

set ip [get_ips -quiet system_video_vram_axi_core_0_0]
puts ">>> upgrade_ip sobre: $ip"
catch { upgrade_ip $ip } e
puts ">>> upgrade_ip resultado: $e"

set xci [get_files -quiet system_video_vram_axi_core_0_0.xci]
reset_target -quiet all $xci
generate_target -quiet all $xci
puts ">>> IP regenerado."

# Verificar que ipshared ahora tiene block RAM
set shared_vdp [glob -nocomplain [file join $repo_root Projects el3313_proyecto2 el3313_proyecto2.gen sources_1 bd system ipshared * src vram_dual_port.v]]
if {[llength $shared_vdp] > 0} {
    set fh [open [lindex $shared_vdp 0] r]; set txt [read $fh]; close $fh
    if {[string match {*ram_style = "block"*} $txt]} {
        puts ">>> OK: ipshared vram_dual_port.v AHORA tiene block RAM."
    } else {
        puts ">>> ADVERTENCIA: ipshared vram_dual_port.v TODAVIA es la version vieja!"
    }
}

set_property top system_io_wrapper [current_fileset]
update_compile_order -fileset sources_1

reset_run synth_1
launch_runs synth_1 -jobs 6
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR synth_1: [get_property STATUS [get_runs synth_1]]"; exit 2
}

set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR impl_1: [get_property STATUS [get_runs impl_1]]"; exit 3
}

puts "================ BUILD RESULT ================"
puts "WNS = [get_property STATS.WNS [get_runs impl_1]]"
set bit [glob -nocomplain [file join $repo_root Projects el3313_proyecto2 el3313_proyecto2.runs impl_1 *.bit]]
if {[llength $bit] > 0} {
    file copy -force [lindex $bit 0] [file join $repo_root artifacts pong_slave.bit]
    puts "Bitstream copiado a artifacts/pong_slave.bit"
}
exit 0
