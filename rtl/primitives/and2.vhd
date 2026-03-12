library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity AND2 is
	port (A: In	std_logic;
		  B: In std_logic;
		  Y: Out std_logic);
end AND2;

architecture ARCH1 of AND2 is
begin
	Y <= (A AND B); 

end ARCH1; 
