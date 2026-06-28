# Re-empaqueta video_vram_axi_core (gate d0 (combinacional)) y reconstruye el slave.
set repo_root [file normalize [file join [file dirname [info script]] .. ..]]

# 1. Re-empaquetar (bump revision para invalidar cache).
set comp [file join $repo_root ip video_vram_axi_core component.xml]
ipx::open_core $comp
ipx::merge_project_changes files [ipx::current_core]
set_property core_revision [expr {[get_property core_revision [ipx::current_core]] + 1}] [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::unload_core
puts ">>> IP re-empaquetado (gate d0 (combinacional))."

# 2. Abrir proyecto, resolver lock con upgrade_ip, regenerar.
open_project [file join $repo_root Projects el3313_proyecto2 el3313_proyecto2.xpr]
update_ip_catalog -rebuild
catch { upgrade_ip [get_ips system_video_vram_axi_core_0_0] } e
puts ">>> upgrade_ip: $e"
set xci [get_files -quiet system_video_vram_axi_core_0_0.xci]
reset_target -quiet all $xci
generate_target -quiet all $xci

# Verificar que ipshared tomo el gate d0 (combinacional)
set shared [glob -nocomplain [file join $repo_root Projects el3313_proyecto2 el3313_proyecto2.gen sources_1 bd system ipshared * src video_vram_axi_core.v]]
if {[llength $shared] > 0} {
    set fh [open [lindex $shared 0] r]; set txt [read $fh]; close $fh
    if {[string match {*vram_read_active ? vram_read_data*} $txt]} {
        puts ">>> OK: ipshared usa gate d0 (combinacional)."
    } else {
        puts ">>> ADVERTENCIA: ipshared NO tiene gate d0 (combinacional)!"
    }
}

# 3. Reconstruir.
set_property top system_io_wrapper [current_fileset]
update_compile_order -fileset sources_1
reset_run synth_1
launch_runs synth_1 -jobs 6
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} { puts "ERROR synth_1"; exit 2 }
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} { puts "ERROR impl_1"; exit 3 }

puts "================ BUILD RESULT ================"
puts "WNS = [get_property STATS.WNS [get_runs impl_1]]"
set bit [glob -nocomplain [file join $repo_root Projects el3313_proyecto2 el3313_proyecto2.runs impl_1 *.bit]]
if {[llength $bit] > 0} {
    file copy -force [lindex $bit 0] [file join $repo_root artifacts pong_slave.bit]
    puts "Bitstream copiado a artifacts/pong_slave.bit"
}
exit 0
