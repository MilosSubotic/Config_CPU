
-------------------------------------------------------------------------------
-- This file is generated by assembler.jl
-- Command line arguments were: src/sw/10x4.asm src/rtl/instruction_rom.vhd
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.instruction_set.all;

entity instruction_rom is
	port (
		i_addr        : in  t_instr_addr;
		o_instruction : out t_instruction
	);
end entity instruction_rom;

architecture instruction_rom_arch of instruction_rom is

	type t_instructions is array (0 to instructions_number-1) of t_instruction;
	
	constant rom : t_instructions := (
		ld_const(0, 0), -- @line 3 @addr 0 // i = 0;
		ld_const(1, 1), -- @line 4 @addr 1 
		ld_const(2, 4), -- @line 5 @addr 2 
		ld_const(3, 0), -- @line 6 @addr 3 // acc = 0;
		ld_const(4, 10), -- @line 7 @addr 4 
-- loop_start:
		add(3, 3, 4), -- @line 9 @addr 5 // acc += 10
		add(0, 0, 1), -- @line 10 @addr 6 // i++
		sub(5, 0, 2), -- @line 11 @addr 7 // i < 4
		jmp(5, P_BELOW), -- @line 12 @addr 8 
		mov(15, 3), -- @line 13 @addr 9 
-- infinite_loop:
		jmp(10), -- @line 15 @addr 10 

		others => nop
	);
	
begin

	o_instruction <= rom(conv_integer(i_addr));

end architecture instruction_rom_arch;
