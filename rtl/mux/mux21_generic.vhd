library IEEE;
use IEEE.std_logic_1164.all;

entity MUX21_GENERIC is
	generic (NBIT: integer:= 32); --The generic statement allows to define the number of bits
			 
	port  (	A_mux:		In	std_logic_vector(NBIT-1 downto 0); --Declaration in a generic way of the various ports
			B_mux:		In	std_logic_vector(NBIT-1 downto 0);
			SEL_mux:	In	std_logic;
			Y_mux:		Out	std_logic_vector(NBIT-1 downto 0));
end MUX21_GENERIC;

architecture BEHAVIORAL of MUX21_GENERIC is --In this section we describe the component in a behavioral way. 
											--In the behavioral description is the compiler that creates the internal 
											--connection. The user can see this connection only at the synthesis phase
 begin
   Y_mux <= A_mux when SEL_mux='1' else B_mux; --we insert in this case the mux delay

 end BEHAVIORAL;