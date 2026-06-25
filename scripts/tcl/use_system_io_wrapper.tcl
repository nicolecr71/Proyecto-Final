open_project Projects/el3313_proyecto2/el3313_proyecto2.xpr

add_files -norecurse src/rtl/io/sync_2ff.v
add_files -norecurse src/rtl/io/debounce.v
add_files -norecurse src/rtl/io/input_conditioner.v
add_files -norecurse src/rtl/top/system_io_wrapper.v

set_property top system_io_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "=== TOP ACTUAL ==="
puts [get_property top [get_filesets sources_1]]

close_project
exit
