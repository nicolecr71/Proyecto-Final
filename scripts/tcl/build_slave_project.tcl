################################################################
# build_slave_project.tcl
#
# Crea y compila el proyecto Vivado para la FPGA esclava.
#
# La FPGA esclava usa el mismo hardware base que la maestra
# (MicroBlaze, DDR2, microSD, VGA, UART) pero con axi_quad_spi_0
# configurado en modo esclavo (Master_mode=0).
#
# El firmware (pong_app_slave) inicializa el AXI Quad SPI sin
# XSP_MASTER_OPTION, haciendo que la FPGA espere el SCK externo
# del maestro en lugar de generarlo.
#
# Uso desde Vivado Tcl:
#   source scripts/tcl/build_slave_project.tcl
################################################################

cd [file dirname [file normalize [info script]]]
cd ../..

set project_name "pong_slave"
set project_path "Projects/${project_name}/${project_name}.xpr"
set bd_tcl_path  "scripts/tcl/create_slave_system_bd.tcl"
set part         "xc7a100tcsg324-1"

puts "=== Creando proyecto esclavo: $project_name ==="

# --- Crear proyecto si no existe --------------------------------
if {![file exists $project_path]} {
    create_project $project_name "Projects/$project_name" -part $part
} else {
    open_project $project_path
}

# --- Registrar IP personalizado ---------------------------------
set ip_repo_path [file normalize "ip"]
set_property ip_repo_paths $ip_repo_path [current_project]
update_ip_catalog -rebuild -quiet

# --- Limpiar BD existente si aplica ----------------------------
set bd_files [get_files -quiet -filter {FILE_TYPE == "Block Designs"}]
foreach f $bd_files {
    if {[string match "*system.bd" $f]} {
        remove_files $f
    }
}
set bd_dir "Projects/${project_name}/${project_name}.srcs/sources_1/bd/system"
if {[file exists $bd_dir]} { file delete -force $bd_dir }
set gen_dir "Projects/${project_name}/${project_name}.gen/sources_1/bd/system"
if {[file exists $gen_dir]} { file delete -force $gen_dir }

# Limpiar fuentes previas
set old_v [get_files -quiet -filter {FILE_TYPE == "Verilog" || FILE_TYPE == "SystemVerilog"}]
if {[llength $old_v] > 0} { remove_files $old_v }
set old_xdc [get_files -quiet -filter {FILE_TYPE == "XDC"}]
if {[llength $old_xdc] > 0} { remove_files $old_xdc }

# --- Recrear Block Design (modo esclavo) -----------------------
puts "=== Creando Block Design para FPGA esclava ==="
source $bd_tcl_path

# --- Generar wrapper Verilog del BD ----------------------------
puts "=== Generando wrapper del BD ==="
set bd_file [get_files system.bd]
make_wrapper -files [get_files $bd_file] -top -force

set wrapper [glob -nocomplain \
    "Projects/${project_name}/${project_name}.gen/sources_1/bd/system/hdl/system_wrapper.v*"]
if {$wrapper eq ""} {
    set wrapper [glob -nocomplain \
        "Projects/${project_name}/${project_name}.srcs/sources_1/bd/system/hdl/system_wrapper.v*"]
}
if {$wrapper ne ""} {
    add_files -norecurse [lindex $wrapper 0]
}

# --- Agregar fuentes RTL ---------------------------------------
# El esclavo usa el mismo wrapper RTL que el maestro (mismos puertos SPI inout)
add_files -norecurse "rtl/io/sync_2ff.v"
add_files -norecurse "rtl/io/debounce.v"
add_files -norecurse "rtl/io/input_conditioner.v"
add_files -norecurse "rtl/top/system_io_wrapper.v"

# --- Agregar constraints (mismos pines físicos que el maestro) -
# Los pines JA del SPI son los mismos; la dirección (maestro/esclavo)
# la maneja el IP internamente según el registro de control.
add_files -fileset constrs_1 -norecurse "constraints/constraints.xdc"

set_property top system_io_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "=== Top: [get_property top [get_filesets sources_1]] ==="

# --- Síntesis --------------------------------------------------
puts "=== Iniciando síntesis ==="
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
puts "=== Síntesis: $synth_status ==="

if {[string match "*error*" [string tolower $synth_status]]} {
    puts "ERROR: la síntesis falló."
    close_project
    exit 1
}

# --- Implementación + bitstream --------------------------------
puts "=== Implementación y bitstream ==="
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
puts "=== Implementación: $impl_status ==="

# --- Copiar artefactos -----------------------------------------
file mkdir "artifacts"
set bit_src [glob -nocomplain \
    "Projects/${project_name}/${project_name}.runs/impl_1/*.bit"]
if {$bit_src ne ""} {
    file copy -force $bit_src "artifacts/pong_slave.bit"
    puts "=== Bitstream copiado a artifacts/pong_slave.bit ==="
}

close_project
puts "=== Proyecto esclavo compilado exitosamente ==="
exit
