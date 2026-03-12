library IEEE;
use IEEE.std_logic_1164.all; --  libreria IEEE con definizione tipi standard logic
use IEEE.numeric_std.all;

entity NAND4 is
	Port (	A:	In	std_logic;
		B:	In	std_logic;
      C:	In	std_logic;
		D:	In	std_logic;
      Y:	Out	std_logic);
end NAND4;


architecture behav of NAND4 is

  signal Y_tmp1 : std_logic;
  signal Y_tmp2 : std_logic;

begin
	Y_tmp1 <= A AND B;
   Y_tmp2 <= C AND D;
   Y <= not(Y_tmp1 AND Y_tmp2);

end behav; 
