open_project Projects/el3313_proyecto2/el3313_proyecto2.xpr

set_property top system_io_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1

reset_run synth_1
reset_run impl_1

launch_runs synth_1 -jobs 4
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "=== TOP ACTUAL ==="
puts [get_property top [get_filesets sources_1]]

puts "=== SYNTH STATUS ==="
puts [get_property STATUS [get_runs synth_1]]

puts "=== IMPL STATUS ==="
puts [get_property STATUS [get_runs impl_1]]

close_project
exit
