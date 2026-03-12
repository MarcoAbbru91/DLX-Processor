library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity stall_unit is
 generic(
  IR_SIZE       : integer := 32;
  OPCODE_SIZE   : integer := 6;    -- Op Code Size
  OPERAND_SIZE  : integer := 5);

 port(
   CLK    : in std_logic;
   RST    : in std_logic;

   IR_IN  : in std_logic_vector(IR_SIZE-1 downto 0);

   stall_DEC 	  	        : out std_logic;
   stall_FETCH_2cc        : out std_logic;
   stall_FETCH            : out std_logic
 );
end stall_unit;

architecture behavior of stall_unit is

 signal RS1, RS2, RD_2, RD_3  : std_logic_vector(OPERAND_SIZE-1 downto 0);
 signal OPCODE_1, OPCODE_2, OPCODE_3 : std_logic_vector(OPCODE_SIZE-1 downto 0);
 signal stall_2cc_fetch : std_logic;

  begin

	OPCODE_1 <= IR_IN(31 downto 26);

  -- stall_2cc_fetch <= stall_FETCH_2cc;

 update: PROCESS(RST, CLK)
   begin


   if (CLK'event and CLK = '1') then

     if (OPCODE_1 > "000000") then
      RD_2  <= IR_IN(20 downto 16);
     elsif (OPCODE_1 = "000000") then
	   RD_2  <= IR_IN(15 downto 11);
	 end if;

	 RD_3 <= RD_2;

   RS1 <= IR_IN(25 downto 21);
   RS2 <= IR_IN(20 downto 16);

   -- OPCODE_1 <= OPCODE_tmp1;   -- OPCODE_tmp1 rappresenta la fase di fetch
	 OPCODE_2 <= OPCODE_1;
    OPCODE_3 <= OPCODE_2;

  end if;    -- end if clock
end process;

stall_detect: process(RST, IR_IN, OPCODE_1, OPCODE_2, OPCODE_3, RS1, RS2, RD_2, RD_3)

  begin

    if RST = '1' then

   stall_DEC		        <= '0';
   stall_FETCH_2cc        <= '0';
   stall_FETCH            <= '0';

  -- elsif (CLK'event and CLK = '1') then
   else

--  ORA CHE E' ASINCRONO IL PROCESSO E' COME SE OPCODE_2 RAPPRESENTASSE LA FASE DI FETCH (E QUINDI ANCHE DEC), E OPCODE_1 L'ISTRANTE IN CUI E' APPENA USCITO DALL'IRAM, QUINDI COME SE NON FOSSE ANCORA STATO FETCHATO

     if OPCODE_3 = "111111" then  -- queste tre righe sono inutili, ma sono necessarie perchè il primo "if statement" dopo l'else del reset non lo legge
      stall_FETCH <= '1';
     end if;


 --    if stall_2cc_fetch = '1' then
 --      stall_FETCH <= stall_2cc_fetch;--'1';             -- perchè in questo modo riesco a stallare per due cc
 --   end if;


     if OPCODE_3 = "100011" OR OPCODE_3 = "100000" OR OPCODE_3 = "100001" OR OPCODE_3 = "100100" OR OPCODE_3 = "100101" OR OPCODE_3 = "001111" then   -- se la nuova istruzione col destination register is a load
  -- USO OPCODE_2 CHE RAPPRESENTA LA FASE DI FETCH/DEC ORA CHE E' ASINCRONO
      if OPCODE_2 = "000000" then  -- se la nuova istruzione è R_type
	    if RS1 = RD_3 then
	     stall_DEC <= '1';     -- PIÙ FORWARDING MEM-ALU AL CC SUCCESSIVO
        stall_FETCH <= '1';   -- stallo gli stage DEC e FETCH
                              -- DENTRO L'IF DELLO STALL ATTIVO IL FORWARDING MEM-ALU PER IL COLPO DI CLOCK SUCCESSIVO
        end if;

		if RS2 = RD_3 then
	     stall_DEC <= '1';
        stall_FETCH <= '1';
		end if;


    elsif OPCODE_2 = "001000" OR OPCODE_2 = "001010" OR OPCODE_2 = "001100" OR OPCODE_2 = "001101" OR OPCODE_2 = "001110" OR 
	       OPCODE_2 = "011101" OR OPCODE_2 = "011100" OR OPCODE_2 = "010100" OR OPCODE_2 = "011001" OR OPCODE_2 = "010110"
       OR OPCODE_2 = "111100" OR OPCODE_2 = "111101" OR OPCODE_2 = "011011" OR OPCODE_2 = "111010" OR OPCODE_2 = "001001" OR OPCODE_2 = "001011" OR 
          OPCODE_2 = "001111" OR OPCODE_2 = "011000" OR OPCODE_2 = "011010" then    -- se invece la nuova istruzione è I-type (non load-store)

	    if RS1 = RD_3 then
	     stall_DEC <= '1';
        stall_FETCH <= '1';

        end if;
       end if;
       else stall_DEC <= '0';
        stall_FETCH <= '0';
	  end if;


     if OPCODE_2 = "100011" OR OPCODE_2 = "100000" OR OPCODE_2 = "100001" OR OPCODE_2 = "100100" OR OPCODE_2 = "100101" OR OPCODE_2 = "001111" then   -- se l'istruzione col destination register in fase EXE is a load.. perchè la dec è nello stesso stato della fetch!!!
  -- PERO' USO OPCODE_2 CHE RAPPRESENTA LA FASE DI FETCH/DEC ORA CHE E' ASINCRONO
      if OPCODE_1 = "000010" OR OPCODE_1 = "000011" OR OPCODE_1 = "000100" OR OPCODE_1 = "000101" OR OPCODE_1 = "010010" OR OPCODE_1 = "010011" then -- se la nuova istruzione IN FASE DI FETCH è un jump o un branch
       if IR_IN(25 downto 21) = RD_2 then   -- IR_IN(25 downto 21) rappresenta l' RS1 in fase di fetch
	     stall_2cc_fetch <= '1';  -- stalla per due colpi di clock!!!  POI FORWARD MEM-DEC   (EXE-DEC!!!!!!!)
        stall_FETCH <= '1';
       end if;
      end if;

	   else stall_2cc_fetch <= '0';
           stall_FETCH <= '0';
     end if;


--    if OPCODE_1 = "000001"  AND OPCODE_2 /= "000001" then-- OR OPCODE_1 = "000011" OR OPCODE_1 = "010010" OR OPCODE_1 = "010011" then --
     --stall, if the istruction is a mult/multu, the instruction in the decode stage
	   --  stall_FETCH_2cc <= '1';  -- stalla per un colpo di clock!!!
--        stall_FETCH <= '1';
--        stall_2cc_fetch <= '1';
--      else stall_FETCH <= '0';
           -- stall_FETCH_2cc <= '0';
--            stall_2cc_fetch <= '0';
--       end if;






--    elsif OPCODE_2 = "000000" OR OPCODE_2 = "001000" OR OPCODE_2 = "001010" OR OPCODE_2 = "001100" OR OPCODE_2 = "001101" OR OPCODE_2 = "001110" OR 
--	     OPCODE_2 = "011101" OR OPCODE_2 = "011100" OR OPCODE_2 = "010100" OR OPCODE_2 = "011001" OR OPCODE_2 = "010110"
--     OR OPCODE_2 = "111100" OR OPCODE_2 = "111101" OR OPCODE_2 = "011011" OR OPCODE_2 = "111010" OR OPCODE_2 = "001001" OR OPCODE_2 = "001011" OR 
--        OPCODE_2 = "001111" OR OPCODE_2 = "011000" OR OPCODE_2 = "011010" then    -- se l'istruzione col destination register in fase EXE è I-type o R-type (non load/store).. perchè la dec è nello stesso stato della fetch!!
--     if OPCODE_1 = "000100" OR OPCODE_1 = "000101" then -- se la nuova istruzione IN FASE DI FETCH/DEC è un jump o un branch

--       if IR_IN(25 downto 21) = RD_2 then   -- IR_IN(25 downto 21) rappresenta l'RS1 in fase di fetch
	    -- stall_FETCH_2cc <= '1';  -- stalla per un colpo di clock!!!  POI FORWARD MEM-DEC   (EXE-DEC!!!!!!!)
--        stall_FETCH <= '1';
      --  stall_2cc_fetch <= '1';
--       end if;
--      end if;


    if OPCODE_1 = "000001"  AND OPCODE_2 /= "000001" then-- OR OPCODE_1 = "000011" OR OPCODE_1 = "010010" OR OPCODE_1 = "010011" then --
     --stall, if the istruction is a mult/multu, the instruction in the decode stage
	   --  stall_FETCH_2cc <= '1';  -- stalla per un colpo di clock!!!
        stall_FETCH <= '1';
        stall_2cc_fetch <= '1';


     else   --stall_FETCH_2cc <= '0';
            stall_FETCH <= '0';
            stall_2cc_fetch <= '0';
      --  stall_FETCH_2cc <= '0';
     end if;



     if OPCODE_2 = "000000" OR OPCODE_2 = "001000" OR OPCODE_2 = "001010" OR OPCODE_2 = "001100" OR OPCODE_2 = "001101" OR OPCODE_2 = "001110" OR 
	     OPCODE_2 = "011101" OR OPCODE_2 = "011100" OR OPCODE_2 = "010100" OR OPCODE_2 = "011001" OR OPCODE_2 = "010110"
     OR OPCODE_2 = "111100" OR OPCODE_2 = "111101" OR OPCODE_2 = "011011" OR OPCODE_2 = "111010" OR OPCODE_2 = "001001" OR OPCODE_2 = "001011" OR 
        OPCODE_2 = "001111" OR OPCODE_2 = "011000" OR OPCODE_2 = "011010" then    -- se l'istruzione col destination register in fase EXE è I-type o R-type (non load/store).. perchè la dec è nello stesso stato della fetch!!
  -- PERO' USO OPCODE_2 CHE RAPPRESENTA LA FASE DI FETCH/DEC ORA CHE E' ASINCRONO
      if OPCODE_1 = "000010" OR OPCODE_1 = "000011" OR OPCODE_1 = "010010" OR OPCODE_1 = "010011" OR OPCODE_1 = "000100" OR OPCODE_1 = "000101" then -- se la nuova istruzione IN FASE DI FETCH/DEC è un jump o un branch

       if IR_IN(25 downto 21) = RD_2 then   -- IR_IN(25 downto 21) rappresenta l'RS1 in fase di fetch
	    -- stall_FETCH_2cc <= '1';  -- stalla per un colpo di clock!!!  POI FORWARD MEM-DEC   (EXE-DEC!!!!!!!)
        stall_FETCH <= '1';
        stall_2cc_fetch <= '1';
        stall_FETCH_2cc <= '1';
       end if;
      end if;


  --  elsif OPCODE_1 = "000001"  AND OPCODE_2 /= "000001" then-- OR OPCODE_1 = "000011" OR OPCODE_1 = "010010" OR OPCODE_1 = "010011" then --
     --stall, if the istruction is a mult/multu, the instruction in the decode stage
	   --  stall_FETCH_2cc <= '1';  -- stalla per un colpo di clock!!!
  --      stall_FETCH <= '1';
  --      stall_2cc_fetch <= '1';


     else   --stall_FETCH_2cc <= '0';
            stall_FETCH <= '0';
            stall_2cc_fetch <= '0';
        stall_FETCH_2cc <= '0';
     end if;


     if stall_2cc_fetch = '1' then
       stall_FETCH <= stall_2cc_fetch;--'1';             -- perchè in questo modo riesco a stallare per due cc
    end if;

 end if;
end process;

end behavior;