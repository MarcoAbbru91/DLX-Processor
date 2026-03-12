library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity logicals is
 generic(N : integer := 32);
 port(ALU_opcode  : in std_logic_vector(3 downto 0);
      operand1    : in std_logic_vector(N-1 downto 0);
      operand2    : in std_logic_vector(N-1 downto 0);
      bitwise_out : out std_logic_vector(N-1 downto 0)
);
end logicals;

architecture structural of logicals is

component NAND3
	port (	A:	In	std_logic;
		B:	In	std_logic;
      C:	In	std_logic;
		Y:	Out	std_logic);
end component;

component NAND4
	port (	A:	In	std_logic;
		B:	In	std_logic;
      C:	In	std_logic;
		D:	In	std_logic;
      Y:	Out	std_logic);
end component;

   signal sel0         : std_logic_vector(N-1 downto 0);
	signal sel1         : std_logic_vector(N-1 downto 0);
	signal sel2         : std_logic_vector(N-1 downto 0);
   signal sel3         : std_logic_vector(N-1 downto 0);
   signal out_1        : std_logic_vector(N-1 downto 0);
   signal out_2        : std_logic_vector(N-1 downto 0);
   signal out_3        : std_logic_vector(N-1 downto 0);
   signal out_4        : std_logic_vector(N-1 downto 0);

 signal not_op1, not_op2 : std_logic_vector(N-1 downto 0);
 
 begin

 logic: process(ALU_opcode, operand1, operand2)
   begin

   if ALU_opcode = "0010" then   -- AND / ANDI
    sel0 <= (others => '0');
    sel1 <= (others => '0');
    sel2 <= (others => '0');
    sel3 <= (others => '1');

    elsif ALU_opcode = "0011" then  -- OR / ORI
    sel0 <= (others => '0');
    sel1 <= (others => '1');
    sel2 <= (others => '1');
    sel3 <= (others => '1');

    elsif ALU_opcode = "0100" then  -- XOR / XORI
    sel0 <= (others => '0');
    sel1 <= (others => '1');
    sel2 <= (others => '1');
    sel3 <= (others => '0');

    elsif ALU_opcode = "1010" then  -- XNOR / XNORI
    sel0 <= (others => '1');
    sel1 <= (others => '0');
    sel2 <= (others => '0');
    sel3 <= (others => '1');
 

    end if;

 end process;

 not_op1 <= not(operand1);
 not_op2 <= not(operand2);
    inst1:  for i in 0 to N-1 generate
      NND31: NAND3 port map(A => sel0(i), B => not_op1(i), C => not_op2(i), Y => out_1(i));
    end generate;

    inst2:  for i in 0 to N-1 generate
      NND32: NAND3 port map(A => sel1(i), B => not_op1(i), C => operand2(i), Y => out_2(i));
    end generate;

    inst3:  for i in 0 to N-1 generate
      NND33: NAND3 port map(A => sel2(i), B => operand1(i), C => not_op2(i), Y => out_3(i));
    end generate;

    inst4:  for i in 0 to N-1 generate
      NND34: NAND3 port map(A => sel3(i), B => operand1(i), C => operand2(i), Y => out_4(i));
    end generate;

    level2: for i in 0 to N-1 generate
       NND4: NAND4 port map(A => out_1(i), B => out_2(i), C => out_3(i), D => out_4(i), Y => bitwise_out(i));
    end generate;

end structural;
