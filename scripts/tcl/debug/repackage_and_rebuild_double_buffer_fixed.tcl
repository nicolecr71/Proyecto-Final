set repo_dir [pwd]
set ip_dir [file normalize "$repo_dir/ip/video_vram_axi_core"]
set proj_file [file normalize "$repo_dir/Projects/el3313_proyecto2/el3313_proyecto2.xpr"]

puts "=== REPACKAGE VIDEO IP ==="
ipx::open_ipxact_file "$ip_dir/component.xml"
set core [ipx::current_core]

set old_rev [get_property core_revision $core]
if {$old_rev eq ""} {
    set old_rev 0
}
set new_rev [expr {$old_rev + 1}]

puts "Core revision: $old_rev -> $new_rev"

set_property core_revision $new_rev $core
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
ipx::unload_core $core

puts "=== OPEN PROJECT ==="
open_project $proj_file

set_property ip_repo_paths [list [file normalize "$repo_dir/ip"]] [current_project]
update_ip_catalog -rebuild

puts "=== OPEN BD ==="
set bd_file [get_files -quiet */system.bd]
if {[llength $bd_file] == 0} {
    set bd_file [get_files -quiet "$repo_dir/Projects/el3313_proyecto2/el3313_proyecto2.srcs/sources_1/bd/system/system.bd"]
}

puts "BD FILE: $bd_file"
open_bd_design $bd_file

puts "=== REPORT IP STATUS ==="
report_ip_status

puts "=== UPGRADE IPs ==="
set all_ips [get_ips -quiet]
puts "IPS: $all_ips"

foreach ip $all_ips {
    if {[string match "*video_vram_axi_core*" $ip]} {
        puts "Upgrade video IP: $ip"
        catch {upgrade_ip $ip} result
        puts $result
    }
}

validate_bd_design
save_bd_design

puts "=== REGENERATE BD PRODUCTS ==="
reset_target all $bd_file
generate_target all $bd_file
export_ip_user_files -of_objects $bd_file -no_script -sync -force -quiet

puts "=== RESET RUNS ==="
set video_runs [get_runs -quiet *video_vram_axi_core*]
puts "VIDEO RUNS: $video_runs"

foreach r $video_runs {
    puts "Reset run: $r"
    catch {reset_run $r}
}

reset_run synth_1
reset_run impl_1

puts "=== BUILD BITSTREAM ==="
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "SYNTH STATUS: [get_property STATUS [get_runs synth_1]]"
puts "IMPL STATUS: [get_property STATUS [get_runs impl_1]]"

close_project
exit
