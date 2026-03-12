library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

entity BOOTHMUL is
	generic(N:integer:=16);
	port(A, B: in std_logic_vector(N-1 downto 0);     -- A and B are the two input operands
		 P:    out std_logic_vector(2*N-1 downto 0)); -- P is the final product, which is on 2*N bits
end BOOTHMUL;

architecture MIXED of BOOTHMUL is

	type SignalVector1 is array (N-1 downto 0) of std_logic_vector(2*N-1 downto 0); -- a matrix is needed in order to describe the overall structure: the vertical dimension is given by the number of levels of the booth multiplier structure, which is ((2*N-2) +1)
	signal tmpsignal: SignalVector1 := (others=>(others=>'0')); -- All the matrices are initialized to zero so we have not to put '0' during the shift operation.
	type SignalVector2 is array (N-1 downto 0) of std_logic_vector(2 downto 0);
	signal out_enc_sel: SignalVector2 := (others=>(others=>'0'));
    signal B_tmp: SignalVector2 := (others=>(others=>'0'));
	type SignalVector3 is array (N-1 downto 0) of std_logic_vector(2*N-1 downto 0);
	signal A_neg1, A_neg2, A_pos1,A_pos2: SignalVector3 := (others=>(others=>'0'));
	 
	signal Co_tmp: std_logic;


	component RCA_GEN
		generic(NBIT: INTEGER:= 4);
		Port(A:	 In std_logic_vector(NBIT-1 downto 0);
			 B:	 In std_logic_vector(NBIT-1 downto 0);
			 Ci: In std_logic;
			 S:	 Out std_logic_vector(NBIT-1 downto 0);
			 Co: Out std_logic);
	end component; 
	
	component encoder
		generic(N: integer:= 3);
		port(B_enc:   in std_logic_vector(N-1 downto 0);
		     out_enc: out std_logic_vector(N-1 downto 0));
	end component;	

	component MUX81_GENERIC is
		generic(N:integer:=4; NN:integer:=3);
		port(A_mux, B_mux, C_mux, D_mux, E_mux, F_mux, G_mux, H_mux: in std_logic_vector(N-1 downto 0);
			 Sel: in std_logic_vector(NN-1 downto 0);
			 Y_mux: out std_logic_vector(N-1 downto 0));
	end component;
  
  
   begin
   
	A_pos1(0)(2*N-1 downto N)<=(2*N-1 downto N=>A(N-1)); --We perform the sign extension taking into account the MSB of A
	A_pos1(0)(N-1 downto 0)<= A(N-1 downto 0); --We store, since it's the first block, A
	A_pos2(0)(2*N-1 downto N+1)<=(2*N-1 downto N+1=>A(N-1)); -- This shift is performed in order to store 2A
	A_pos2(0)(N downto 1)<= A(N-1 downto 0);
	A_neg1(0) <= std_logic_vector(unsigned(not(A_pos1(0)))+1);	--Instead of using an adder structural block we compute the two's complement in a behavioral way
	A_neg2(0)<= std_logic_vector(unsigned(not(A_pos2(0)))+1);    
	B_tmp(0)<= B(1)&B(0)&'0'; --In the first iteration we put a zero in the LSB of the encoder signal.

	 
   mux0: MUX81_GENERIC generic map(N=>2*N, NN=>3) port map(A_mux=>(others=>'0'), B_mux=>A_neg1(0), C_mux=>A_neg1(0), D_mux=> A_neg2(0), E_mux=>A_pos2(0), F_mux=>A_pos1(0), G_mux=>A_pos1(0), H_mux=>(others=>'0'), Sel=>out_enc_sel(0), Y_mux=>tmpsignal(0));
   enc0: encoder generic map(N=>3) port map(B_enc=> B_tmp(0), out_enc=>out_enc_sel(0)); 
   
    for_label: for i in 2 to N-2 generate
		if_label: if ((i mod 2) = 0) generate		--Into the generate statement we perform the same step to compute n*A, -2n*A 
													--(of course taking into account the right value for the shift and the computation of the two's complement)
		gen_enc_mux_rca: for j in 0 to 0 generate

		A_pos1(i/2)(2*N-1 downto (N-1)+i+1)<=(2*N-1 downto (N-1)+i+1=>A(N-1)); 
		A_pos1(i/2)((N-1)+i downto i)<=A(N-1 downto 0) ;
		A_pos2(i/2)(2*N-1 downto (N-1)+i+2)<=(2*N-1 downto (N-1)+i+2=>A(N-1));
		A_pos2(i/2)((N-1)+i+1 downto i+1)<=A(N-1 downto 0) ;
		A_neg1(i/2)<= std_logic_vector(unsigned(not(A_pos1(i/2)))+1);	
		A_neg2(i/2)<= std_logic_vector(unsigned(not(A_pos2(i/2)))+1);	
		B_tmp(i/2) <= B(i+1)&B(i)&B(i-1);
		 
	   mux_i: MUX81_GENERIC generic map(N=>2*N, NN=>3) port map(A_mux=>(others=>'0'), B_mux=>A_neg1(i/2), C_mux=>A_neg1(i/2), D_mux=> A_neg2(i/2), E_mux=>A_pos2(i/2), F_mux=>A_pos1(i/2), G_mux=>A_pos1(i/2), H_mux=>(others=>'0'), Sel=>out_enc_sel(i/2), Y_mux=>tmpsignal(i-1));
	   enc_i: encoder generic map(N=>3) port map(B_enc=> B_tmp(i/2), out_enc=>out_enc_sel(i/2));
	   rca_i: RCA_GEN generic map(NBIT=>2*N) port map(A=>tmpsignal(i-1), B=>tmpsignal(i-2), Ci=>'0', S=>tmpsignal(i), Co=>Co_tmp);

		end generate gen_enc_mux_rca;
		end generate if_label;	
    end generate for_label;

    P <= tmpsignal(N-2); -- The final product is stored 

end MIXED;
   