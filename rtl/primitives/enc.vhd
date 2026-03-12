library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity encoder is
 generic(N: integer:= 3);
 port(B_enc: in std_logic_vector(N-1 downto 0);
      out_enc: out std_logic_vector(N-1 downto 0));
end encoder;

architecture BEHAVIOR of encoder is 

-- encoder described in a behavioral way, i.e. simply assigning an output to a given input. The output were chosen taking into account the the structure of the multiplexer that we described

 begin 

    out_enc <= "111" when B_enc = "000" else
	           "001" when B_enc = "001" else
	           "010" when B_enc = "010" else
	           "011" when B_enc = "011" else
	           "100" when B_enc = "100" else
               "101" when B_enc = "101" else
	           "110" when B_enc = "110" else
	           "000" when B_enc = "111";
	
end BEHAVIOR;