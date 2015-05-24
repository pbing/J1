# Description
[J1: a small Forth CPU Core for FPGAs](http://excamera.com/sphinx/fpga-j1.html)

Rewritten in SystemVerilog from [Verilog Source](https://github.com/ros-drivers/wge100_driver/tree/hydro-devel/wge100_camera_firmware/src/hardware/verilog/j1.v).

## Usage of SystemVerilog *union*
ModelSim Altera Starter Edition 10.1d compiles and simulates with unions. [Quartus II](http://dl.altera.com/13.0sp1/?edition=web) for [Cyclone II FPGA](http://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&CategoryNo=53&No=83) cannot use them. Use [this](rtl/j1_quartus_ii.sv) as a workaround.
