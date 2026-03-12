library IEEE;
use IEEE.std_logic_1164.all; 

entity FD_generic is
    Generic (NBIT: integer:= 32); --We define the total number of bits using the generic statement
	Port (	D_fd:	In	std_logic_vector(NBIT-1 downto 0); --The input signal and the output signal are arrays of bits
			CK_fd:	In	std_logic;
			RESET_fd:	In	std_logic;
			EN_fd: In std_logic;
			Q_fd:	Out	std_logic_vector(NBIT-1 downto 0));
end FD_generic;

architecture synch_ffd of FD_generic is -- flip flop D with syncronous reset

component FD
	Port (	D:	In	std_logic;
		CK:	In	std_logic;
		RESET:	In	std_logic;
		ENABLE: In std_logic;		
		Q:	Out	std_logic);
end component;

begin
      g2: for i in 0 to (NBIT-1) generate  --We use the generate statement to make the connections
      fd_lab_i: FD port map(D=>D_fd(i), CK=>CK_fd, RESET=>RESET_fd, ENABLE=>EN_fd, Q=>Q_fd(i));
     end generate g2;

end synch_ffd;