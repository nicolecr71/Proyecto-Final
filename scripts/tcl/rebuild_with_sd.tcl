################################################################
# rebuild_with_sd.tcl
# Regenera el Block Design con axi_quad_spi_1 para microSD,
# actualiza el wrapper y lanza sintesis + implementacion + bitstream.
################################################################

cd [file dirname [file normalize [info script]]]
cd ../..

set project_path "Projects/el3313_proyecto2/el3313_proyecto2.xpr"
set bd_tcl_path  "scripts/tcl/create_system_bd.tcl"

puts "=== Abriendo proyecto ==="
open_project $project_path

# --- Registrar repositorio de IP personalizado --------------------
set ip_repo_path [file normalize "ip"]
set_property ip_repo_paths $ip_repo_path [current_project]
update_ip_catalog -rebuild -quiet

# --- Eliminar el BD existente para recrearlo ----------------------
puts "=== Eliminando BD existente ==="
set bd_files [get_files -filter {FILE_TYPE == "Block Designs"}]
foreach f $bd_files {
    if {[string match "*system.bd" $f]} {
        remove_files $f
    }
}

# Borrar archivos generados del BD anterior
set bd_dir "Projects/el3313_proyecto2/el3313_proyecto2.srcs/sources_1/bd/system"
if {[file exists $bd_dir]} {
    file delete -force $bd_dir
}
set gen_dir "Projects/el3313_proyecto2/el3313_proyecto2.gen/sources_1/bd/system"
if {[file exists $gen_dir]} {
    file delete -force $gen_dir
}

# --- Recrear el BD con el nuevo SPI para SD ----------------------
puts "=== Recreando Block Design ==="
source $bd_tcl_path

# --- Generar wrapper Verilog del BD ------------------------------
puts "=== Generando wrapper ==="
set bd_file [get_files system.bd]
make_wrapper -files [get_files $bd_file] -top -force
set wrapper [glob -nocomplain \
    "Projects/el3313_proyecto2/el3313_proyecto2.gen/sources_1/bd/system/hdl/system_wrapper.v"]
if {$wrapper ne ""} {
    add_files -norecurse $wrapper
} else {
    set wrapper [glob -nocomplain \
        "Projects/el3313_proyecto2/el3313_proyecto2.srcs/sources_1/bd/system/hdl/system_wrapper.v"]
    if {$wrapper ne ""} {
        add_files -norecurse $wrapper
    }
}

# --- Agregar fuentes RTL del top ---------------------------------
add_files -norecurse "src/rtl/io/sync_2ff.v"
add_files -norecurse "src/rtl/io/debounce.v"
add_files -norecurse "src/rtl/io/input_conditioner.v"
add_files -norecurse "src/rtl/top/system_io_wrapper.v"

set_property top system_io_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "=== Top actual: [get_property top [get_filesets sources_1]] ==="

# --- Lanzar sintesis ----------------------------------------------
puts "=== Iniciando sintesis ==="
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
puts "=== Sintesis: $synth_status ==="

if {[string match "*error*" [string tolower $synth_status]]} {
    puts "ERROR: la sintesis fallo."
    close_project
    exit 1
}

# --- Lanzar implementacion + bitstream ----------------------------
puts "=== Iniciando implementacion y bitstream ==="
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
puts "=== Implementacion: $impl_status ==="

# --- Copiar artefactos --------------------------------------------
set bit_src [glob -nocomplain \
    "Projects/el3313_proyecto2/el3313_proyecto2.runs/impl_1/*.bit"]
if {$bit_src ne ""} {
    file copy -force $bit_src "artifacts/system_io_wrapper.bit"
    puts "=== Bitstream copiado a artifacts/system_io_wrapper.bit ==="
}

close_project
puts "=== Listo ==="
exit
