library ieee;
use ieee.std_logic_1164.all;

entity GENERAT is
  port( Gik, Gk1j: in std_logic; --Gk1j is the same of Gk-1j
        Pik: in std_logic;
        out_gen: out std_logic); 
end GENERAT;

 architecture BEHAVIORAL of GENERAT is
   begin
	
	 out_gen <= Gik OR (Pik AND Gk1j);
	 
 end BEHAVIORAL;