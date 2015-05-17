###############################################################################
#
# @author Milos Subotic <milos.subotic.sm@gmail.com>
# @license MIT
#
# @brief Makefile for processor project.
#
###############################################################################
# User defines.

FIRMWARE=src/sw/10x4.asm
ISET_DEF=src/sw/instr_set_v1.isd

###############################################################################
# Targets.

.PHONY: default asm comp_sim sim run_vivado synthesize clean distclean dist

default: sim

###############################################################################
# Private vars.

ASM=./src/tools/assembler.jl
ISET_P=src/rtl/instruction_set_p.vhd
ROM_A=src/rtl/instruction_rom_a.vhd
GEN_ISET=./src/tools/gen_instr_set.jl

###############################################################################
# Rules.

asm: ${ROM_A}
${ROM_A}: ${ASM} ${FIRMWARE}
	${ASM} ${FIRMWARE} ${ROM_A}

${ISET_P} ${ASM}: ${GEN_ISET} ${ISET_DEF}
	${GEN_ISET} ${ISET_DEF} ${ISET_P} ${ASM}

comp_sim: ${ISET_P} ${ROM_A}
	vlib modelsim_work
	vmap work modelsim_work
	vcom -2002 +cover ${ISET_P}
	vcom -2002 +cover src/rtl/instruction_rom_e.vhd
	vcom -2002 +cover ${ROM_A}
	vcom -2002 +cover src/rtl/processor.vhd
	vcom -2002 +cover src/sim/processor_tb.vhd

sim: comp_sim
	vsim -coverage -voptargs="+acc" -t 1ns work.processor_tb \
		-do src/sim/processor_tb.do -l simulation.log -c

run_vivado:
	vivado -source ./vivado_create_project.tcl

synthesize:
	vivado -source ./vivado_synthesize.tcl -mode tcl

###############################################################################
# Housekeeping.

clean:
	rm -rf modelsim_work/ *.wlf modelsim.ini \
		vivado_work/ vivado*.jou vivado*.log vivado*.zip vivado*.str .Xil/ \
		ise_work

distclean: clean
	rm -rf utilization.txt simulation.log


dist: distclean
	cd ../ && zip -9r \
		Config_CPU-$$(date +%F-%T | sed 's/:/-/g').zip Config_CPU

###############################################################################

