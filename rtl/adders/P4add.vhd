library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity P4ADD is
  generic(N: integer:= 32);
  port(A, B: in std_logic_vector(N-1 downto 0); -- the inputs are the two operands, A and B
       C_in: in std_logic;
	   C_out: out std_logic; -- the carry out is not used, but it's considered because it can be useful if we need an output of N+1 bits in a successive stage 
	   Sum: out std_logic_vector(N-1 downto 0));
end P4ADD;

architecture STRUCTURAL of P4ADD is -- described in a structural way: we started from the previous generated blocks, i.e the sum generator and the carry generator, and we simply connected them
  signal not_B, out_mux : std_logic_vector(N-1 downto 0);
  signal C_int: std_logic_vector(N/4 downto 0); -- a signal was necessary in order to describe the wires that connect the two blocks (C_int stands for "internal carries")
  
  component network
  generic(N: integer:= 32; Nbit: integer:= 4);
  port(A_in, B_in: in std_logic_vector(N-1 downto 0);
       C_in: in std_logic;
	   C_out: out std_logic_vector((N/Nbit)-1 downto 0));
 end component;
  
  component SUM_GENERATOR
	generic(NBIT: integer:=32;M: integer:=4);
	port(A,B: in std_logic_vector(NBIT-1 downto 0);
		  Cin: in std_logic_vector((NBIT/4)-1 downto 0);
        Sum:  out std_logic_vector(NBIT-1 downto 0));
end component;

component MUX21_GENERIC
	generic (NBIT: integer:= 32); --The generic statement allows to define the number of bits
			 
	port  (A_mux:		In	std_logic_vector(NBIT-1 downto 0); --Declaration in a generic way of the various ports
			 B_mux:		In	std_logic_vector(NBIT-1 downto 0);
			 SEL_mux:	In	std_logic;
			 Y_mux:		Out	std_logic_vector(NBIT-1 downto 0));
end component;

   begin
   
   C_int(0) <= C_in; -- the first bit of the C_int signal is connected to the input carry
   C_out <= C_int(N/4);   -- the carry out is connected to the last bit of the C_int signal
   not_B <= not(B);

   mux: MUX21_GENERIC generic map(NBIT => 32) port map(A_mux => not_B, B_mux => B, SEL_mux => C_in, Y_mux => out_mux);
   -- if I've to perform a subtraction, C_in = 1, I need not(B) and thus I choose the input A_mux
   sparse_tree: network generic map(N=>N, Nbit=>4) port map(A_in=>A, B_in=>out_mux, C_in=>C_in, C_out=>C_int(N/4 downto 1)); -- the outputs of the carry generator structure are connected to the internal carry signal
   sum_gen: SUM_GENERATOR generic map(NBIT=>N, M=>4) port map(A=>A, B=>out_mux, Cin=>C_int(N/4-1 downto 0), Sum=>Sum); -- the internal carry is then used as input of the next structure, i.e. the sum generator
   
end STRUCTURAL;