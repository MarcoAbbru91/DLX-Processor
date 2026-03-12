library IEEE;
use IEEE.std_logic_1164.all; --  libreria IEEE con definizione tipi standard logic
use IEEE.numeric_std.all; -- libreria WORK user-defined

entity NOR32 is
	port (A:	in	std_logic_vector(31 downto 0);
	   	Y:	out	std_logic);
end NOR32;


architecture ARCH1 of NOR32 is

begin

	Y <= not(   A(0) OR A(1) OR A(2) OR A(3) OR A(4) OR A(5) OR A(6) OR A(7) OR A(8) OR A(9) OR A(10) OR A(11)
			   OR A(12) OR A(13) OR A(14) OR A(15) OR A(16) OR A(16) OR A(17) OR A(18)
				OR A(19) OR A(20) OR A(21) OR A(22) OR A(23) OR A(24) OR A(25) OR A(26) OR A(27) OR A(28) OR A(29) OR A(30));

end ARCH1; 
