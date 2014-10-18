-------------------------------------------------------------------------------
-- @file processor_TB.vhd
-- @date Oct 17, 2014
--
-- @author Milos Subotic <milos.subotic.sm@gmail.com>
-- @license MIT
--
-- @brief Testbench for processor.
--
-- @version: 1.0
-- Changelog:
-- 1.0 - Initial version.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity processor_tb is
end entity processor_tb;

architecture processor_tb_arch of processor_tb is

	component processor is
		port (
			i_clk    : in  std_logic;
			in_reset : in  std_logic;
			o_leds   : out std_logic_vector(7 downto 0)
		);
	end component processor;

	signal i_clk        : std_logic := '0';
	signal in_reset     : std_logic := '0';
	signal o_leds       : std_logic_vector(7 downto 0);

	constant clk_period : time      := 10 ns;

begin
	
	
	dut: processor
	port map (
		i_clk    => i_clk,
		in_reset => in_reset,
		o_leds   => o_leds
	);
	

	i_clk_process: process
	begin
		i_clk <= '0';
		wait for clk_period/2;
		i_clk <= '1';
		wait for clk_period/2;
	end process i_clk_process;

	stimulus_process: process
	begin
		wait for clk_period*2;
		in_reset <= '1';

		wait;
	end process stimulus_process;

end architecture processor_tb_arch;

