library ieee;
use ieee.std_logic_1164.all;

entity GENPROP is
  port( Gik, Gk1j: in std_logic;
        Pik, Pk1j: in std_logic; --Pk1j is the same Pk-1j
		  out_gen: out std_logic;
        out_prop: out std_logic); 
end GENPROP;

 architecture BEHAVIORAL of GENPROP is
   begin
	
	 out_gen <= Gik OR (Pik AND Gk1j);
	 
	 out_prop <= Pik AND Pk1j;
	 
 end BEHAVIORAL;	 