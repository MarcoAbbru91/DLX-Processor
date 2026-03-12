library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity DLX_CU is -- DLX Control Unit
  generic (
	 OPERAND_SIZE       :     integer := 5;
    FUNC_SIZE          :     integer := 11;   -- Func Field Size for R-Type Ops
    OPCODE_SIZE        :     integer := 6;    -- Op Code Size
    IR_SIZE            :     integer := 32;   -- Instruction Register Size
    CW_SIZE            :     integer := 33);  -- Control Word Size
  port (
    CLK                : in  std_logic;
    RST                : in  std_logic;
    IR_IN              : in std_logic_vector(IR_SIZE-1 downto 0);

   stall_DEC 	  	        : in std_logic;
   stall_FETCH_2cc        : in std_logic;
   stall_FETCH            : in std_logic;

    -- IF Control Signal
  --  IR_LATCH_EN        : out std_logic;  -- Instruction Register Latch Enable
  --  PC_LATCH_EN        : out std_logic;  -- Program Counter Latch Enable

    -- ID Control Signals
    JMP_26             : out std_logic;
    JR_JALR            : out std_logic;
    BRANCH             : out std_logic;
    FORWARD_EXE_DEC_SEL: out std_logic;
    MUX_IMM_S_U_SEL    : out std_logic;
    MUX_R31_SEL        : out std_logic;
    MUX_RS2_SEL        : out std_logic;
    MUX_RD_I_R_SEL     : out std_logic;
    RF_READ1           : out std_logic;
    RF_READ2           : out std_logic;
    RF_EN              : out std_logic;
    RegA_LATCH_EN      : out std_logic;  -- Register A Latch Enable
    RegB_LATCH_EN      : out std_logic;  -- Register B Latch Enable
    RegIMM_LATCH_EN    : out std_logic;  -- Immediate Register Latch Enable

    -- EX Control Signals
    MUXA1_SEL              : out std_logic;  -- MUX-A Sel
    FORWARD_MEM_ALU_A2_SEL : out std_logic;
	 FORWARD_ALU_ALU_A3_SEL : out std_logic;
  	 MUXB1_SEL              : out std_logic;  -- MUX-B Sel
    FORWARD_MEM_ALU_B2_SEL : out std_logic;
	 FORWARD_ALU_ALU_B3_SEL : out std_logic;
	 ALU_OPCODE1            : out std_logic;    -- ALU Operation Code
    ALU_OPCODE2            : out std_logic;
    ALU_OPCODE3            : out std_logic;
    ALU_OPCODE4            : out std_logic;
    ALU_OUTREG_EN          : out std_logic;  -- ALU Output Register Enable

    -- MEM Control Signals
    LD_SW_FORW_SEL     : out std_logic;
    DRAM_CS            : out std_logic;  -- Data RAM Write Enable
    DRAM_RD            : out std_logic;
    DRAM_WR            : out std_logic;
    LMD_LATCH_EN       : out std_logic;  -- LMD Register Latch Enable

    -- WB Control signals
    RF_WRITE           : out std_logic;  -- Register File Write Enable
    WB_MUX_SEL         : out std_logic;  -- Write Back MUX Sel
    PC_PLUS_8          : out std_logic
  );

end DLX_CU;


architecture DLX_CU_RTL of DLX_CU is

component hazard_unit
 generic(
  IR_SIZE       : integer := 32;
  OPCODE_SIZE   : integer := 6;    -- Op Code Size
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
--   stall_DEC 	  	        : out std_logic;
--   stall_FETCH_2cc        : out std_logic;
--   stall_FETCH            : out std_logic
 );
end component;

  signal forward_ALU_ALU_top    : std_logic;
  signal forward_ALU_ALU_down   : std_logic;
  signal forward_MEM_ALU_top    : std_logic;
  signal forward_MEM_ALU_down   : std_logic;
  signal forward_MEM_MEM        : std_logic;
  signal forward_EXE_DEC        : std_logic;
--  signal stall_DEC 	  	        : std_logic;
--  signal stall_FETCH_2cc        : std_logic;
  signal stall_FETCH_tmp         : std_logic;

  --signal CW_tmp : std_logic_vector(32 downto 0);
 -- signal CW_1 : std_logic_vector(32 downto 0); -- first stage
  signal CW_1 : std_logic_vector(32 downto 0); -- second stage
  signal CW_2 : std_logic_vector(18 downto 0); -- third stage
  signal CW_3 : std_logic_vector(7 downto 0);  -- fourth stage
  signal CW_4 : std_logic_vector(2 downto 0);  -- fifth stage

 -- signal cw1 : std_logic_vector(32 downto 31);
  signal cw1 : std_logic_vector(32 downto 19);
  signal cw2 : std_logic_vector(18 downto 8);
  signal cw3 : std_logic_vector(7 downto 3);
  signal cw4 : std_logic_vector(2  downto 0);

  signal Y1, Y2, Y3, Y4, Y5, Y6, Y6_tmp: std_logic;-- Y9, Y9_tmp, Y10, Y10_tmp: std_logic;

  signal IR_opcode   : std_logic_vector(OPCODE_SIZE -1 downto 0);  -- OpCode part of IR
  signal IR_func     : std_logic_vector(FUNC_SIZE - 1 downto 0);   -- Func part of IR when Rtype


  TYPE state_type is (RESET, NOP, ADD, SUB, AND_R, OR_R, XOR_R, SGE, SLE, SLL_R, SNE, SRL_R,
							 ADDI, SUBI, ANDI, ORI, XORI, SGEI, SLEI, SLLI, SNEI, SRLI, SW, LW,
							 BEQZ, BNEZ, J, JAL,  JR, JALR,
					       ADDU, SUBU, SEQ, SLT, SGT, SLTU, SGTU, SLEU, SGEU, SGTUI,
						    SLEUI, SGEUI, SGTI, MULT, MULTU, SLTUI, ADDUI, SUBUI, SEQI, LHI, SLTI,
							 LB, LH, LBU, LHU, SB, SH);

  signal CURRENT_STATE: state_type;

  begin  -- DLX_CU_RTL

   IR_opcode <= IR_IN(31 downto 26);
   IR_func   <= IR_IN(10 downto 0);

   --cw1 <= CW_1(32 downto 31);
   cw1 <= CW_1(32 downto 19);
   cw2 <= CW_2(18 downto 8);
   cw3 <= CW_3(7 downto 3);
   cw4 <= CW_4(2 downto 0);


 -- IR_LATCH_EN             <= cw1(34);
 -- PC_LATCH_EN             <= cw1(33);
  JR_JALR                 <= cw1(32);
  JMP_26                  <= cw1(31);
  BRANCH                  <= cw1(30);
  FORWARD_EXE_DEC_SEL     <= Y6; --cw1(29);
  MUX_IMM_S_U_SEL         <= cw1(28);
  MUX_R31_SEL             <= cw1(27);
  MUX_RS2_SEL             <= cw1(26);
  MUX_RD_I_R_SEL          <= cw1(25);
  RF_READ1                <= cw1(24);
  RF_READ2                <= cw1(23);
  RF_EN                   <= cw1(22);
  RegA_LATCH_EN           <= cw1(21);
  RegB_LATCH_EN           <= cw1(20);
  RegIMM_LATCH_EN         <= cw1(19);

  MUXA1_SEL               <= cw2(18);
  FORWARD_MEM_ALU_A2_SEL  <= Y1; --cw2(17);
  FORWARD_ALU_ALU_A3_SEL  <= Y2; --cw2(16);
  MUXB1_SEL               <= cw2(15);
  FORWARD_MEM_ALU_B2_SEL  <= Y3; --cw2(14);
  FORWARD_ALU_ALU_B3_SEL  <= Y4; --cw2(13);
  ALU_OPCODE1             <= cw2(12);
  ALU_OPCODE2             <= cw2(11);
  ALU_OPCODE3             <= cw2(10);
  ALU_OPCODE4             <= cw2(9);
  ALU_OUTREG_EN           <= cw2(8);

  LD_SW_FORW_SEL          <= Y5; --cw3(7);  -- LD_SW_FORW_SEL <= forward_MEM_MEM;
  DRAM_CS                 <= cw3(6);  -- Data RAM Write Enable
  DRAM_RD                 <= cw3(5);
  DRAM_WR                 <= cw3(4);
  LMD_LATCH_EN            <= cw3(3);

  RF_WRITE      	        <= cw4(2);
  WB_MUX_SEL              <= cw4(1);
  PC_PLUS_8               <= cw4(0);


  state_transition: PROCESS(RST, CLK)
   begin
    if RST = '1' then	 -- asynchronous reset

     CURRENT_STATE <= RESET;


    elsif (CLK'event and CLK = '1') then

   -- Y8 <= '1';

 --   CW_1 <= CW_tmp;
    CW_2 <= CW_1(18 downto 0);--(32 downto 0);    -- DEC
    CW_3 <= CW_2(7 downto 0);--(17 downto 0);    -- EXE
    CW_4 <= CW_3(2 downto 0);--(6 downto 0);   -- MEM
  --  CW_5 <= CW_4(1 downto 0);   -- WB


  --  stall_FETCH_tmp <= stall_FETCH; -- questo tmp mi serve solo per attivare il forwarding un colpo di clock dopo lo stall_fetch

-- se il segnale di forward è ad '1', allora Y1 viene settato ad '1' (ossia il MUXA_2 prende come input il ramo di forward), altrimenti prendi cw_3(16),
-- che di default è settato a '0' (ossia il MUXA_2 prende come input l'uscita del MUXA precedente)
  --  if stall_FETCH          = '1' then Y7 <= '0'; else Y7 <= cw2(32); end if;
  --  if stall_FETCH          = '1' then Y8 <= '0'; else Y8 <= cw2(31); end if;
    if forward_MEM_ALU_top  = '1' then Y1 <= '1'; else Y1 <= cw2(17); end if;
    if forward_ALU_ALU_top  = '1' then Y2 <= '1'; else Y2 <= cw2(16); end if;
    if forward_MEM_ALU_down = '1' then Y3 <= '0'; else Y3 <= cw2(14); end if;
    if forward_ALU_ALU_down = '1' then Y4 <= '0'; else Y4 <= cw2(13); end if;
    if forward_MEM_MEM      = '1' then Y5 <= '1'; else Y5 <= cw3(7); end if;

  --  if forward_EXE_DEC      = '1' then Y6 <= '1'; else Y6 <= cw1(29); end if;
    Y6_tmp <= stall_FETCH_2cc OR forward_EXE_DEC;
    Y6 <= Y6_tmp;
 --   if stall_FETCH = '1' then Y6 <= '1'; else Y6 <= '0'; end if;
    if stall_DEC   = '1' then Y1 <= '1'; else Y1 <= '0'; end if;
   -- if IR_opcode = "010010" then Y6 <= '1'; else Y6 <= cw1(30); end if;   -- opcode = JR
   -- if IR_opcode = "111011" OR IR_opcode = "111100" OR IR_opcode = "111101" OR IR_opcode = "111010" OR IR_opcode = "001001" OR IR_opcode = "001011"
   --    OR IR_opcode = "000001" OR IR_opcode = "100100" OR IR_opcode = "100101"
   --    OR IR_func = "00000100001" OR IR_func = "00000100011" OR IR_func = "00000111010" OR IR_func = "00000111011"
   --    OR IR_func = "00000111100" OR IR_func = "00000111101" then Y7_tmp <= '1'; else Y7_tmp <= cw2(29); end if;
   -- Y7 <= Y7_tmp; -- to have the value of the select of the mux set in the decode stage
   -- if IR_opcode = "010011" then Y8_tmp <= '1'; else Y8_tmp <= cw2(28); end if;
   -- Y8 <= Y8_tmp;
   -- if IR_opcode = "000000" then Y9_tmp <= '1'; else Y9_tmp <= cw2(27); end if;
   -- Y9 <= Y9_tmp;
   -- if IR_opcode = "000000" then Y10_tmp <= '1'; else Y10_tmp <= cw2(26); end if;
   -- Y10 <= Y10_tmp;

        case CURRENT_STATE is

			when RESET       => if IR_opcode = "000000" then
   								     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when ADD   => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when SUB   => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when AND_R => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when OR_R  => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when XOR_R => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when SGE   => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when SLE   => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when SLL_R => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when SNE   => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when SRL_R => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when NOP   => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when ADDI  => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when SUBI  => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when ANDI  => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when ORI   => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when XORI  => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when SGEI  => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when SLEI  => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when SLLI  => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when SNEI  => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when SRLI  => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when SW    => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when LW    => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when BEQZ  => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when BNEZ  => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when J     => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        when JAL   => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4 => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6 => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when ADDU       => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when SUBU       => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when SEQ  => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when SLT   => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when SGT   => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when SLTU    => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when SGTU     => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when SLEU     => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when SGEU     => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when SGTUI    => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when SLEUI       => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when SGEUI     => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when SGTI    => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when MULT     => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when MULTU     => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when SLTUI      => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when ADDUI      => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when SUBUI      => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when SEQI      => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when LB      => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when LHI     => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when SLTI      => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when JR     => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when JALR      => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when LBU      => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when LH      => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when LHU      => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;


			when SH      => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

			when SB      => if IR_opcode = "000000" then 
  									     case to_integer(unsigned(IR_func)) is
			                         when 32 => CURRENT_STATE <= ADD;
								          when 34 => CURRENT_STATE <= SUB;
									       when 36 => CURRENT_STATE <= AND_R;
									       when 37 => CURRENT_STATE <= OR_R;
									       when 38 => CURRENT_STATE <= XOR_R;
									       when 45 => CURRENT_STATE <= SGE;
									       when 44 => CURRENT_STATE <= SLE;
									       when 4  => CURRENT_STATE <= SLL_R;
									       when 41 => CURRENT_STATE <= SNE;
									       when 6  => CURRENT_STATE <= SRL_R;
										    when 33 => CURRENT_STATE <= ADDU;
										    when 35 => CURRENT_STATE <= SUBU;
										    when 40 => CURRENT_STATE <= SEQ;
											 when 42 => CURRENT_STATE <= SLT;
											 when 43 => CURRENT_STATE <= SGT;
											 when 58 => CURRENT_STATE <= SLTU;
											 when 59 => CURRENT_STATE <= SGTU;
 											 when 60 => CURRENT_STATE <= SLEU;
											 when 61 => CURRENT_STATE <= SGEU;
									       when others => CURRENT_STATE <= RESET;   -- if here, there is something wrong
									      end case;
								        end if;
									  if IR_opcode = "010101" then CURRENT_STATE <= NOP;  end if;
									  if IR_opcode = "001000" then CURRENT_STATE <= ADDI; end if;
									  if IR_opcode = "001010" then CURRENT_STATE <= SUBI; end if;
									  if IR_opcode = "001100" then CURRENT_STATE <= ANDI; end if;
									  if IR_opcode = "001101" then CURRENT_STATE <= ORI;  end if;
									  if IR_opcode = "001110" then CURRENT_STATE <= XORI; end if;
									  if IR_opcode = "011101" then CURRENT_STATE <= SGEI; end if;
									  if IR_opcode = "011100" then CURRENT_STATE <= SLEI; end if;
									  if IR_opcode = "010100" then CURRENT_STATE <= SLLI; end if;
									  if IR_opcode = "011001" then CURRENT_STATE <= SNEI; end if;
									  if IR_opcode = "010110" then CURRENT_STATE <= SRLI; end if;
									  if IR_opcode = "101011" then CURRENT_STATE <= SW;   end if;
									  if IR_opcode = "100011" then CURRENT_STATE <= LW;   end if;
									  if IR_opcode = "000100" then CURRENT_STATE <= BEQZ; end if;
									  if IR_opcode = "000101" then CURRENT_STATE <= BNEZ; end if;
									  if IR_opcode = "000010" then CURRENT_STATE <= J;    end if;
									  if IR_opcode = "000011" then CURRENT_STATE <= JAL;  end if;
									  if IR_opcode = "111011" then CURRENT_STATE <= SGTUI;  end if;
									  if IR_opcode = "111100" then CURRENT_STATE <= SLEUI;  end if;
									  if IR_opcode = "111101" then CURRENT_STATE <= SGEUI;  end if;
									  if IR_opcode = "011011" then CURRENT_STATE <= SGTI;   end if;
									  if IR_opcode = "111010" then CURRENT_STATE <= SLTUI;  end if;
									  if IR_opcode = "001001" then CURRENT_STATE <= ADDUI;  end if;
									  if IR_opcode = "001011" then CURRENT_STATE <= SUBUI;  end if;
									  if IR_opcode = "011000" then CURRENT_STATE <= SEQI;   end if;
									  if IR_opcode = "100000" then CURRENT_STATE <= LB;     end if;
									  if IR_opcode = "001111" then CURRENT_STATE <= LHI;    end if;
								     if IR_opcode = "011010" then CURRENT_STATE <= SLTI;   end if;
									  if IR_opcode = "010010" then CURRENT_STATE <= JR;     end if;
									  if IR_opcode = "010011" then CURRENT_STATE <= JALR;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULT;   end if;
									  if IR_opcode = "000001" then CURRENT_STATE <= MULTU;  end if;
									  if IR_opcode = "100100" then CURRENT_STATE <= LBU;    end if;
									  if IR_opcode = "100001" then CURRENT_STATE <= LH;     end if;
									  if IR_opcode = "100101" then CURRENT_STATE <= LHU;    end if;
									  if IR_opcode = "101001" then CURRENT_STATE <= SH;     end if;
									  if IR_opcode = "101000" then CURRENT_STATE <= SB;     end if;

        end case;
    end if;
  end process;



  state_assignments: PROCESS(CURRENT_STATE)
    begin



   case CURRENT_STATE is

    when RESET => CW_1 <= "000000110000000011100000000000000";

    when ADD   => CW_1 <= "000000111111100001110000100000100";

    when SUB   => CW_1 <= "000000111111100001110001100000100";

    when AND_R => CW_1 <= "000000111111100001110010100000100";

    when OR_R  => CW_1 <= "000000111111100001110011100000100";

    when XOR_R => CW_1 <= "000000111111100001110100100000100";

    when SGE   => CW_1 <= "000000111111100001110101100000100";

    when SLE   => CW_1 <= "000000111111100001110110100000100";

    when SLL_R => CW_1 <= "000000111111100001110111100000100";

    when SNE   => CW_1 <= "000000111111100001111000100000100";

    when SRL_R => CW_1 <= "000000111111100001111001100000100";

    when NOP   => CW_1 <= "000000000000000000110000000000000";

    when ADDI  => CW_1 <= "000000001011010000110000100000100";

    when SUBI  => CW_1 <= "000000001011010000110001100000100";

    when ANDI  => CW_1 <= "000000001011010000110010100000100";

    when ORI   => CW_1 <= "000000001011010000110011100000100";

    when XORI  => CW_1 <= "000000001011010000110100100000100";

    when SGEI  => CW_1 <= "000000001011010000110101100000100";

    when SLEI  => CW_1 <= "000000001011010000110110100000100";

    when SLLI  => CW_1 <= "000000001011010000110111100000100";

    when SNEI  => CW_1 <= "000000001011010000111000100000100";

    when SRLI  => CW_1 <= "000000001011010000111001100000100";

    when SW    => CW_1 <= "000000001111110000110000101111110";

    when LW    => CW_1 <= "000000001011010000111111111101110";

    when BEQZ  => CW_1 <= "001000001011011000110000100000000";

    when BNEZ  => CW_1 <= "000000001011011000110000100000000";

    when J     => CW_1 <= "010000000010011000110000100000000";

    when JAL   => CW_1 <= "010000000010011000110000100001001";

    when ADDU  => CW_1 <= "000010111111100001110000100000100";

    when SUBU  => CW_1 <= "000010111111100001110001100000100";

    when SEQ   => CW_1 <= "000000111111100001111100100000100";

    when SGTUI => CW_1 <= "000010001011010000111110100000100";

    when SLEUI => CW_1 <= "000010001011010000110110100000100";

    when SGEUI => CW_1 <= "000010001011010000110101100000100";

    when SGTI  => CW_1 <= "000000001011010000111110100000100";

    when MULT  => CW_1 <= "000000001111100001111011100000100";

    when MULTU => CW_1 <= "000010001111100001111011100000100";

    when SLTUI => CW_1 <= "000010001011010000111101100000100";

    when ADDUI => CW_1 <= "000010001011010000110000100000100";

    when SUBUI => CW_1 <= "000010001011010000110001100000100";

    when SEQI  => CW_1 <= "000000001011010000111100100000100";

	 when SLT   => CW_1 <= "000000111111100001111101100000100";

    when SGT   => CW_1 <= "000000111111100001111110100000100";

    when SLTU  => CW_1 <= "000010111111100001111101100000100";

    when SGTU  => CW_1 <= "000010111111100001111110100000100";

    when SLEU  => CW_1 <= "000010111111100001110110100000100";

    when SGEU  => CW_1 <= "000010111111100001110101100000100";

    when LB    => CW_1 <= "000000001011010000110000101101110";

    when LHI   => CW_1 <= "000000000010010000111111001100100";

    when SLTI  => CW_1 <= "000000001011010000111101100000100";

    when JR    => CW_1 <= "100000001010000001111111000000000";

    when JALR  => CW_1 <= "100001001010000001111111000000001";

    when LH    => CW_1 <= "000000001011010000110000111101110";

    when LBU   => CW_1 <= "000010001011010000110000101101110";

    when LHU   => CW_1 <= "000010001011010000110000101101110";

    when SB    => CW_1 <= "000000001111110000110000101111110";

    when SH    => CW_1 <= "000000001111110000110000101111110";

   end case;
  end process;

hazard: hazard_unit
 generic map(
  IR_SIZE       => 32,
  OPCODE_SIZE   => 6,
  OPERAND_SIZE  => 5)

port map(
   CLK    => CLK,
   RST    => RST,

   IR_IN  => IR_IN,

   forward_ALU_ALU_top    => forward_ALU_ALU_top,
   forward_ALU_ALU_down   => forward_ALU_ALU_down,
   forward_MEM_ALU_top    => forward_MEM_ALU_top,
   forward_MEM_ALU_down   => forward_MEM_ALU_down,
   forward_MEM_MEM        => forward_MEM_MEM,
   forward_EXE_DEC        => forward_EXE_DEC
--   stall_DEC 	  	        => stall_DEC,
--   stall_FETCH_2cc        => stall_FETCH_2cc,
--   stall_FETCH            => stall_FETCH
);

end DLX_CU_RTL;