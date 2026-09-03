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

  ----------------------------------------------------------------------------
  -- OPCODE field, IR(31 downto 26).
  -- Written as based literals so that the encoding stays readable, but kept as
  -- integers like the FUNC codes below: OPCODE_SIZE is a generic, so a
  -- std_logic_vector constant built on it would not be locally static and
  -- could not be used as a case choice.
  ----------------------------------------------------------------------------
  constant OP_RTYPE : integer := 2#000000#;  -- R-type ops, see the FUNC field
  constant OP_MUL   : integer := 2#000001#;  -- MULT and MULTU share this opcode
  constant OP_J     : integer := 2#000010#;
  constant OP_JAL   : integer := 2#000011#;
  constant OP_BEQZ  : integer := 2#000100#;
  constant OP_BNEZ  : integer := 2#000101#;
  constant OP_ADDI  : integer := 2#001000#;
  constant OP_ADDUI : integer := 2#001001#;
  constant OP_SUBI  : integer := 2#001010#;
  constant OP_SUBUI : integer := 2#001011#;
  constant OP_ANDI  : integer := 2#001100#;
  constant OP_ORI   : integer := 2#001101#;
  constant OP_XORI  : integer := 2#001110#;
  constant OP_LHI   : integer := 2#001111#;
  constant OP_JR    : integer := 2#010010#;
  constant OP_JALR  : integer := 2#010011#;
  constant OP_SLLI  : integer := 2#010100#;
  constant OP_NOP   : integer := 2#010101#;
  constant OP_SRLI  : integer := 2#010110#;
  constant OP_SEQI  : integer := 2#011000#;
  constant OP_SNEI  : integer := 2#011001#;
  constant OP_SLTI  : integer := 2#011010#;
  constant OP_SGTI  : integer := 2#011011#;
  constant OP_SLEI  : integer := 2#011100#;
  constant OP_SGEI  : integer := 2#011101#;
  constant OP_LB    : integer := 2#100000#;
  constant OP_LH    : integer := 2#100001#;
  constant OP_LW    : integer := 2#100011#;
  constant OP_LBU   : integer := 2#100100#;
  constant OP_LHU   : integer := 2#100101#;
  constant OP_SB    : integer := 2#101000#;
  constant OP_SH    : integer := 2#101001#;
  constant OP_SW    : integer := 2#101011#;
  constant OP_SLTUI : integer := 2#111010#;
  constant OP_SGTUI : integer := 2#111011#;
  constant OP_SLEUI : integer := 2#111100#;
  constant OP_SGEUI : integer := 2#111101#;

  ----------------------------------------------------------------------------
  -- FUNC field, IR(10 downto 0), meaningful only when OPCODE = OP_RTYPE
  ----------------------------------------------------------------------------
  constant FN_SLL  : integer :=  4;
  constant FN_SRL  : integer :=  6;
  constant FN_ADD  : integer := 32;
  constant FN_ADDU : integer := 33;
  constant FN_SUB  : integer := 34;
  constant FN_SUBU : integer := 35;
  constant FN_AND  : integer := 36;
  constant FN_OR   : integer := 37;
  constant FN_XOR  : integer := 38;
  constant FN_SEQ  : integer := 40;
  constant FN_SNE  : integer := 41;
  constant FN_SLT  : integer := 42;
  constant FN_SGT  : integer := 43;
  constant FN_SLE  : integer := 44;
  constant FN_SGE  : integer := 45;
  constant FN_SLTU : integer := 58;
  constant FN_SGTU : integer := 59;
  constant FN_SLEU : integer := 60;
  constant FN_SGEU : integer := 61;

  ----------------------------------------------------------------------------
  -- Decoded instruction, one entry per supported operation
  ----------------------------------------------------------------------------
  TYPE state_type is (RESET, NOP, ADD, SUB, AND_R, OR_R, XOR_R, SGE, SLE, SLL_R, SNE, SRL_R,
							 ADDI, SUBI, ANDI, ORI, XORI, SGEI, SLEI, SLLI, SNEI, SRLI, SW, LW,
							 BEQZ, BNEZ, J, JAL,  JR, JALR,
					       ADDU, SUBU, SEQ, SLT, SGT, SLTU, SGTU, SLEU, SGEU, SGTUI,
						    SLEUI, SGEUI, SGTI, MULT, MULTU, SLTUI, ADDUI, SUBUI, SEQI, LHI, SLTI,
							 LB, LH, LBU, LHU, SB, SH);

  signal CURRENT_STATE: state_type;

  ----------------------------------------------------------------------------
  -- Control Word ROM. Every word is written as the four slices that the CU
  -- shifts down the pipe, so that each field sits under the stage using it:
  --
  --   DEC (14) : JR_JALR JMP_26 BRANCH FORWARD_EXE_DEC MUX_IMM_S_U MUX_R31
  --              MUX_RS2 MUX_RD_I_R RF_READ1 RF_READ2 RF_EN RegA RegB RegIMM
  --   EXE (11) : MUXA1 FWD_MEM_ALU_A2 FWD_ALU_ALU_A3 MUXB1 FWD_MEM_ALU_B2
  --              FWD_ALU_ALU_B3 ALU_OPCODE1..4 ALU_OUTREG_EN
  --   MEM ( 5) : LD_SW_FORW DRAM_CS DRAM_RD DRAM_WR LMD_LATCH_EN
  --   WB  ( 3) : RF_WRITE WB_MUX_SEL PC_PLUS_8
  ----------------------------------------------------------------------------
  TYPE cw_rom_type is array (state_type) of std_logic_vector(CW_SIZE-1 downto 0);

  constant CW_ROM : cw_rom_type := (
    --          DEC                EXE            MEM       WB
    RESET => "00000011000000" & "00111000000" & "00000" & "000",
    NOP   => "00000000000000" & "00001100000" & "00000" & "000",

    -- R-type, register-register ALU ops
    ADD   => "00000011111110" & "00011100001" & "00000" & "100",
    ADDU  => "00001011111110" & "00011100001" & "00000" & "100",
    SUB   => "00000011111110" & "00011100011" & "00000" & "100",
    SUBU  => "00001011111110" & "00011100011" & "00000" & "100",
    AND_R => "00000011111110" & "00011100101" & "00000" & "100",
    OR_R  => "00000011111110" & "00011100111" & "00000" & "100",
    XOR_R => "00000011111110" & "00011101001" & "00000" & "100",
    SGE   => "00000011111110" & "00011101011" & "00000" & "100",
    SGEU  => "00001011111110" & "00011101011" & "00000" & "100",
    SLE   => "00000011111110" & "00011101101" & "00000" & "100",
    SLEU  => "00001011111110" & "00011101101" & "00000" & "100",
    SLL_R => "00000011111110" & "00011101111" & "00000" & "100",
    SNE   => "00000011111110" & "00011110001" & "00000" & "100",
    SRL_R => "00000011111110" & "00011110011" & "00000" & "100",
    SEQ   => "00000011111110" & "00011111001" & "00000" & "100",
    SLT   => "00000011111110" & "00011111011" & "00000" & "100",
    SLTU  => "00001011111110" & "00011111011" & "00000" & "100",
    SGT   => "00000011111110" & "00011111101" & "00000" & "100",
    SGTU  => "00001011111110" & "00011111101" & "00000" & "100",
    MULT  => "00000000111110" & "00011110111" & "00000" & "100",
    MULTU => "00001000111110" & "00011110111" & "00000" & "100",

    -- I-type, register-immediate ALU ops
    ADDI  => "00000000101101" & "00001100001" & "00000" & "100",
    ADDUI => "00001000101101" & "00001100001" & "00000" & "100",
    SUBI  => "00000000101101" & "00001100011" & "00000" & "100",
    SUBUI => "00001000101101" & "00001100011" & "00000" & "100",
    ANDI  => "00000000101101" & "00001100101" & "00000" & "100",
    ORI   => "00000000101101" & "00001100111" & "00000" & "100",
    XORI  => "00000000101101" & "00001101001" & "00000" & "100",
    SGEI  => "00000000101101" & "00001101011" & "00000" & "100",
    SGEUI => "00001000101101" & "00001101011" & "00000" & "100",
    SLEI  => "00000000101101" & "00001101101" & "00000" & "100",
    SLEUI => "00001000101101" & "00001101101" & "00000" & "100",
    SLLI  => "00000000101101" & "00001101111" & "00000" & "100",
    SNEI  => "00000000101101" & "00001110001" & "00000" & "100",
    SRLI  => "00000000101101" & "00001110011" & "00000" & "100",
    SEQI  => "00000000101101" & "00001111001" & "00000" & "100",
    SLTI  => "00000000101101" & "00001111011" & "00000" & "100",
    SLTUI => "00001000101101" & "00001111011" & "00000" & "100",
    SGTI  => "00000000101101" & "00001111101" & "00000" & "100",
    SGTUI => "00001000101101" & "00001111101" & "00000" & "100",
    LHI   => "00000000001001" & "00001111110" & "01100" & "100",

    -- Loads and stores
    LB    => "00000000101101" & "00001100001" & "01101" & "110",
    LBU   => "00001000101101" & "00001100001" & "01101" & "110",
    LH    => "00000000101101" & "00001100001" & "11101" & "110",
    LHU   => "00001000101101" & "00001100001" & "01101" & "110",
    LW    => "00000000101101" & "00001111111" & "11101" & "110",
    SB    => "00000000111111" & "00001100001" & "01111" & "110",
    SH    => "00000000111111" & "00001100001" & "01111" & "110",
    SW    => "00000000111111" & "00001100001" & "01111" & "110",

    -- Branches and jumps
    BEQZ  => "00100000101101" & "10001100001" & "00000" & "000",
    BNEZ  => "00000000101101" & "10001100001" & "00000" & "000",
    J     => "01000000001001" & "10001100001" & "00000" & "000",
    JAL   => "01000000001001" & "10001100001" & "00001" & "001",
    JR    => "10000000101000" & "00011111110" & "00000" & "000",
    JALR  => "10000100101000" & "00011111110" & "00000" & "001"
  );

  signal forward_ALU_ALU_top    : std_logic;
  signal forward_ALU_ALU_down   : std_logic;
  signal forward_MEM_ALU_top    : std_logic;
  signal forward_MEM_ALU_down   : std_logic;
  signal forward_MEM_MEM        : std_logic;
  signal forward_EXE_DEC        : std_logic;

  signal CW_1 : std_logic_vector(CW_SIZE-1 downto 0); -- second stage, straight out of the ROM
  signal CW_2 : std_logic_vector(18 downto 0);        -- third stage
  signal CW_3 : std_logic_vector(7 downto 0);         -- fourth stage
  signal CW_4 : std_logic_vector(2 downto 0);         -- fifth stage

  signal cw1 : std_logic_vector(32 downto 19);
  signal cw2 : std_logic_vector(18 downto 8);
  signal cw3 : std_logic_vector(7 downto 3);
  signal cw4 : std_logic_vector(2  downto 0);

  signal Y1, Y2, Y3, Y4, Y5, Y6, Y6_tmp: std_logic;

  signal IR_opcode   : std_logic_vector(OPCODE_SIZE -1 downto 0);  -- OpCode part of IR
  signal IR_func     : std_logic_vector(FUNC_SIZE - 1 downto 0);   -- Func part of IR when Rtype

  begin  -- DLX_CU_RTL

   IR_opcode <= IR_IN(31 downto 26);
   IR_func   <= IR_IN(10 downto 0);

   CW_1 <= CW_ROM(CURRENT_STATE);

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

    CW_2 <= CW_1(18 downto 0);    -- DEC
    CW_3 <= CW_2(7 downto 0);     -- EXE
    CW_4 <= CW_3(2 downto 0);     -- MEM

-- se il segnale di forward è ad '1', allora Y1 viene settato ad '1' (ossia il MUXA_2 prende come input il ramo di forward), altrimenti prendi cw_3(16),
-- che di default è settato a '0' (ossia il MUXA_2 prende come input l'uscita del MUXA precedente)
    if forward_MEM_ALU_top  = '1' then Y1 <= '1'; else Y1 <= cw2(17); end if;
    if forward_ALU_ALU_top  = '1' then Y2 <= '1'; else Y2 <= cw2(16); end if;
    if forward_MEM_ALU_down = '1' then Y3 <= '0'; else Y3 <= cw2(14); end if;
    if forward_ALU_ALU_down = '1' then Y4 <= '0'; else Y4 <= cw2(13); end if;
    if forward_MEM_MEM      = '1' then Y5 <= '1'; else Y5 <= cw3(7); end if;

    Y6_tmp <= stall_FETCH_2cc OR forward_EXE_DEC;
    Y6 <= Y6_tmp;

-- ATTENZIONE: questa assegnazione viene dopo quella su forward_MEM_ALU_top, quindi vince lei e
-- Y1 di fatto segue solo stall_DEC. Comportamento lasciato identico all'originale: da rivedere
-- insieme al forwarding MEM->ALU sull'operando alto.
    if stall_DEC   = '1' then Y1 <= '1'; else Y1 <= '0'; end if;

-- l'istruzione decodificata dipende solo da IR: l'opcode e, per le R-type, il campo func.
-- Non c'è nessuna dipendenza dallo stato corrente, quindi basta un solo decode.
        case to_integer(unsigned(IR_opcode)) is

          when OP_RTYPE =>
            case to_integer(unsigned(IR_func)) is
             when FN_ADD  => CURRENT_STATE <= ADD;
             when FN_ADDU => CURRENT_STATE <= ADDU;
             when FN_SUB  => CURRENT_STATE <= SUB;
             when FN_SUBU => CURRENT_STATE <= SUBU;
             when FN_AND  => CURRENT_STATE <= AND_R;
             when FN_OR   => CURRENT_STATE <= OR_R;
             when FN_XOR  => CURRENT_STATE <= XOR_R;
             when FN_SLL  => CURRENT_STATE <= SLL_R;
             when FN_SRL  => CURRENT_STATE <= SRL_R;
             when FN_SEQ  => CURRENT_STATE <= SEQ;
             when FN_SNE  => CURRENT_STATE <= SNE;
             when FN_SLT  => CURRENT_STATE <= SLT;
             when FN_SGT  => CURRENT_STATE <= SGT;
             when FN_SLE  => CURRENT_STATE <= SLE;
             when FN_SGE  => CURRENT_STATE <= SGE;
             when FN_SLTU => CURRENT_STATE <= SLTU;
             when FN_SGTU => CURRENT_STATE <= SGTU;
             when FN_SLEU => CURRENT_STATE <= SLEU;
             when FN_SGEU => CURRENT_STATE <= SGEU;
             when others  => CURRENT_STATE <= RESET;   -- if here, there is something wrong
            end case;

          -- MULT e MULTU condividono l'opcode: come nell'originale si decodifica MULTU
          when OP_MUL   => CURRENT_STATE <= MULTU;

          when OP_ADDI  => CURRENT_STATE <= ADDI;
          when OP_ADDUI => CURRENT_STATE <= ADDUI;
          when OP_SUBI  => CURRENT_STATE <= SUBI;
          when OP_SUBUI => CURRENT_STATE <= SUBUI;
          when OP_ANDI  => CURRENT_STATE <= ANDI;
          when OP_ORI   => CURRENT_STATE <= ORI;
          when OP_XORI  => CURRENT_STATE <= XORI;
          when OP_SLLI  => CURRENT_STATE <= SLLI;
          when OP_SRLI  => CURRENT_STATE <= SRLI;
          when OP_SEQI  => CURRENT_STATE <= SEQI;
          when OP_SNEI  => CURRENT_STATE <= SNEI;
          when OP_SLTI  => CURRENT_STATE <= SLTI;
          when OP_SGTI  => CURRENT_STATE <= SGTI;
          when OP_SLEI  => CURRENT_STATE <= SLEI;
          when OP_SGEI  => CURRENT_STATE <= SGEI;
          when OP_SLTUI => CURRENT_STATE <= SLTUI;
          when OP_SGTUI => CURRENT_STATE <= SGTUI;
          when OP_SLEUI => CURRENT_STATE <= SLEUI;
          when OP_SGEUI => CURRENT_STATE <= SGEUI;
          when OP_LHI   => CURRENT_STATE <= LHI;

          when OP_LB    => CURRENT_STATE <= LB;
          when OP_LBU   => CURRENT_STATE <= LBU;
          when OP_LH    => CURRENT_STATE <= LH;
          when OP_LHU   => CURRENT_STATE <= LHU;
          when OP_LW    => CURRENT_STATE <= LW;
          when OP_SB    => CURRENT_STATE <= SB;
          when OP_SH    => CURRENT_STATE <= SH;
          when OP_SW    => CURRENT_STATE <= SW;

          when OP_BEQZ  => CURRENT_STATE <= BEQZ;
          when OP_BNEZ  => CURRENT_STATE <= BNEZ;
          when OP_J     => CURRENT_STATE <= J;
          when OP_JAL   => CURRENT_STATE <= JAL;
          when OP_JR    => CURRENT_STATE <= JR;
          when OP_JALR  => CURRENT_STATE <= JALR;

          when OP_NOP   => CURRENT_STATE <= NOP;

          when others   => null;   -- opcode non riconosciuto: si tiene lo stato corrente

        end case;

    end if;
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
