-------------------------------------------------------------------------------
-- @file processor.vhd
-- @date Oct 17, 2014
--
-- @author Milos Subotic <milos.subotic.sm@gmail.com>
-- @license MIT
--
-- @brief Digital design of simple processor.
--
-- @version: 1.0
-- Changelog:
-- 1.0 - Initial version.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
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
	-- Registers
	
	signal program_counter : t_instr_addr := (others => '0');

	type t_registers is array (0 to registers_number-1) of t_word;
	signal registers       : t_registers := (others => conv_std_logic_vector(0, word_size));

	signal flags           : t_predicate := (others => '0');

	---------------------------------------------------------------------------
	-- Nets

	-- Instruction and its decoding.
	signal instruction     : t_instruction;
	signal predicate       : t_predicate;
	signal opcode          : t_opcode;
	signal dest_op         : t_operand;
	signal src1_op         : t_operand;
	signal src2_op         : t_operand;
	signal const           : t_word;
	signal jmp_addr        : t_instr_addr;

	-- ALU input.
	signal src1            : t_word;
	signal src2            : t_word;
	signal carry_in        : std_logic;

	-- ALU output.
	signal dest            : t_word;
	signal carry_out       : std_logic;
	signal zero            : std_logic;

	signal exec_instr      : std_logic;
	signal dest_we         : std_logic;
	signal flags_we        : std_logic;


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
				if opcode = OC_JMP and exec_instr = '1' then
					program_counter <= jmp_addr;
				else
					program_counter <= program_counter + 1;
				end if;
			end if;
		end if;
	end process program_counter_reg;

	---------------------------------------------------------------------------
	-- Split instruction.

	predicate <= instruction(instruction_size-1 downto instruction_size-predicate_size);
	opcode <= instruction(instruction_size-predicate_size-1 downto instruction_size-predicate_size-opcode_size);
	dest_op <= instruction(instruction_size-predicate_size-opcode_size-1 downto instruction_size-predicate_size-opcode_size-operand_size);
	src1_op <= instruction(instruction_size-predicate_size-opcode_size-operand_size-1 downto instruction_size-predicate_size-opcode_size-operand_size*2);
	src2_op <= instruction(instruction_size-predicate_size-opcode_size-operand_size*2-1 downto 0);
	const <= instruction(instruction_size-predicate_size-opcode_size-operand_size-1 downto 0);
	jmp_addr <= instruction(instruction_size-predicate_size-opcode_size-1 downto 0);

	---------------------------------------------------------------------------

	src1 <= registers(conv_integer(src1_op));
	src2 <= registers(conv_integer(src2_op));
	carry_in <= flags(2);

	alu: process(opcode, src1, src2, const, carry_in)
		variable res : std_logic_vector(word_size downto 0);
	begin
		-- For instructions for which not matter.
		dest <= (others => '0');
		dest_we <= '0';
		carry_out <= '0';
		zero <= '0';
		flags_we <= '0';
		case opcode is
			when OC_LD_CONST =>
				dest <= const;
				dest_we <= '1';
			when OC_MOV =>
				dest <= src1;
				dest_we <= '1';
			when OC_ADD =>
				res := ( '0' & src1 ) + ( '0' & src2 );

				dest <= res(word_size-1 downto 0);
				dest_we <= '1';

				carry_out <= res(word_size);
				flags_we <= '1';
			when OC_SUB =>
				res := ( '0' & src1 ) - ( '0' & src2 );

				dest <= res(word_size-1 downto 0);
				dest_we <= '1';

				carry_out <= res(word_size);
				flags_we <= '1';
			when others =>
				dest_we <= '0';
				flags_we <= '0';
		end case;
	end process alu;

	---------------------------------------------------------------------------
	
	registers_ram: process(i_clk)
	begin
		if rising_edge(i_clk) then
			if in_reset = '0' then
				registers <= (others => conv_std_logic_vector(0, word_size));
			elsif dest_we = '1' and exec_instr = '1' then
				registers(conv_integer(dest_op)) <= dest;
			end if;
		end if;
	end process registers_ram;

	flags_reg: process(i_clk)
	begin
		if rising_edge(i_clk) then
			if in_reset = '0' then
				flags <= (others => '0');
			elsif flags_we = '1' and exec_instr = '1' then
				flags <= (not carry_out and not zero) & carry_out & not zero & zero;
			end if;
		end if;
	end process flags_reg;

	---------------------------------------------------------------------------
	-- Predicate check.

	exec_instr <= '1' when (predicate and flags) = predicate else '0';

	---------------------------------------------------------------------------
	-- Register mapping.

	-- Value of register 15 is mapped to LEDs.
	o_leds <= registers(15);

	---------------------------------------------------------------------------

end architecture processor_arch_v1;

