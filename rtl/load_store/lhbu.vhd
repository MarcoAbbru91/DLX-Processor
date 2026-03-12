library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity lhbu is
	generic(N:integer:=32);
	port(data_in: in std_logic_vector(N-1 downto 0);
		  Sel: in std_logic_vector(1 downto 0);
		  data_out: out std_logic_vector(N-1 downto 0));
end lhbu;

architecture behavioral of lhbu is 
	
	signal lb,lbu,lh,lhu,tmp: std_logic_vector(N-1 downto 0);
	
	begin
	
	lb<=(N-1 downto 8=>data_in(7))&data_in(7 downto 0);
	lbu<=(N-1 downto 8=>'0')&data_in(7 downto 0);
	lh<= (N-1 downto 16=>data_in(15))&data_in(15 downto 0);
	lhu<=(N-1 downto 16=>'0')&data_in(15 downto 0);
	tmp<=(others=>'0');
	
	with Sel select data_out <=
		lb when "00", --LB
		lh when "01", --LH
		lbu when "10", --LBU
		lhu when "11",-- LHU
		lb when others;
		
end behavioral;