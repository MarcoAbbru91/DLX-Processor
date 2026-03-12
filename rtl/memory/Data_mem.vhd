library IEEE;
use IEEE.std_logic_1164.all;
--use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity Data_mem is
	generic (N: integer := 32; M: integer := 64); --N=64;M=32 is the number of register
	 port (CLK: 		IN std_logic;
			 RESET: 	IN std_logic;
			 CS: 	IN std_logic;
			 RD: 		IN std_logic;
			 WR: 		IN std_logic;
			 ADD: 	IN std_logic_vector(N-1 downto 0);
			 DATAIN: 	IN std_logic_vector(N-1 downto 0);
			 OUT1: 		OUT std_logic_vector(N-1 downto 0));
end Data_mem;

architecture BEHAVIOR of Data_mem is

        -- suggested structures
        subtype REG_ADDR is integer range 0 to M-1; -- using natural type
		type REG_ARRAY is array(REG_ADDR) of std_logic_vector(N-1 downto 0);
		signal REGISTERS : REG_ARRAY;
     
      signal new_addr : std_logic_vector(5 downto 0);

begin 
	  REG: process(CLK,RESET, CS)
		   begin

		new_addr <= ADD(5 downto 0);

				if RESET='1' then
					for i in 0 to M-1 loop
						REGISTERS(i)<=std_logic_vector(to_unsigned((i), N));
					end loop;
					OUT1 <= (others=>'0');
				elsif CLK'event and CLK = '1' then
					if CS = '1' then
						if WR = '1' then
							REGISTERS(to_integer(unsigned(new_addr))) <= DATAIN;
						end if;
					end if;
				elsif CS = '1' then 
					if RD = '1' then 
						OUT1 <= REGISTERS(to_integer(unsigned(new_addr)));
					end if;
				end if;
		end process;
end BEHAVIOR;