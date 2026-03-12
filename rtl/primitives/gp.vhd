library ieee;
use ieee.std_logic_1164.all;

entity GP is
 port(A, B: in std_logic;
      gnrat, prpgat: out std_logic);
end GP;

-- basic block which generates the AND and OR operations (i.e. the generate and propagate operations, respectively), in a behavioral way

 architecture BEHAVIORAL of GP is 
  
  begin
   
   gnrat <= A AND B;
   prpgat <= A XOR B;
	
 end BEHAVIORAL;	