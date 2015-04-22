-------------------------------------------------------------------------------
-- @file processor.vhd
-- @date Oct 17, 2014
--
-- @author Milos Subotic <milos.subotic.sm@gmail.com>
-- @license MIT
--
-- @brief Digital design of simple processor.
--
-- @version: 1.1
-- Changelog:
-- 1.0 - Initial version.
-- 1.1 - numeric_std.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.instruction_set.all;

entity processor is
	port (
		i_clk    : in  std_logic;
		in_reset : in  std_logic;
		o_leds   : out std_logic_vector(7 downto 0)
	);
end entity processor;

architecture processor_arch_v1 of processor is
	---------------------------------------------------------------------------
	-- Components declarations.
	
	component instruction_rom is
		port (
			i_addr        : in  t_instr_addr;
			o_instruction : out t_instruction
		);
	end component instruction_rom;

	---------------------------------------------------------------------------
	-- Registers.
	
	signal program_counter : t_instr_addr;

	type t_registers is array (0 to registers_number-1) of t_word;
	signal registers       : t_registers;

	signal flags           : t_predicate;

	---------------------------------------------------------------------------
	-- Nets.

	-- Instruction and its fields.
	signal instruction     : t_instruction;
	signal predicate       : t_predicate;
	signal opcode          : t_opcode;
	signal dest_op         : t_dest_op;
	signal src1_op         : t_src1_op;
	signal src2_op         : t_src2_op;
	signal const           : t_word;
	signal jmp_addr        : t_instr_addr;

	-- ALU input.
	signal src1            : t_word;
	signal src2            : t_word;
	signal carry_in        : std_logic;

	-- ALU output.
	signal alu_res         : unsigned(word_size downto 0);
	signal dest            : t_word;
	signal carry_out       : std_logic;
	signal zero            : std_logic;

	-- WE for regs.
	signal flags_we        : std_logic;
	signal dest_we         : std_logic;
	signal jmp_en          : std_logic;
	signal exec_instr      : std_logic;


	---------------------------------------------------------------------------

begin

	---------------------------------------------------------------------------

	instr_rom : instruction_rom
	port map (
		i_addr  => program_counter,
		o_instruction => instruction
	);

	program_counter_reg: process(i_clk)
	begin
		if rising_edge(i_clk) then
			if in_reset = '0' then
				program_counter <= (others => '0');
			else
				if jmp_en = '1' and exec_instr = '1' then
					program_counter <= jmp_addr;
				else
					program_counter <= program_counter + 1;
				end if;
			end if;
		end if;
	end process program_counter_reg;

	---------------------------------------------------------------------------
	-- Decoding (splitting) instruction to its fields.

	predicate <= instruction(t_predicate'range);
	opcode    <= instruction(t_opcode'range);
	dest_op   <= unsigned(instruction(dest_op'range));
	src1_op   <= unsigned(instruction(src1_op'range));
	src2_op   <= unsigned(instruction(src2_op'range));
	const     <= instruction(t_word'range);
	jmp_addr  <= unsigned(instruction(t_instr_addr'range));

	---------------------------------------------------------------------------
	-- Reading from registers and flags.	

	src1 <= registers(to_integer(src1_op));
	src2 <= registers(to_integer(src2_op));
	carry_in <= flags(t_predicate'low + 2);

	---------------------------------------------------------------------------

	-- ALU
	with opcode select
		alu_res <= 
			'0' & unsigned(const)                       when OC_LD_CONST,
			'0' & unsigned(src1)                        when OC_MOV,
			unsigned('0' & src1) + unsigned('0' & src2) when OC_ADD,
			unsigned('0' & src1) - unsigned('0' & src2) when OC_SUB,
			(others => '0')                             when others;

	---------------------------------------------------------------------------
	-- Prepare data for writing.

	dest      <= std_logic_vector(alu_res(word_size-1 downto 0));
	carry_out <= std_logic(alu_res(word_size));
	zero      <= '1' when alu_res(word_size-1 downto 0) = 0 else '0';

	---------------------------------------------------------------------------
	-- Resolve enables for registers, flags and jump from opcode.

	with opcode select
		flags_we <= 
			'1' when OC_ADD,
			'1' when OC_SUB,
			'0' when others;

	with opcode select
		dest_we <= 
			'1' when OC_LD_CONST,
			'1' when OC_MOV,
			'1' when OC_ADD,
			'1' when OC_SUB,
			'0' when others;

	with opcode select
		jmp_en <=
			'1' when OC_JMP,
			'0' when others;

	---------------------------------------------------------------------------
	-- Writing to registers and flags.

	registers_ram: process(i_clk)
	begin
		if rising_edge(i_clk) then
			if dest_we = '1' and exec_instr = '1' then
				registers(to_integer(unsigned(dest_op))) <= dest;
			end if;
		end if;
	end process registers_ram;

	flags_reg: process(i_clk)
	begin
		if rising_edge(i_clk) then
			if flags_we = '1' and exec_instr = '1' then
				flags <= 
					(not carry_out and not zero) & carry_out & not zero & zero;
			end if;
		end if;
	end process flags_reg;

	---------------------------------------------------------------------------
	-- Predicate check.

	-- If some bit in predicate is 1, and coresponding bit in flags is also 1
	-- then instruction will be executed.
	-- 0 bit in predicate means that it is not matter what is in flags.
	exec_instr <= '1' when (predicate and flags) = predicate else '0';

	---------------------------------------------------------------------------
	-- Register mapping.

	-- Value of register 15 is mapped to LEDs.
	o_leds <= registers(15);

	---------------------------------------------------------------------------

end architecture processor_arch_v1;

