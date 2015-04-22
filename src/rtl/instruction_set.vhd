-------------------------------------------------------------------------------
-- @file instruction_set.vhd
-- @date Oct 18, 2014
--
-- @author Milos Subotic <milos.subotic.sm@gmail.com>
-- @license MIT
--
-- @brief Instruction set definition.
--
-- @version: 1.0
-- Changelog:
-- 1.0 - Initial version.
--
-------------------------------------------------------------------------------

library  ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package instruction_set is

	---------------------------------------------------------------------------

	-- Intructions structure:
	--
	-- 1st type:
	-- predicate    - 4 bits
	-- opcode       - 4 bits
	-- dest operand - 4 bits
	-- 1st operand  - 4 bits
	-- 2nd operand  - 4 bits
	--
	-- 2nd type:
	-- predicate    - 4 bits
	-- opcode       - 4 bits
	-- dest operand - 4 bits
	-- const word   - 8 bits
	--
	-- 3rd type:
	-- predicate    - 4 bits
	-- opcode       - 4 bits
	-- instr addr   - 12 bits

	constant predicate_size      : natural := 4;
	constant opcode_size         : natural := 4;
	constant operand_size        : natural := 4;
	constant word_size           : natural := 8;
	constant instr_addr_size     : natural := 12;
	constant instruction_size    : natural := 20;

	constant registers_number    : natural := 2**operand_size;
	constant instructions_number : natural := 256; --2**instr_addr_size;


	subtype t_predicate          is std_logic_vector(19 downto 16);
	constant P_ALWAYS            : t_predicate := "0000";
	constant P_EQUAL             : t_predicate := "0001";
	constant P_DIFFERENT         : t_predicate := "0010";
	constant P_BELOW             : t_predicate := "0100";
	constant P_ABOVE             : t_predicate := "1000";
	constant P_ZERO              : t_predicate := "0001";
	constant P_CARRY             : t_predicate := "0100";

	subtype t_opcode             is std_logic_vector(15 downto 12);

	subtype t_dest_op            is unsigned(11 downto 8);
	subtype t_src1_op            is unsigned(7 downto 4);
	subtype t_src2_op            is unsigned(3 downto 0);
	subtype t_word               is std_logic_vector(7 downto 0);
	subtype t_instr_addr         is unsigned(11 downto 0);
	subtype t_instruction        is std_logic_vector(19 downto 0);
	
	
	subtype t_operand_nat        is natural range 2**operand_size-1 downto 0;
	subtype t_word_nat           is natural range 2**word_size-1 downto 0;
	subtype t_instr_addr_nat     is natural range 2**instr_addr_size-1 downto 0;

	---------------------------------------------------------------------------

	constant OC_NOP      : t_opcode := std_logic_vector(to_unsigned(0, opcode_size));
	constant OC_JMP      : t_opcode := std_logic_vector(to_unsigned(1, opcode_size));
	constant OC_LD_CONST : t_opcode := std_logic_vector(to_unsigned(2, opcode_size));
	constant OC_MOV      : t_opcode := std_logic_vector(to_unsigned(3, opcode_size));
	constant OC_ADD      : t_opcode := std_logic_vector(to_unsigned(4, opcode_size));
	constant OC_SUB      : t_opcode := std_logic_vector(to_unsigned(5, opcode_size));

	---------------------------------------------------------------------------

	function nop return t_instruction;

	function jmp (
		addr      : t_instr_addr_nat;
		predicate : t_predicate := P_ALWAYS
	) return t_instruction;

	function ld_const (
		dest      : t_operand_nat;
		const     : t_word_nat;
		predicate : t_predicate := P_ALWAYS
	) return t_instruction;
	
	function mov (
		dest      : t_operand_nat;
		src       : t_operand_nat;
		predicate : t_predicate := P_ALWAYS
	) return t_instruction;

	function add (
		dest      : t_operand_nat;
		src1      : t_operand_nat;
		src2      : t_operand_nat;
		predicate : t_predicate := P_ALWAYS
	) return t_instruction;

	function sub (
		dest      : t_operand_nat;
		src1      : t_operand_nat;
		src2      : t_operand_nat;
		predicate : t_predicate := P_ALWAYS
	) return t_instruction;

end package instruction_set;

package body instruction_set is


	function nop return t_instruction is
	begin
		return
			P_ALWAYS &
			OC_NOP & 
			std_logic_vector(to_unsigned(0, 3*operand_size));
	end function nop;

	function jmp (
		addr      : t_instr_addr_nat;
		predicate : t_predicate := P_ALWAYS
	) return t_instruction is
	begin
		return
			predicate &
			OC_JMP &
			std_logic_vector(to_unsigned(addr, instr_addr_size));
	end function jmp;

	function ld_const (
		dest      : t_operand_nat;
		const     : t_word_nat;
		predicate : t_predicate := P_ALWAYS
	) return t_instruction is
	begin
		return
			predicate &
			OC_LD_CONST &
			std_logic_vector(to_unsigned(dest, operand_size)) &
			std_logic_vector(to_unsigned(const, word_size));
	end function ld_const;
	
	function mov (
		dest      : t_operand_nat;
		src       : t_operand_nat;
		predicate : t_predicate := P_ALWAYS
	) return t_instruction is
	begin
		return
			predicate &
			OC_MOV &
			std_logic_vector(to_unsigned(dest, operand_size)) &
			std_logic_vector(to_unsigned(src, operand_size)) &
			std_logic_vector(to_unsigned(0, operand_size));
	end function mov;

	function add (
		dest      : t_operand_nat;
		src1      : t_operand_nat;
		src2      : t_operand_nat;
		predicate : t_predicate := P_ALWAYS
	) return t_instruction is
	begin
		return
			predicate &
			OC_ADD &
			std_logic_vector(to_unsigned(dest, operand_size)) &
			std_logic_vector(to_unsigned(src1, operand_size)) &
			std_logic_vector(to_unsigned(src2, operand_size));
	end function add;

	function sub (
		dest      : t_operand_nat;
		src1      : t_operand_nat;
		src2      : t_operand_nat;
		predicate : t_predicate := P_ALWAYS
	) return t_instruction is
	begin
		return
			predicate &
			OC_SUB &
			std_logic_vector(to_unsigned(dest, operand_size)) &
			std_logic_vector(to_unsigned(src1, operand_size)) &
			std_logic_vector(to_unsigned(src2, operand_size));
	end function sub;

end package body instruction_set;

