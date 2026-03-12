library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

 entity network is
  generic(N: integer:= 32; Nbit: integer:= 4);
  port(A_in, B_in: in std_logic_vector(N-1 downto 0);
       C_in: in std_logic;
	   C_out: out std_logic_vector((N/Nbit)-1 downto 0));
 end network;

 architecture STRUCTURAL of network is 
  
  	function log2 ( arg: integer ) return integer ;
	function log2 ( arg: integer )  return integer is
	variable temp    : integer := arg;
	variable result : integer := 0;
	begin

	while temp > 1 loop
	result := result + 1;
	temp    := temp / 2;
	end loop;

	return result;
	end function log2 ;
	 
  component GENERAT
  port(Gik, Gk1j: in std_logic;
       Pik: in std_logic;
       out_gen: out std_logic);  
  end component;
  
  component GP
  port(A, B: in std_logic;
       gnrat, prpgat: out std_logic);
  end component;
  
  component GENPROP
  port(Gik, Gk1j: in std_logic;
       Pik, Pk1j: in std_logic;
		 out_gen: out std_logic;
       out_prop: out std_logic); 
  end component;
  
  component GENPROP_0
  port(A, B,C_in: in std_logic;
       gnrat: out std_logic);
  end component;
  
  

  type SignalVector is array (N-1 downto 0) of std_logic_vector(N-1 downto 0);
  signal prop, gen: SignalVector; 

	 begin
 -- 3 indici servono: l'indice di riga, che si incrementa di 1 di volta in volta; gli indici i-j (del libro) che indicano "dove punta" l'uscita di un blocco e "da dove proviene" l'uscita di un blocco  
 
  rows:  for i in 0 to log2(N) generate

	row_0: if i = 0 generate
	column_0: for j in 0 to N-1 generate
	 block_g00: if j=0 generate
	  G0x: GENPROP_0 port map(A=>A_in(0), B=>B_in(0),C_in=>C_in, gnrat=>gen(i)(0));--, prpgat=>prop(i)(0));
	  end generate block_g00;
	  block_g0x: if j/=0 generate
	  G0x: GP port map(A=>A_in(j), B=>B_in(j), gnrat=>gen(j)(j), prpgat=>prop(j)(j)); 
	  end generate block_g0x;
	 end generate column_0;
	end generate row_0; 


   row_1: if i = 1 generate
     column_01: for j in 0 to (N-1) generate
		g_block_01:if j = 0 generate
	    G10: GENERAT port map(Gik=>gen(i)(j+1), Pik=>prop(i)(j+1), Gk1j=>gen(i-1)(j), out_gen=>gen(i+1)(j)); -- out=>point to the next row; same index for j (see 32/64 bit scheme)
		end generate g_block_01;
		g_block_0x:if ((j mod 2)= 0) generate
		 G1x: GENPROP port map (Gik=>gen(j+1)(j+1),Pik=>prop(j+1)(j+1),Gk1j=>gen(j)(j),Pk1j=>prop(j)(j),out_gen=>gen(j+1)(j),out_prop=>prop(j+1)(j));
		end generate g_block_0x;
	  end generate column_01;
	 end generate row_1;

 
    row_2: if i = 2 generate
     column_02: for j in 0 to (N-1) generate
		g_block_20:if j = 0 generate
	    G20: GENERAT port map(Gik=>gen(i+1)(i), Pik=>prop(i+1)(i), Gk1j=>gen(i-1)(j), out_gen=>gen(i+1)(j)); 
		end generate g_block_20;
		g_block_2x:if ((j mod 4)= 0) generate
		    G2x: GENPROP port map(Gik=>gen(j+2**i-1)(j+2), Pik=>prop(j+2**i-1)(j+2), Gk1j=>gen(j+1)(j), Pk1j=>prop(j+1)(j), out_gen=>gen(j+i+1)(j), out_prop=>prop(j+i+1)(j));
	  end generate g_block_2x;
	 end generate column_02;
    end generate row_2;	 
	 
    row_3: if (i/=0 AND i/=1 AND i/=2) generate
    
		g_blocks: for j in 0 to (2**(i-3))-1 generate
			Gi0: GENERAT port map(Gik=>gen(((8*2**(i-3)-1)-4*j))(2**(i-3)*4), Pik=>prop(((8*2**(i-3)-1)-4*j))((2**(i-3)*4)), Gk1j=>gen(2**(i-3)*4-1)(0), out_gen=>gen((8*2**(i-3)-1)-4*j)(0)); -- out=>point to the next row; same index for j (see 32/64 bit scheme)
			end generate g_blocks;
		pg_blocks: if (2**(i-3) < N/8) generate 
			pg_block_row_i: for k in 1 to ((N/8-2**(i-3))/(2**(i-3))) generate
				 pg_sub_block_row_i: for m in 0 to ((2**(i-3))-1) generate
				 PGix: GENPROP port map(Gik=>gen((k*2**i)+2**i-1-4*m)((k*2**i+2**(i-3)*4)), Pik=>prop((k*2**i)+2**i-1-4*m)((k*2**i+2**(i-3)*4)), Gk1j=>gen((k*2**i+2**(i-3)*4)-1)(k*2**i), Pk1j=>prop((k*2**i+2**(i-3)*4)-1)(k*2**i), out_gen=>gen((k*2**i)+2**i-1-4*m)(k*2**i), out_prop=>prop((k*2**i)+2**i-1-4*m)(k*2**i));
				 end generate pg_sub_block_row_i;
			end generate pg_block_row_i;
		end generate pg_blocks;
	end generate row_3;
	end generate rows;
	
	carry_out: for i in 1 to N generate
carry_store:if ((i mod 4)=0) generate
			C_out(i/Nbit-1) <= gen(i-1)(0);
		end  generate carry_store;
    end generate carry_out;
	
end STRUCTURAL;	