-------------------------------------------------------------------------------
-- @file processor_tb.vhd
-- @date Oct 17, 2014
--
-- @author Milos Subotic <milos.subotic.sm@gmail.com>
-- @license MIT
--
-- @brief Testbench for processor.
--
-- @version: 1.1
-- Changelog:
-- 1.0 - Initial version.
-- 1.1 - Asserts and numeric_std.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.processor;

entity processor_tb is
end entity processor_tb;

architecture processor_tb_arch of processor_tb is

	-- Possible values: note, warning, error, failure;
	constant assert_severity : severity_level := failure; 

	signal i_clk        : std_logic := '1';
	signal in_reset     : std_logic := '0';
	signal o_leds       : std_logic_vector(7 downto 0);

	constant clk_period : time      := 10 ns;
	
	file stdout: text open write_mode is "STD_OUTPUT";
	procedure println(s: string) is
		variable l: line;
	begin
		write(l, s);
		writeline(stdout, l);
	end procedure println;

begin
		
	dut: entity processor
	port map (
		i_clk    => i_clk,
		in_reset => in_reset,
		o_leds   => o_leds
	);
	
	i_clk_process: process
	begin
		i_clk <= '1';
		wait for clk_period/2;
		i_clk <= '0';
		wait for clk_period/2;
	end process i_clk_process;

	stimulus_process: process
	begin
		wait for clk_period*2;
		in_reset <= '1';

		wait for clk_period*22;

		assert unsigned(o_leds) = to_unsigned(40, o_leds'length) 
			report "Output on LEDs is not what we expected!"
			severity assert_severity;

		println("--------------------------------------");
		println("Testbench done!");
		println("--------------------------------------");
	end process stimulus_process;

end architecture processor_tb_arch;

