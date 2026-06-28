# Re-empaqueta el IP video_vram_axi_core con la fuente actualizada (block RAM,
# 2 ciclos de latencia consistentes) y reconstruye el bitstream del slave.
# Arregla: franja superior corrupta / bola invisible (desajuste 1-vs-2 ciclos)
# y la violación de timing (RAM distribuida -> block RAM).
set repo_root [file normalize [file join [file dirname [info script]] .. ..]]

# --- 1. Re-empaquetar el IP (refresca component.xml con el src nuevo) ---
set comp [file join $repo_root ip video_vram_axi_core component.xml]
ipx::open_core $comp
ipx::merge_project_changes files [ipx::current_core]
set_property core_revision [expr {[get_property core_revision [ipx::current_core]] + 1}] [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::unload_core
puts ">>> IP video_vram_axi_core re-empaquetado."

# --- 2. Abrir proyecto y forzar regeneración del IP ---
open_project [file join $repo_root Projects el3313_proyecto2 el3313_proyecto2.xpr]
update_ip_catalog -rebuild

set xci [get_files -quiet system_video_vram_axi_core_0_0.xci]
puts ">>> Reseteando productos generados del IP: $xci"
reset_target -quiet all $xci
generate_target -quiet all $xci
export_ip_user_files -of_objects $xci -no_script -force -quiet

# --- 3. Reconstruir desde síntesis ---
set_property top system_io_wrapper [current_fileset]
update_compile_order -fileset sources_1

reset_run synth_1
launch_runs synth_1 -jobs 6
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR synth_1: [get_property STATUS [get_runs synth_1]]"; exit 2
}

# phys_opt post-route como respaldo de timing (block RAM debería cerrar solo)
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR impl_1: [get_property STATUS [get_runs impl_1]]"; exit 3
}

set wns [get_property STATS.WNS [get_runs impl_1]]
puts "================ BUILD RESULT ================"
puts "WNS = $wns"

set bit [glob -nocomplain [file join $repo_root Projects el3313_proyecto2 el3313_proyecto2.runs impl_1 *.bit]]
if {[llength $bit] > 0} {
    file copy -force [lindex $bit 0] [file join $repo_root artifacts pong_slave.bit]
    puts "Bitstream copiado a artifacts/pong_slave.bit"
}
exit 0
