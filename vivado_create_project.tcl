#
###############################################################################
# @file vivado_create_project.tcl
# @date Oct 17, 2014
#
# @author Milos Subotic <milos.subotic.sm@gmail.com>
# @license MIT
#
# @brief Create project for Xilinx Vivado.
#
# @version: 1.0
# Changelog:
# 1.0 - Initial version.
#
###############################################################################

proc add_rtl_file {file} {
	add_files -norecurse -scan_for_includes -fileset sources_1 $file
}

proc set_rtl_top {top} {
	set_property top $top [get_filesets sources_1]
}

proc add_sim_file {file} {
	add_files -norecurse -scan_for_includes -fileset sim_1 $file
}

proc set_sim_top {top} {
	set_property top $top [get_filesets sim_1]
}


###############################################################################

create_project processor vivado_work -force

add_rtl_file src/rtl/instruction_set.vhd
add_rtl_file src/rtl/instruction_rom.vhd
add_rtl_file src/rtl/processor.vhd
set_rtl_top processor

add_sim_file src/sim/processor_tb.vhd
set_sim_top processor_tb

# Set to ZedBoard
set_property board_part em.avnet.com:zed:part0:1.0 [current_project]

###############################################################################

