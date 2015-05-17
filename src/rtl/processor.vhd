-------------------------------------------------------------------------------
--
-- @author Milos Subotic <milos.subotic.sm@gmail.com>
-- @license MIT
--
-- @brief Digital design of simple processor.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.instruction_set.all;
use work.instruction_rom;

entity processor is
	port (
		i_clk    : in  std_logic;
		in_reset : in  std_logic;
		o_leds   : out std_logic_vector(7 downto 0)
	);
end entity processor;

architecture processor_arch_v1 of processor is

	---------------------------------------------------------------------------
	-- Registers.
	
	signal program_counter : t_addr0;

	type t_registers is array (0 to REGISTER_NUMBER-1) of t_word;
	signal registers       : t_registers;

   signal zero            : std_logic;
	signal carry           : std_logic;

	---------------------------------------------------------------------------
	-- Nets.

	-- Instruction and its fields.
	signal instruction     : t_instruction;
	signal predicate       : t_predicate;
	signal opcode          : t_opcode;
	signal dst0            : t_dst0;
	signal src0            : t_src0;
	signal src1            : t_src1;
	signal num_word        : t_num0;
	signal num_half_word   : t_num1;
	signal jmp_addr        : t_addr0;

	-- ALU input.
	signal w_src0          : t_word;
	signal w_src1          : t_word;
	signal carry_in        : std_logic;

	-- ALU output.
	signal alu_res         : unsigned(t_word'left+1 downto t_word'right);
	signal w_dst0          : t_word;
	signal carry_out       : std_logic;
	signal zero_out        : std_logic;

	-- WE for regs.
	signal flags_we        : std_logic;
	signal dest_we         : std_logic;
	signal jmp_en          : std_logic;
	signal exec_instr      : std_logic;

   -- Temporals for calculation.
	signal u_src0          : unsigned(t_word'range);
	signal u_src1          : unsigned(t_word'range);
	signal s_src0          : signed(t_word'range);
	signal s_src1          : signed(t_word'range);
   signal pred_calc_out   : std_logic;

	---------------------------------------------------------------------------

begin

	---------------------------------------------------------------------------

	instr_rom : entity instruction_rom
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
   
	predicate     <= instruction(t_predicate'range);
	opcode        <= instruction(t_opcode'range);
	dst0          <= unsigned(instruction(t_dst0'range));
	src0          <= unsigned(instruction(t_src0'range));
	src1          <= unsigned(instruction(t_src1'range));
	num_word      <= unsigned(instruction(t_num0'range));
	num_half_word <= unsigned(instruction(t_num1'range));
	jmp_addr      <= unsigned(instruction(t_addr0'range));

	---------------------------------------------------------------------------
	-- Reading from registers.	
   
	w_src0 <= registers(to_integer(src0));
	w_src1 <= registers(to_integer(src1));

   ---------------------------------------------------------------------------
   -- Temporals.
   
	u_src0 <= unsigned(w_src0);
	u_src1 <= unsigned(w_src1);
	s_src0 <= signed(w_src0);
	s_src1 <= signed(w_src1);
	
	---------------------------------------------------------------------------

	-- ALU
	with opcode select
		alu_res <= 
			'0' & num_word                             when OC_LD_NUM,
			'0' & u_src0                               when OC_MOV,
			('0' & u_src0) + ('0' & u_src1)            when OC_ADD,
			('0' & u_src0) - ('0' & u_src1)            when OC_SUB,
			('0' & u_src0) + ("00000" & num_half_word) when OC_ADDK,
			('0' & u_src0) - ("00000" & num_half_word) when OC_SUBK,
			(others => '0')                            when others;

	---------------------------------------------------------------------------
	-- Prepare data for writing.

	w_dst0    <= std_logic_vector(alu_res(t_word'range));
	carry_out <= std_logic(alu_res(t_word'left+1));
	zero_out  <= '1' when alu_res(t_word'range) = 0 else '0';

	---------------------------------------------------------------------------
	-- Resolve enables for registers, flags and jump from opcode.

	with opcode select
		flags_we <= 
			'1' when OC_ADD,
			'1' when OC_SUB,
			'0' when others;

	with opcode select
		dest_we <= 
			'1' when OC_LD_NUM,
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
				registers(to_integer(dst0)) <= w_dst0;
			end if;
		end if;
	end process registers_ram;

	flags_reg: process(i_clk)
	begin
		if rising_edge(i_clk) then
			if flags_we = '1' and exec_instr = '1' then
            zero <= zero_out;
				carry <= carry_out;
			end if;
		end if;
	end process flags_reg;

	---------------------------------------------------------------------------
	-- Predicate check.

   with predicate(t_predicate'left downto t_predicate'right+1) select
      pred_calc_out <= 
			'1'   when "000",
			zero  when "001",
			carry when "010",
			'1'   when others;
   
   -- Lowest bit of predicate negate result.
   exec_instr <= 
      pred_calc_out when predicate(t_predicate'right) = '0' else 
      not pred_calc_out;

	---------------------------------------------------------------------------
	-- Register mapping.

	-- Value of register 15 is mapped to LEDs.
	o_leds <= registers(15);

	---------------------------------------------------------------------------

end architecture processor_arch_v1;

