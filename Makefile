###############################################################################
# @file Makefile
# @date Oct 18, 2014
#
# @author Milos Subotic <milos.subotic.sm@gmail.com>
# @license MIT
#
# @brief Makefile for processor project.
#
# @version: 1.0
# Changelog:
# 1.0 - Initial version.
#
###############################################################################

comp_sim:
	vlib modelsim_work
	vmap work ${PWD}/modelsim_work
	vcom -2002 +cover src/rtl/instruction_set.vhd
	vcom -2002 +cover src/rtl/instruction_rom.vhd
	vcom -2002 +cover src/rtl/processor.vhd
	vcom -2002 +cover src/sim/processor_tb.vhd

sim: comp_sim
	vsim -coverage -voptargs="+acc" -t 1ns work.processor_tb \
		-do src/sim/processor_tb.do -l simulation.log #-c

run_vivado:
	vivado -source ./vivado_create_project.tcl

synthesize:
	vivado -source ./vivado_synthesize.tcl -mode tcl

asm:
	./src/tools/assembler.jl src/sw/10x4.asm src/rtl/instruction_rom.vhd


clean:
	rm -rf modelsim_work/ *.wlf modelsim.ini \
		vivado_work/ vivado*.jou vivado*.log vivado*.zip vivado*.str .Xil/

distclean: clean
	rm -rf utilization.txt simulation.log

