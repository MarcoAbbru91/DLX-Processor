library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity MUX81_GENERIC is
	generic(N:integer:=16; NN:integer:=3);
	port(A_mux,B_mux,C_mux,D_mux,E_mux,F_mux,G_mux,H_mux:in std_logic_vector(N-1 downto 0);
		 Sel: in std_logic_vector(NN-1 downto 0);
		 Y_mux: out std_logic_vector(N-1 downto 0));
end MUX81_GENERIC;

architecture STRUCTURAL of MUX81_GENERIC is -- generic multiplexer based on the basic mux21 block, which in turn was described in a behavioral way (if condition)
	
	type SignalVector is array (5 downto 0) of std_logic_vector(N-1 downto 0); 	
	signal tmpsignal: SignalVector;											   --000=H_mux
																			   --001=G_mux
	component MUX21_GENERIC is												   --010=F_mux
		generic (NBIT: integer:= 16);									   --011=E_mux
																			   --100=D_mux
		port (	A_mux:	In	std_logic_vector(NBIT-1 downto 0) ;				   --101=C_mux
				B_mux:	In	std_logic_vector(NBIT-1 downto 0);                 --110=B_mux
				SEL_mux:	In	std_logic;									   --111=A_mux
				Y_mux:	Out	std_logic_vector(NBIT-1 downto 0));
	end component;

	begin

		MUX_0: MUX21_GENERIC generic map(NBIT=>N) port map(A_mux=>A_mux,B_mux=>B_mux,SEL_mux=>Sel(0),Y_mux=>tmpsignal(0));
		MUX_1: MUX21_GENERIC generic map(NBIT=>N) port map(A_mux=>C_mux,B_mux=>D_mux,SEL_mux=>Sel(0),Y_mux=>tmpsignal(1));
		MUX_2: MUX21_GENERIC generic map(NBIT=>N) port map(A_mux=>E_mux,B_mux=>F_mux,SEL_mux=>Sel(0),Y_mux=>tmpsignal(2));
		MUX_3: MUX21_GENERIC generic map(NBIT=>N) port map(A_mux=>G_mux,B_mux=>H_mux,SEL_mux=>Sel(0),Y_mux=>tmpsignal(3));
		MUX_4: MUX21_GENERIC generic map(NBIT=>N) port map(A_mux=>tmpsignal(0),B_mux=>tmpsignal(1),SEL_mux=>Sel(1),Y_mux=>tmpsignal(4));
		MUX_5: MUX21_GENERIC generic map(NBIT=>N) port map(A_mux=>tmpsignal(2),B_mux=>tmpsignal(3),SEL_mux=>Sel(1),Y_mux=>tmpsignal(5));
		MUX_6: MUX21_GENERIC generic map(NBIT=>N) port map(A_mux=>tmpsignal(4),B_mux=>tmpsignal(5),SEL_mux=>Sel(2),Y_mux=>Y_mux);
		
			
end STRUCTURAL;
