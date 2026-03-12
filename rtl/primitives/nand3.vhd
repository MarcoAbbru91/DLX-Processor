library IEEE;
use IEEE.std_logic_1164.all; --  libreria IEEE con definizione tipi standard logic
use IEEE.numeric_std.all;

entity NAND3 is
	port (	A:	In	std_logic;
		B:	In	std_logic;
      C:	In	std_logic;
		Y:	Out	std_logic);
end NAND3;


architecture behav of NAND3 is

  signal Y_tmp : std_logic;

begin
	Y_tmp <= A AND B;
   Y <= not(C AND Y_tmp);

end behav;