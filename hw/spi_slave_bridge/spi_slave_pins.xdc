# Pmod JA — enlace SPI, esta FPGA es ESCLAVO del bus.
# JA1=CS, JA2=MOSI, JA3=MISO, JA4=SCLK.
#
# Reemplaza las líneas viejas de spi_rtl_0_* en constraints/constraints.xdc
# (las del axi_quad_spi_0 que se eliminó).
#
# cs/sck/mosi son ENTRADAS (las genera el master); miso es SALIDA.

set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33 } [get_ports { spi_cs_n }]; #Sch=ja[1] SPI_SS_N
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { spi_mosi }]; #Sch=ja[2] SPI_MOSI
set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS33 } [get_ports { spi_miso }]; #Sch=ja[3] SPI_MISO
set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { spi_sck  }]; #Sch=ja[4] SPI_SCLK
