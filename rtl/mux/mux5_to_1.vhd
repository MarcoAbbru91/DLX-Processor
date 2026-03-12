library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity mux5_to_1 is
 generic(N : integer := 32);
 port(A  : in std_logic_vector(N-1 downto 0);
	   B  : in std_logic_vector(N-1 downto 0);
      C  : in std_logic_vector(N-1 downto 0);
      D  : in std_logic_vector(N-1 downto 0);
      E  : in std_logic_vector(N-1 downto 0);
      Sel: in std_logic_vector(3 downto 0);
      Y  : out std_logic_vector(N-1 downto 0)
);
end mux5_to_1;

architecture behavior of mux5_to_1 is

	signal out_tmp: std_logic_vector(N-1 downto 0);

  begin

	--out_tmp <= (others=>'0');

	with Sel select Y <=
		A when "0000", --ADD/I
		A when "0001", --SUB/I
		C when "0010", --AND/I
		C when "0011", --OR/I
		C when "0100", --XOR/I
		B when "0101", --SGE/I .. comparator
		B when "0110", --SLE/I .. comparator
		D when "0111", --SLL/I
		B when "1000", --SNE/I .. comparator
		D when "1001", --SRL/I
		C when "1010", --XNOR/I
		E when "1011", --MUL/MULTU
		B when "1100", --SEQ .. comparator
		B when "1101", --SLT .. comparator
		B when "1110", --SGT .. comparator
		A when others;

end behavior;