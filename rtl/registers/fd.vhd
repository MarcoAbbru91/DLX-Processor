library IEEE;
use IEEE.std_logic_1164.all; 

entity FD is
	Port (	D:	In	std_logic;
		CK:	In	std_logic;
		RESET:	In	std_logic;
		ENABLE: In std_logic;
		Q:	Out	std_logic);
end FD;


architecture behav of FD is -- flip flop D with synchronous reset. In the following description the reset is synchronous
begin						--because we check its value during the positive edge of the clock signal(within the statement
	PSYNCH: process(CK,RESET)	--of the clock)
	begin
	    if RESET = '1' then -- active high reset 
	      Q <= '0'; 
	  elsif CK = '1' then -- positive edge triggered:  CK'event and 
		 if ENABLE = '1' then
	      Q <= D; -- input is written on output
		 end if; 
	    end if;
	end process;

end behav;