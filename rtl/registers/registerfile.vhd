library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity register_file is
	generic (N: integer:= 32;M:integer:=32; MM:integer:=5); --N=64;M=32 is the number of register;MM=log2 of the register number
	 port (  CLK: 		IN std_logic;
			 RESET: 	IN std_logic;
			 ENABLE: 	IN std_logic;
			 RD1: 		IN std_logic;
			 RD2: 		IN std_logic;
			 WR: 		IN std_logic;
			 ADD_WR: 	IN std_logic_vector(MM-1 downto 0);
			 ADD_RD1: 	IN std_logic_vector(MM-1 downto 0);
			 ADD_RD2: 	IN std_logic_vector(MM-1 downto 0);
			 DATAIN: 	IN std_logic_vector(N-1 downto 0);
			 OUT1: 		OUT std_logic_vector(N-1 downto 0);
			 OUT2: 		OUT std_logic_vector(N-1 downto 0));
end register_file;

architecture BEHAVIOR of register_file is

        -- suggested structures
        subtype REG_ADDR is natural range 0 to M-1; -- using natural type
		type REG_ARRAY is array(REG_ADDR) of std_logic_vector(N-1 downto 0);
		signal REGISTERS : REG_ARRAY;


begin 
	  WRITE: process(CLK,RESET)
	   begin
				if RESET='1' then
					for i in 0 to M-1 loop
							REGISTERS(i)<=std_logic_vector(to_unsigned((i), M));
					end loop;
					OUT1 <= (others=>'0');
					OUT2 <= (others=>'0');
				elsif CLK'event and CLK = '1' then
					if ENABLE='1' then
						if WR='1' then
							REGISTERS(to_integer(unsigned(ADD_WR))) <= DATAIN;
						end if;
					end if;
            end if;
 
  end process;
     READ: process(RD1, RD2, ADD_RD1, ADD_RD2)
     begin
				if ENABLE = '1' then 
					if RD1='1' then 
						OUT1 <= REGISTERS(to_integer(unsigned(ADD_RD1)));
					end if;
					if RD2='1' then 
						OUT2 <= REGISTERS(to_integer(unsigned(ADD_RD2)));
					end if;
				end if;
		end process;
end BEHAVIOR;