library IEEE;
use IEEE.std_logic_1164.all; --  libreria IEEE con definizione tipi standard logic
use IEEE.numeric_std.all; -- libreria WORK user-defined

entity OR2 is
	port (	A:	In	std_logic;
		B:	In	std_logic;
		Y:	Out	std_logic);
end OR2;


architecture ARCH1 of OR2 is

begin
	Y <= (A OR B);

end ARCH1; 
