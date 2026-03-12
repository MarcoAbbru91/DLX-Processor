library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity memory is
	generic (N: integer := 32);
	port (add: in std_logic_vector (N-1 downto 0);
		  data_in: in std_logic_vector (N-1 downto 0);
		  CS, WR, RD, clk: in std_logic;
		  data_out: out std_logic_vector (N-1 downto 0));
end memory;

architecture behavior of memory is

type mem_array is array (0 to 63) of std_logic_vector(N-1 downto 0);
signal mem: mem_array ;

begin
Writing : process (clk)
	begin
	if (CS = '1') then
		if (clk ='1' and clk' event) then
			if WR ='1' then
			 mem(to_integer(unsigned(add))) <= data_in;
			end if;
		end if;
	end if;
end process;

Reading : process (RD,add)
	begin
	IF (CS='1') then
		if (RD='1') then
		data_out <= mem(to_integer(unsigned(add)));
		end if;
	end if;
end process;
end behavior;