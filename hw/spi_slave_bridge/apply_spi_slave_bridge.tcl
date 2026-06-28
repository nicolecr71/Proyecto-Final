################################################################################
# apply_spi_slave_bridge.tcl
#
# Reemplaza el axi_quad_spi_0 (mal configurado como master) por el esclavo SPI
# de hardware comprobado (spi_game_slave_reference) expuesto al MicroBlaze por
# 3 AXI GPIO. Ejecutar dentro del proyecto del SLAVE en Vivado:
#
#   cd <repo>/Projects/el3313_proyecto2
#   vivado -mode batch -source ../../hw/spi_slave_bridge/apply_spi_slave_bridge.tcl
#
# o desde la consola TCL de Vivado con el proyecto ya abierto:
#   source <repo>/hw/spi_slave_bridge/apply_spi_slave_bridge.tcl
#
# Tras correrlo: revisar validate_bd_design, regenerar wrapper, sintetizar e
# implementar (write_bitstream). Luego regenerar el BSP (xparameters.h tendrá
# XPAR_AXI_GPIO_SPI_{A,B,C}_BASEADDR) y recompilar el ELF del slave.
#
# Si algo falla, usar el README.md (pasos equivalentes en GUI).
################################################################################

set repo_root [file normalize [file join [file dirname [info script]] .. ..]]
set rtl_dir   [file join $repo_root hw spi_slave_bridge]

# Abrir proyecto si no está abierto.
if {[catch {current_project}]} {
    open_project [file join $repo_root Projects el3313_proyecto2 el3313_proyecto2.xpr]
}

# 1. Agregar el RTL del puente.
add_files -norecurse [list \
    [file join $rtl_dir spi_game_slave_reference.v] \
    [file join $rtl_dir spi_game_slave_bridge.v] ]
update_compile_order -fileset sources_1

# 2. Abrir el block design.
open_bd_design [get_files system.bd]
current_bd_design [get_bd_designs system]

set ic microblaze_riscv_0_axi_periph

# 3. Borrar el AXI Quad SPI del enlace y su puerto externo (libera los pines JA).
catch { delete_bd_objs [get_bd_intf_nets axi_quad_spi_0_SPI_0] }
catch { delete_bd_objs [get_bd_intf_ports spi_rtl_0] }
catch { delete_bd_objs [get_bd_cells axi_quad_spi_0] }

# 4. Crear las 3 instancias AXI GPIO.
#    a: ch1<-word0  ch2<-word1   (ambos entrada)
#    b: ch1<-word2  ch2<-word3   (ambos entrada)
#    c: ch1<-word4  ch2->p2      (ch1 entrada, ch2 salida)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_spi_a
set_property -dict [list \
    CONFIG.C_IS_DUAL {1} \
    CONFIG.C_GPIO_WIDTH {32}  CONFIG.C_ALL_INPUTS {1} \
    CONFIG.C_GPIO2_WIDTH {32} CONFIG.C_ALL_INPUTS_2 {1} ] [get_bd_cells axi_gpio_spi_a]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_spi_b
set_property -dict [list \
    CONFIG.C_IS_DUAL {1} \
    CONFIG.C_GPIO_WIDTH {32}  CONFIG.C_ALL_INPUTS {1} \
    CONFIG.C_GPIO2_WIDTH {32} CONFIG.C_ALL_INPUTS_2 {1} ] [get_bd_cells axi_gpio_spi_b]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_spi_c
set_property -dict [list \
    CONFIG.C_IS_DUAL {1} \
    CONFIG.C_GPIO_WIDTH {32}  CONFIG.C_ALL_INPUTS {1} \
    CONFIG.C_GPIO2_WIDTH {32} CONFIG.C_ALL_OUTPUTS_2 {1} ] [get_bd_cells axi_gpio_spi_c]

# 5. Crear el módulo del puente (module reference al RTL agregado).
create_bd_cell -type module -reference spi_game_slave_bridge spi_game_slave_bridge_0

# 6. Conectar reloj y reset del puente (dominio 100 MHz de periféricos).
connect_bd_net [get_bd_pins clk_wiz_1/clk_out1] \
               [get_bd_pins spi_game_slave_bridge_0/clk]
connect_bd_net [get_bd_pins rst_clk_wiz_1_100M/peripheral_aresetn] \
               [get_bd_pins spi_game_slave_bridge_0/rst_n]

# 7. Conectar AXI (S_AXI de cada GPIO) al MicroBlaze vía automation.
#    Esto expande el interconnect, conecta ACLK/ARESETN y asigna dirección.
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config [list Master {/microblaze_riscv_0 (Periph)} Clk {Auto}] \
    [get_bd_intf_pins axi_gpio_spi_a/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config [list Master {/microblaze_riscv_0 (Periph)} Clk {Auto}] \
    [get_bd_intf_pins axi_gpio_spi_b/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config [list Master {/microblaze_riscv_0 (Periph)} Clk {Auto}] \
    [get_bd_intf_pins axi_gpio_spi_c/S_AXI]

# 8. Conectar los buses de datos GPIO <-> puente.
#    Entradas hacia el CPU: state_wordN -> gpio_io_i
connect_bd_net [get_bd_pins spi_game_slave_bridge_0/state_word0] [get_bd_pins axi_gpio_spi_a/gpio_io_i]
connect_bd_net [get_bd_pins spi_game_slave_bridge_0/state_word1] [get_bd_pins axi_gpio_spi_a/gpio2_io_i]
connect_bd_net [get_bd_pins spi_game_slave_bridge_0/state_word2] [get_bd_pins axi_gpio_spi_b/gpio_io_i]
connect_bd_net [get_bd_pins spi_game_slave_bridge_0/state_word3] [get_bd_pins axi_gpio_spi_b/gpio2_io_i]
connect_bd_net [get_bd_pins spi_game_slave_bridge_0/state_word4] [get_bd_pins axi_gpio_spi_c/gpio_io_i]
#    Salida desde el CPU: gpio2_io_o -> p2_in_word
connect_bd_net [get_bd_pins axi_gpio_spi_c/gpio2_io_o] [get_bd_pins spi_game_slave_bridge_0/p2_in_word]

# 9. Pines SPI externos (Pmod JA). Esta FPGA es ESCLAVO: cs/sck/mosi son
#    entradas, miso es salida. El XDC los mapea a C17/D18/E18/G17.
create_bd_port -dir I spi_cs_n
create_bd_port -dir I spi_sck
create_bd_port -dir I spi_mosi
create_bd_port -dir O spi_miso
connect_bd_net [get_bd_ports spi_cs_n] [get_bd_pins spi_game_slave_bridge_0/spi_cs_n]
connect_bd_net [get_bd_ports spi_sck]  [get_bd_pins spi_game_slave_bridge_0/spi_sck]
connect_bd_net [get_bd_ports spi_mosi] [get_bd_pins spi_game_slave_bridge_0/spi_mosi]
connect_bd_net [get_bd_ports spi_miso] [get_bd_pins spi_game_slave_bridge_0/spi_miso]

# 10. Asegurar direcciones asignadas y validar.
assign_bd_address
regenerate_bd_layout
validate_bd_design

save_bd_design

# 11. Regenerar el HDL wrapper del BD.
set bd_file [get_files system.bd]
catch { make_wrapper -files [get_files $bd_file] -top -force }

puts "================================================================"
puts " Puente SPI esclavo aplicado."
puts " Direcciones asignadas (anotar para verificar XPAR_*):"
report_bd_address -quiet
puts ""
puts " SIGUIENTE:"
puts "  1. Actualizar el XDC: mapear spi_cs_n=C17, spi_mosi=D18,"
puts "     spi_miso=E18, spi_sck=G17 (ver hw/spi_slave_bridge/spi_slave_pins.xdc)."
puts "     Quitar las líneas viejas de spi_rtl_0_*."
puts "  2. launch_runs synth_1 ; launch_runs impl_1 -to_step write_bitstream"
puts "  3. Exportar XSA y regenerar el BSP (xparameters.h)."
puts "  4. Recompilar el ELF del slave."
puts "================================================================"
