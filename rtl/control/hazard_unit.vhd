library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity hazard_unit is
 generic(
  IR_SIZE       : integer := 32;
  OPCODE_SIZE  : integer := 6;    -- Op Code Size  
  OPERAND_SIZE  : integer := 5);

 port(
   CLK    : in std_logic;
   RST    : in std_logic;

   IR_IN  : in std_logic_vector(IR_SIZE-1 downto 0);

   forward_ALU_ALU_top    : out std_logic;
   forward_ALU_ALU_down   : out std_logic;
   forward_MEM_ALU_top    : out std_logic;
   forward_MEM_ALU_down   : out std_logic;
   forward_MEM_MEM        : out std_logic;
   forward_EXE_DEC        : out std_logic
 --  stall_DEC 	  	        : out std_logic;
 --  stall_FETCH_2cc        : out std_logic;
 --  stall_FETCH            : out std_logic
 );
end hazard_unit;

architecture behav of hazard_unit is

-- signal Rtype_Rtype_top, Rtype_Itype_top, Rtype_RType_down, load_Itype_top2, Itype_Itype_top    : std_logic;
-- signal load_Rtype_top2, load_Rtype_down2, Itype_Rtype_top, Itype_RType_down, R_Itype_store_top : std_logic;
-- signal IR_IN_1, IR_IN_2, IR_IN_3 : std_logic_vector(IR_SIZE-1 downto 0);
 signal RS1, RS1_exe, RS2, RD, RD_1, RD_2, RD_3  : std_logic_vector(OPERAND_SIZE-1 downto 0);
 signal OPCODE_tmp1, OPCODE_1, OPCODE_2, OPCODE_3 : std_logic_vector(OPCODE_SIZE-1 downto 0);
-- signal stall_DEC1, stall_FETCH_2cc1, stall_FETCH1 : std_logic;

  begin

	OPCODE_1 <= IR_IN(31 downto 26);

     RS1 <= IR_IN(25 downto 21);
     RS2 <= IR_IN(20 downto 16);

 hazard_detect: PROCESS(RST, CLK)
   begin
    if RST = '1' then

--     OPCODE_1 <= (others => '0');
--	    OPCODE_2 <= (others => '0');
--     OPCODE_3 <= (others => '0');


   forward_ALU_ALU_top    <= '0';
   forward_ALU_ALU_down   <= '0';
   forward_MEM_ALU_top    <= '0';
   forward_MEM_ALU_down   <= '0';
   forward_MEM_MEM        <= '0';
   forward_EXE_DEC        <= '0';
  -- stall_DEC		        <= '0';
  -- stall_FETCH_2cc        <= '0';
  -- stall_FETCH            <= '0';


    elsif (CLK'event and CLK = '1') then

   forward_ALU_ALU_top    <= '0';
   forward_ALU_ALU_down   <= '0';
   forward_MEM_ALU_top    <= '0';
   forward_MEM_ALU_down   <= '0';
   forward_MEM_MEM        <= '0';
   forward_EXE_DEC        <= '0';
  -- stall_DEC		        <= '0';
  -- stall_FETCH_2cc        <= '0';
  -- stall_FETCH            <= '0';

   --  RS1_tmp <= IR_IN(25 downto 21);
   --  RS2_tmp <= IR_IN(20 downto 16);


     if (OPCODE_1 > "000000") then
      RD_1  <= IR_IN(20 downto 16);
     elsif (OPCODE_1 = "000000") then
	   RD_1  <= IR_IN(15 downto 11);
	 end if;

	 RS1_exe <= RS1;

	-- OPCODE_tmp2 <= OPCODE_tmp1;  -- stesso discorso per OPCODE_tmp
	-- OPCODE_1 <= OPCODE_tmp2;
  --  OPCODE_1 <= OPCODE_tmp1;   -- OPCODE_tmp1 rappresenta la fase di fetch
	 OPCODE_2 <= OPCODE_1;
	 OPCODE_3 <= OPCODE_2;

	-- RD_1 <= RD;
	 RD_2 <= RD_1;
	 RD_3 <= RD_2;


     if OPCODE_2 = "000000" then   -- se l'istruzione col destination register è R-type
       if OPCODE_1 = "000000" then -- se la nuova istruzione è R-type
         if RS1 = RD_1 then
		  forward_ALU_ALU_top <= '1';
         end if;

	    if RS2 = RD_1 then
		 forward_ALU_ALU_down <= '1';
	    end if;
      end if;
	 end if;
 -- dallo stato di EXE devo attivare il forwarding  PER IL PROSSIMO (!!!) c.c., quando sarò in MEM


-----------
	 if OPCODE_2 = "000000" then   -- se l'istruzione col destination register è R-type
      if OPCODE_1 = "001000" OR OPCODE_1 = "001010" OR OPCODE_1 = "001100" OR OPCODE_1 = "001101" OR OPCODE_1 = "001110" OR
	     OPCODE_1 = "011101" OR OPCODE_1 = "011100" OR OPCODE_1 = "010100" OR OPCODE_1 = "011001" OR OPCODE_1 = "010110" OR OPCODE_1 = "100011"
     OR OPCODE_1 = "111100" OR OPCODE_1 = "111101" OR OPCODE_1 = "011011" OR OPCODE_1 = "100000" OR OPCODE_1 = "100001" OR OPCODE_1 = "100100" OR -- da questa riga compresa sono istruz PRO
        OPCODE_1 = "100101" OR OPCODE_1 = "101000" OR OPCODE_1 = "101001" OR OPCODE_1 = "111010" OR OPCODE_1 = "001001" OR OPCODE_1 = "001011" OR 
        OPCODE_1 = "001111" OR OPCODE_1 = "011000" OR OPCODE_1 = "011010" then  -- se la nuova istruzione è I-type (o anche load/store)


	    if RS1 = RD_1 then
		 forward_ALU_ALU_top <= '1';
	    end if;
	   end if;
     end if;


-----------
    if OPCODE_2 = "001000" OR OPCODE_2 = "001010" OR OPCODE_2 = "001100" OR OPCODE_2 = "001101" OR OPCODE_2 = "001110" OR OPCODE_2 = "011101" OR
	     OPCODE_2 = "011100" OR OPCODE_2 = "010100" OR OPCODE_2 = "011001" OR OPCODE_2 = "010110" OR OPCODE_2 = "100011"
     OR OPCODE_2 = "111100" OR OPCODE_2 = "111101" OR OPCODE_2 = "011011" OR OPCODE_2 = "111010" OR OPCODE_2 = "001001" OR OPCODE_2 = "001011" OR 
        OPCODE_2 = "011000" OR OPCODE_2 = "011010" then    -- se l'istruzione col destination register è I-type (NON load/store)

	    if OPCODE_1 = "000000" then -- se la nuova istruzione è R-type

	    if RS1 = RD_1 then
		 forward_ALU_ALU_top <= '1';
        end if;

	    if RS2 = RD_1 then
		 forward_ALU_ALU_down <= '1';
	    end if;

       elsif OPCODE_1 = "001000" OR OPCODE_1 = "001010" OR OPCODE_1 = "001100" OR OPCODE_1 = "001101" OR OPCODE_1 = "001110" OR 
	          OPCODE_1 = "011101" OR OPCODE_1 = "011100" OR OPCODE_1 = "010100" OR OPCODE_1 = "011001" OR OPCODE_1 = "010110"
          OR OPCODE_1 = "111100" OR OPCODE_1 = "111101" OR OPCODE_1 = "011011" OR OPCODE_1 = "111010" OR OPCODE_1 = "001001" OR OPCODE_1 = "001011" OR 
             OPCODE_1 = "001111" OR OPCODE_1 = "011000" OR OPCODE_1 = "011010" then  -- se invece la nuova istruzione è I-type (NON load/store)
	       if RS1 = RD_1 then
		    forward_ALU_ALU_top <= '1';
           end if;
		 end if;
		end if;


------------
     if OPCODE_3 = "000000" OR OPCODE_3 = "001000" OR OPCODE_3 = "001010" OR OPCODE_3 = "001100" OR OPCODE_3 = "001101" OR OPCODE_3 = "001110" OR 
	     OPCODE_3 = "011101" OR OPCODE_3 = "011100" OR OPCODE_3 = "010100" OR OPCODE_3 = "011001" OR OPCODE_3 = "010110"
     OR OPCODE_3 = "111100" OR OPCODE_3 = "111101" OR OPCODE_3 = "011011" OR OPCODE_3 = "111010" OR OPCODE_3 = "001001" OR OPCODE_3 = "001011" OR 
        OPCODE_3 = "001111" OR OPCODE_3 = "011000" OR OPCODE_3 = "011010" then  -- se l'istruzione col destination register, nello stage MEM, è R-type o I-type (non load/store)

      if OPCODE_1 = "101011" OR OPCODE_1 = "101000" OR OPCODE_1 = "101001" then  -- se invece la nuova istruzione è una store
	    if RS1 = RD_2 then
	     forward_MEM_ALU_top <= '1';
        end if;
	  end if;
	 end if;


-----------
	  if OPCODE_3 = "001000" OR OPCODE_3 = "001010" OR OPCODE_3 = "001100" OR OPCODE_3 = "001101" OR OPCODE_3 = "001110" OR 
	     OPCODE_3 = "011101" OR OPCODE_3 = "011100" OR OPCODE_3 = "010100" OR OPCODE_3 = "011001" OR OPCODE_3 = "010110"
     OR OPCODE_3 = "111100" OR OPCODE_3 = "111101" OR OPCODE_3 = "011011" OR OPCODE_3 = "111010" OR OPCODE_3 = "001001" OR OPCODE_3 = "001011" OR 
        OPCODE_3 = "001111" OR OPCODE_3 = "011000" OR OPCODE_3 = "011010" then -- se l'istruzione nello stage MEM è I-type (non load/store)

       if OPCODE_1 = "001000" OR OPCODE_1 = "001010" OR OPCODE_1 = "001100" OR OPCODE_1 = "001101" OR OPCODE_1 = "001110" OR 
	       OPCODE_1 = "011101" OR OPCODE_1 = "011100" OR OPCODE_1 = "010100" OR OPCODE_1 = "011001" OR OPCODE_1 = "010110"
       OR OPCODE_1 = "111100" OR OPCODE_1 = "111101" OR OPCODE_1 = "011011" OR OPCODE_1 = "111010" OR OPCODE_1 = "001001" OR OPCODE_1 = "001011" OR 
          OPCODE_1 = "001111" OR OPCODE_1 = "011000" OR OPCODE_1 = "011010" then -- se anche la nuova istruzione è I-type (non load/store)

         if RS1 = RD_2 then
          forward_MEM_ALU_top <= '1';
         end if;
       end if;
     end if;


------------
	  if OPCODE_2 = "001000" OR OPCODE_2 = "001010" OR OPCODE_2 = "001100" OR OPCODE_2 = "001101" OR OPCODE_2 = "001110" OR 
	     OPCODE_2 = "011101" OR OPCODE_2 = "011100" OR OPCODE_2 = "010100" OR OPCODE_2 = "011001" OR OPCODE_2 = "010110"
     OR OPCODE_2 = "111100" OR OPCODE_2 = "111101" OR OPCODE_2 = "011011" OR OPCODE_2 = "111010" OR OPCODE_2 = "001001" OR OPCODE_2 = "001011" OR 
        OPCODE_2 = "001111" OR OPCODE_2 = "011000" OR OPCODE_2 = "011010" then -- se l'istruzione nello stage MEM è I-type (non load/store)

       if OPCODE_1 = "000000" then

         if RS1 = RD_2 then
          forward_MEM_ALU_top <= '1';
         end if;
         if RS2 = RD_2 then
          forward_MEM_ALU_down <= '1';
         end if;
       end if;
     end if;


------------
     if OPCODE_3 = "000000" then -- se l'istruzione nello stage MEM è R-type

      if OPCODE_1 = "000000" then
         if RS1 = RD_2 then
          forward_MEM_ALU_top <= '1';
         end if;
         if RS2 = RD_2 then
          forward_MEM_ALU_down <= '1';
         end if;
       end if;
     end if;


------------
     if OPCODE_3 = "000000" then

       if OPCODE_1 = "001000" OR OPCODE_1 = "001010" OR OPCODE_1 = "001100" OR OPCODE_1 = "001101" OR OPCODE_1 = "001110" OR 
	       OPCODE_1 = "011101" OR OPCODE_1 = "011100" OR OPCODE_1 = "010100" OR OPCODE_1 = "011001" OR OPCODE_1 = "010110" 
       OR OPCODE_1 = "111100" OR OPCODE_1 = "111101" OR OPCODE_1 = "011011" OR OPCODE_1 = "100000" OR OPCODE_1 = "100001" OR OPCODE_1 = "100100" OR
          OPCODE_1 = "100101" OR OPCODE_1 = "101000" OR OPCODE_1 = "101001" OR OPCODE_1 = "111010" OR OPCODE_1 = "001001" OR OPCODE_1 = "001011" OR 
          OPCODE_1 = "001111" OR OPCODE_1 = "011000" OR OPCODE_1 = "011010" then  -- se la nuova istruzione è I-type (o anche load/store)

         if RS1 = RD_2 then
          forward_MEM_ALU_top <= '1';
         end if;
       end if;
     end if;


------------
     if OPCODE_2 = "100011" OR OPCODE_2 = "100000" OR OPCODE_2 = "100001" OR OPCODE_2 = "100100" OR OPCODE_2 = "100101" OR OPCODE_2 = "001111" then  -- load nello stage MEM

      if OPCODE_1 = "000000" then

	    if RS1 = RD_2 then
	     forward_MEM_ALU_top <= '1';
        end if;

		if RS2 = RD_2 then
	     forward_MEM_ALU_down <= '1';
		end if;

       elsif OPCODE_1 = "001000" OR OPCODE_1 = "001010" OR OPCODE_1 = "001100" OR OPCODE_1 = "001101" OR OPCODE_1 = "001110" OR 
	          OPCODE_1 = "011101" OR OPCODE_1 = "011100" OR OPCODE_1 = "010100" OR OPCODE_1 = "011001" OR OPCODE_1 = "010110"
          OR OPCODE_1 = "111100" OR OPCODE_1 = "111101" OR OPCODE_1 = "011011" OR OPCODE_1 = "111010" OR OPCODE_1 = "001001" OR OPCODE_1 = "001011" OR 
             OPCODE_1 = "001111" OR OPCODE_1 = "011000" OR OPCODE_1 = "011010" then   -- se invece la nuova istruzione è I-type (non load-store)

	    if RS1 = RD_2 then
	     forward_MEM_ALU_top <= '1';
        end if;

	   elsif OPCODE_1 = "101011" OR OPCODE_1 = "101000" OR OPCODE_1 = "101001" then	 -- se l'istruzione nello stage MEM è una load e quella nello stage EXE è una store -> forwarding MEM-MEM
	    if RS1 = RD_2 then
	     forward_MEM_MEM <= '1';
       end if;
	   end if;
	  end if;


------------
	  if OPCODE_3 = "000000" OR OPCODE_3 = "001000" OR OPCODE_3 = "001010" OR OPCODE_3 = "001100" OR OPCODE_3 = "001101" OR OPCODE_3 = "001110" OR 
	     OPCODE_3 = "011101" OR OPCODE_3 = "011100" OR OPCODE_3 = "010100" OR OPCODE_3 = "011001" OR OPCODE_3 = "010110"
     OR OPCODE_3 = "111100" OR OPCODE_3 = "111101" OR OPCODE_3 = "011011" OR OPCODE_3 = "111010" OR OPCODE_3 = "001001" OR OPCODE_3 = "001011" OR 
        OPCODE_3 = "001111" OR OPCODE_3 = "011000" OR OPCODE_3 = "011010" then   -- se l'istruzione nello stage MEM è R o I-type (non load/store)
       if OPCODE_2 = "101011" OR OPCODE_2 = "101001" OR OPCODE_2 = "101000" then  -- se l'istruzione nello stage EXE è una store

        if RS1_exe = RD_2 then
	      forward_MEM_MEM <= '1';
        end if;
       end if;
      end if;


------------
     if OPCODE_2 = "000000" OR OPCODE_2 = "001000" OR OPCODE_2 = "001010" OR OPCODE_2 = "001100" OR OPCODE_2 = "001101" OR OPCODE_2 = "001110" OR 
	     OPCODE_2 = "011101" OR OPCODE_2 = "011100" OR OPCODE_2 = "010100" OR OPCODE_2 = "011001" OR OPCODE_2 = "010110"
     OR OPCODE_2 = "111100" OR OPCODE_2 = "111101" OR OPCODE_2 = "011011" OR OPCODE_2 = "111010" OR OPCODE_2 = "001001" OR OPCODE_2 = "001011" OR 
        OPCODE_2 = "001111" OR OPCODE_2 = "011000" OR OPCODE_2 = "011010" then    -- se l'istruzione col destination register in fase EXE è I-type o R-type (non load/store)
       if OPCODE_tmp1 = "000010" OR OPCODE_tmp1 = "000011" OR OPCODE_tmp1 = "000100" OR OPCODE_tmp1 = "000101" OR OPCODE_tmp1 = "010010" OR OPCODE_tmp1 = "010011" then -- se la nuova istruzione IN FASE DI FETCH è un jump o un branch

         if IR_IN(25 downto 21) = RD_1 then  -- IR_IN(25 downto 21) rappresenta l' RS1 in fase di fetch
          forward_EXE_DEC <= '1';
         end if;
       end if;
     end if;


--	end if;    -- end if clock
--  end process;


--stall_unit: process()
 --  begin
                   --   STALLS   --

------------
 --    if OPCODE_2 = "100011" OR OPCODE_2 = "100000" OR OPCODE_2 = "100001" OR OPCODE_2 = "100100" OR OPCODE_2 = "100101" OR OPCODE_2 = "001111" then   -- se l'istruzione col destination register is a load
 --     if OPCODE_1 = "000000" then  -- se la nuova istruzione è R_type
--	    if RS1 = RD_2 then
--	     stall_DEC <= '1';     -- PIÙ FORWARDING MEM-ALU AL CC SUCCESSIVO
                              -- stallo gli stage DEC e FETCH
                              -- DENTRO L'IF DELLO STALL ATTIVO IL FORWARDING MEM-ALU PER IL COLPO DI CLOCK SUCCESSIVO
  --      end if;

	--	if RS2 = RD_2 then
	--     stall_DEC <= '1';
	--	end if;

   --    elsif OPCODE_1 = "001000" OR OPCODE_1 = "001010" OR OPCODE_1 = "001100" OR OPCODE_1 = "001101" OR OPCODE_1 = "001110" OR 
	--       OPCODE_1 = "011101" OR OPCODE_1 = "011100" OR OPCODE_1 = "010100" OR OPCODE_1 = "011001" OR OPCODE_1 = "010110"
   --    OR OPCODE_1 = "111100" OR OPCODE_1 = "111101" OR OPCODE_1 = "011011" OR OPCODE_1 = "111010" OR OPCODE_1 = "001001" OR OPCODE_1 = "001011" OR 
   --       OPCODE_1 = "001111" OR OPCODE_1 = "011000" OR OPCODE_1 = "011010" then    -- se invece la nuova istruzione è I-type (non load-store)

	--    if RS1 = RD_2 then
	--     stall_DEC <= '1';
   --     end if;
   --    end if;
	--  end if;


   --  if OPCODE_1 = "100011" OR OPCODE_1 = "100000" OR OPCODE_1 = "100001" OR OPCODE_1 = "100100" OR OPCODE_1 = "100101" OR OPCODE_1 = "001111" then   -- se l'istruzione col destination register in fase DEC is a load
   --   if OPCODE_tmp1 = "000010" OR OPCODE_tmp1 = "000011" OR OPCODE_tmp1 = "000100" OR OPCODE_tmp1 = "000101" OR OPCODE_tmp1 = "010010" OR OPCODE_tmp1 = "010011" then -- se la nuova istruzione IN FASE DI FETCH è un jump o un branch
   --    if IR_IN(25 downto 21) = RD_1 then   -- IR_IN(25 downto 21) rappresenta l' RS1 in fase di fetch
	--     stall_FETCH_2cc <= '1';  -- stalla per due colpi di clock!!!  POI FORWARD MEM-DEC   (EXE-DEC!!!!!!!)
   --    end if;
   --   end if;
   --  end if;


   --  if OPCODE_1 = "000000" OR OPCODE_1 = "001000" OR OPCODE_1 = "001010" OR OPCODE_1 = "001100" OR OPCODE_1 = "001101" OR OPCODE_1 = "001110" OR 
	--     OPCODE_1 = "011101" OR OPCODE_1 = "011100" OR OPCODE_1 = "010100" OR OPCODE_1 = "011001" OR OPCODE_1 = "010110"
   --  OR OPCODE_1 = "111100" OR OPCODE_1 = "111101" OR OPCODE_1 = "011011" OR OPCODE_1 = "111010" OR OPCODE_1 = "001001" OR OPCODE_1 = "001011" OR 
   --     OPCODE_1 = "001111" OR OPCODE_1 = "011000" OR OPCODE_1 = "011010" then    -- se l'istruzione col destination register in fase DEC è I-type o R-type (non load/store)

  --    if OPCODE_tmp1 = "000010" OR OPCODE_tmp1 = "000011" OR OPCODE_tmp1 = "000100" OR OPCODE_tmp1 = "000101" OR OPCODE_tmp1 = "010010" OR OPCODE_tmp1 = "010011" then -- se la nuova istruzione IN FASE DI FETCH è un jump o un branch

  --     if IR_IN(25 downto 21) = RD_1 then   -- IR_IN(25 downto 21) rappresenta l'RS1 in fase di fetch
  --	     stall_FETCH <= '1';  -- stalla per un colpo di clock!!!  POI FORWARD MEM-DEC   (EXE-DEC!!!!!!!)
  --     end if;
  --    end if;
  --   end if;

  end if;    -- end if clock
end process;

end behav; 
