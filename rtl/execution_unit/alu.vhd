library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity ALU is
  generic (N: integer := 32);
  port 	 (ALU_OP: 	    IN std_logic_vector (3 downto 0);
           DATA1, DATA2: IN std_logic_vector(N-1 downto 0);
           OUTALU:       OUT std_logic_vector(N-1 downto 0));
end ALU;

architecture STRUCTURAL of ALU is

   component BOOTHMUL 
	 generic(N: integer := 16);
	 port(A, B: in std_logic_vector(N-1 downto 0);     -- A and B are the two input operands
		   P:    out std_logic_vector(2*N-1 downto 0)); -- P is the final product, which is on 2*N bits
   end component;

component P4ADD
  generic(N: integer:= 32);
  port(A, B:  in std_logic_vector(N-1 downto 0); -- the inputs are the two operands, A and B
       C_in:  in std_logic;
	    C_out: out std_logic; -- carry out not used, but it's considered because it can be useful if we need an output of N+1 bits in a successive stage 
	    Sum:   out std_logic_vector(N-1 downto 0));
end component;

 component comparators
 generic(N: integer := 32);
 port(operand1       : in std_logic_vector(N-1 downto 0);
      operand2       : in std_logic_vector(N-1 downto 0);
	   ALU_opcode     : in std_logic_vector(3 downto 0);
      out_comparator : out std_logic_vector(N-1 downto 0));
 end component;

	component logicals
		generic(N : integer := 32);
		port(ALU_opcode  : in std_logic_vector(3 downto 0);
			  operand1    : in std_logic_vector(N-1 downto 0);
           operand2    : in std_logic_vector(N-1 downto 0);
           bitwise_out : out std_logic_vector(N-1 downto 0));
	end component;

  component SHIFTER_GENERIC is
		generic(N: integer := 32);
		port(A:            in std_logic_vector(N-1 downto 0);
			  B:            in std_logic_vector(4 downto 0);
			  LOGIC_ARITH:  in std_logic;	-- 1 = logic, 0 = arith
			  LEFT_RIGHT:   in std_logic;	-- 1 = left, 0 = right
			  SHIFT_ROTATE: in std_logic;	-- 1 = shift, 0 = rotate
			  OUTPUT:       out std_logic_vector(N-1 downto 0));
	end component;

component mux1_to_5
 generic(N: integer := 32);
 port(A_mux   : in std_logic_vector(N-1 downto 0);
      Sel_mux : in std_logic_vector(3 downto 0);
      Y1_mux  : out std_logic_vector(N-1 downto 0);
      Y2_mux  : out std_logic_vector(N-1 downto 0);
      Y3_mux  : out std_logic_vector(N-1 downto 0);
      Y4_mux  : out std_logic_vector(N-1 downto 0);
      Y5_mux  : out std_logic_vector(N-1 downto 0));
end component;

component mux5_to_1
 generic(N: integer := 32);
 port(A  : in std_logic_vector(N-1 downto 0);
	   B  : in std_logic_vector(N-1 downto 0);
      C  : in std_logic_vector(N-1 downto 0);
      D  : in std_logic_vector(N-1 downto 0);
      E  : in std_logic_vector(N-1 downto 0);
      Sel: in std_logic_vector(3 downto 0);
      Y  : out std_logic_vector(N-1 downto 0));
end component;

signal out1_mux1, out2_mux1, out3_mux1, out4_mux1, out5_mux1, out6_mux1, out7_mux1, out8_mux1 : std_logic_vector(N-1 downto 0);
signal out1_mux2, out2_mux2, out3_mux2, out4_mux2, out5_mux2, out6_mux2, out7_mux2, out8_mux2 : std_logic_vector(N-1 downto 0);
signal not_out1_mux2,out_P4, comparator_out, logic_out, shift_out, out_mul : std_logic_vector(N-1 downto 0);
signal c_out : std_logic;


begin

 mux1: mux1_to_5 generic map(N => 32) port map(A_mux => DATA1, Sel_mux =>  ALU_OP, Y1_mux => out1_mux1, Y2_mux => out2_mux1, Y3_mux => out3_mux1, Y4_mux => out4_mux1, Y5_mux => out5_mux1);

 mux2: mux1_to_5 generic map(N => 32) port map(A_mux => DATA2, Sel_mux =>  ALU_OP, Y1_mux => out1_mux2, Y2_mux => out2_mux2, Y3_mux => out3_mux2, Y4_mux => out4_mux2, Y5_mux => out5_mux2);

 P4: P4ADD generic map(N => 32) port map(A => out1_mux1, B => out1_mux2, C_in => ALU_OP(0), C_out => c_out, Sum => out_P4);
  -- P4 adder to perform a sum when the opcode is "0000", a subtraction when the opcode is "0001", therefore "C_in" is given by the LSB of the opcode: if it is 1, I have to perform subtraction, C_in=1 and I take B_mux = not(out1_mux2)
 comp: comparators generic map(N => 32) port map(operand1 => out2_mux1, operand2 => out2_mux2,ALU_opcode=>ALU_OP, out_comparator => comparator_out);

 logic: logicals generic map(N => 32) port map(ALU_opcode => ALU_OP, operand1 => out3_mux1, operand2 => out3_mux2, bitwise_out => logic_out);
 shift: SHIFTER_GENERIC generic map(N => 32) port map(A => out4_mux1, B => out4_mux2(4 downto 0), LOGIC_ARITH =>ALU_OP(2), LEFT_RIGHT => ALU_OP(1), SHIFT_ROTATE => '1', OUTPUT => shift_out);

 mul: BOOTHMUL generic map(N => 16) port map(A => out5_mux1(15 downto 0), B => out5_mux2(15 downto 0), P => out_mul);
 mux_out: mux5_to_1 generic map(N => 32) port map(A => out_P4, B => comparator_out, C => logic_out, D => shift_out, E => out_mul, Sel => ALU_OP, Y => OUTALU);


end STRUCTURAL;