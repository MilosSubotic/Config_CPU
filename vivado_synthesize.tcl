#
###############################################################################
#
# @author Milos Subotic <milos.subotic.sm@gmail.com>
# @license MIT
#
# @brief Synthesize project with Xilinx Vivado.
#
###############################################################################

source ./vivado_create_project.tcl

launch_runs synth_1
wait_on_run synth_1

open_run synth_1 -name netlist_1
report_utilization -file utilization.txt

exit

###############################################################################

