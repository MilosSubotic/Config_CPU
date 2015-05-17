-------------------------------------------------------------------------------
--
-- @author Milos Subotic <milos.subotic.sm@gmail.com>
-- @license MIT
--
-- @brief Entity of instruction ROM.
--
-------------------------------------------------------------------------------

use work.instruction_set.all;

entity instruction_rom is
	port (
		i_addr        : in  t_addr0;
		o_instruction : out t_instruction
	);
end entity instruction_rom;

