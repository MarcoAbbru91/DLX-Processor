library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity comparators is
generic(N : integer := 32);
port(
   operand1   : in  std_logic_vector(N-1 downto 0);
   operand2   : in  std_logic_vector(N-1 downto 0);
	ALU_opcode : in std_logic_vector(3 downto 0);
   out_comparator : out std_logic_vector(N-1 downto 0)
);
end comparators;


architecture structural of comparators is

	component P4ADD
		generic(N: integer:= 32);
		port(A, B: in std_logic_vector(N-1 downto 0); -- the inputs are the two operands, A and B
			 C_in: in std_logic;
			C_out: out std_logic; -- carry out not used, but considered because it can be useful if we need an output of N+1 bits in a successive stage 
			Sum: out std_logic_vector(N-1 downto 0));
	end component;

	component AND2
		port (	A:	In	std_logic;
			B:	In	std_logic;
			Y:	Out	std_logic);
	end component;

	component OR2
		port (	A:	In	std_logic;
			B:	In	std_logic;
			Y:	Out	std_logic);
	end component;

	component NOR32
		port (A:	In	std_logic_vector(N-1 downto 0);
				Y:	Out	std_logic);
	end component;

	component mux6_to_1_comp 
	port(A  : in std_logic;
		  B  : in std_logic;
		  C  : in std_logic;
		  D  : in std_logic;
		  E  : in std_logic;
		  F  : in std_logic;
		  Sel: in std_logic_vector(3 downto 0);
		  Y  : out std_logic);
	end component;

	signal out_P4   : std_logic_vector(N-1 downto 0);
	signal c_out, NOR_Sum, out_OR, out_AND, out_tmp, not_NOR_sum, not_cout : std_logic;

	--signal not_op2 : std_logic_vector(N-1 downto 0);

	signal less_equal : std_logic;
	signal less       : std_logic;
	signal greater    : std_logic;
	signal greater_eq : std_logic;
	signal equal      : std_logic;
	signal not_equal: std_logic;

	begin

	--not_op2 <= not(operand2);
	P4: P4ADD generic map(N => 32) port map(A => operand1, B =>operand2, C_in => '1', C_out => c_out, Sum => out_P4);
	NOR2: NOR32 port map(A => out_P4, Y => NOR_Sum);
	not_cout <= not(c_out);
	OR21: OR2 port map(A => not_cout, B => NOR_sum, Y => out_OR);
	less_equal <= out_OR;
	not_NOR_sum <= not(NOR_Sum);
	AND21: AND2 port map(A => c_out, B => not_NOR_sum, Y => out_AND);
	greater <= out_AND;
	less <= not(c_out);
	greater_eq <= c_out;
	equal <= NOR_Sum;
	not_equal<=not equal;
	
	mux_out: mux6_to_1_comp port map(A => less_equal, B => less, C => greater, D => greater_eq, E=>equal, F=>not_equal, Sel => ALU_opcode, Y => out_tmp);

	out_comparator <= "0000000000000000000000000000000" & out_tmp;

end structural; 
