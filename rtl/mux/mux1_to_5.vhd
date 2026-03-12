library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity mux1_to_5 is
 generic(N : integer := 32);
 port(A_mux  : in std_logic_vector(N-1 downto 0);
      Sel_mux: in std_logic_vector(3 downto 0);
      Y1_mux  : out std_logic_vector(N-1 downto 0);
      Y2_mux  : out std_logic_vector(N-1 downto 0);
      Y3_mux  : out std_logic_vector(N-1 downto 0);
      Y4_mux  : out std_logic_vector(N-1 downto 0);
      Y5_mux  : out std_logic_vector(N-1 downto 0));
end mux1_to_5;

architecture behavioral of mux1_to_5 is

  begin

	process (Sel_mux, A_mux)
		begin

	    case Sel_mux is
			when "0000" => Y1_mux <= A_mux; -- ADD/I..  -- branch, jump
			when "0001" => Y1_mux <= A_mux; -- SUB/I
			when "0010" => Y3_mux <= A_mux; -- AND/I.. logical
			when "0011" => Y3_mux <= A_mux; -- OR/I.. logical
			when "0100" => Y3_mux <= A_mux; -- XOR/I.. logical
			when "0101" => Y2_mux <= A_mux; -- SGE/I.. comparator
			when "0110" => Y2_mux <= A_mux; -- SLE/I.. comparator
			when "0111" => Y4_mux <= A_mux; -- SLL/I.. shift
			when "1000" => Y2_mux <= A_mux; -- SNE/I.. comparator
			when "1001" => Y4_mux <= A_mux; -- SRL/I.. shift
			when "1010" => Y3_mux <= A_mux; -- XNOR/I.. logical
		   when "1011" => Y5_mux <= A_mux; -- MUL/MULU
			when "1100" => Y2_mux <= A_mux; -- SEQ.. comparator
		   when "1101" => Y2_mux <= A_mux; -- SLT.. comparator
		   when "1110" => Y2_mux <= A_mux; -- SGT.. comparator
		   when others => Y1_mux <=(others=>'0'); Y2_mux<= (others=>'0'); Y3_mux<= (others=>'0'); Y4_mux<= (others=>'0'); Y5_mux <= (others=>'0');
		   end case;
	end process;
end behavioral;
