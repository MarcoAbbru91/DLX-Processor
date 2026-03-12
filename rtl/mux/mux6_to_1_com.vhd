library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity mux6_to_1_comp is
 port(A  : in std_logic;
	   B  : in std_logic;
      C  : in std_logic;
      D  : in std_logic;
      E  : in std_logic;
		F  : in std_logic;
      Sel: in std_logic_vector(3 downto 0);
      Y  : out std_logic);
end mux6_to_1_comp;

architecture behavior of mux6_to_1_comp is

	signal out_tmp: std_logic;
	
  begin
	
	out_tmp<='U';
	
	with Sel select Y <=
		D when "0101", --SGE/I .. comparator
		A when "0110", --SLE/I .. comparator
		F when "1000", --SNE/I .. comparator
		E when "1100", --SEQ .. comparator
		B when "1101", --SLT .. comparator
		C when "1110", --SGT .. comparator
		out_tmp when others;
		
end behavior;