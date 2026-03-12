library IEEE;
use IEEE.std_logic_1164.all; --  libreria IEEE con definizione tipi standard logic

entity MUX21 is
	Port (A_mux:	In	std_logic;
		   B_mux:	In	std_logic;
		   SEL_mux:	In	std_logic;
		   Y_mux:	Out	std_logic);
end MUX21;

architecture BEHAVIORAL of MUX21 is

begin

    Y_mux <= A_mux when SEL_mux='1' else B_mux;

end BEHAVIORAL;