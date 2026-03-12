library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;


entity Data_Path is
 generic(
   FUNC_SIZE          :     integer := 11;  -- Func Field Size for R-Type Ops
	OPERAND_SIZE       :     integer := 5;
   OPCODE_SIZE        :     integer := 6;   -- Op Code Size
	IR_SIZE            :     integer := 32;
	MM                 :     integer := 5;
	CW_SIZE            :     integer := 33
 );

  port( CLK : in  std_logic;
        RST : in  std_logic;
    IR_OUT  : out std_logic_vector(IR_SIZE-1 downto 0);

	--	IR_IN  : in std_logic_vector(IR_SIZE-1 downto 0);

  --  IR_LATCH_EN        : in std_logic;  -- Instruction Register Latch Enable
  --  PC_LATCH_EN        : in std_logic;  -- Program Counter Latch Enable

    output_from_PC     : out std_logic_vector(IR_SIZE-1 downto 0);
    input_for_IR       : in std_logic_vector(IR_SIZE-1 downto 0);

    output_from_mem     : out std_logic_vector(IR_SIZE-1 downto 0);
    input_for_mem       : in std_logic_vector(IR_SIZE-1 downto 0);

    -- ID Control Signals
    JMP_26             : in std_logic;
    JR_JALR            : in std_logic;
    BRANCH             : in std_logic;
    FORWARD_EXE_DEC_SEL: in std_logic;
    MUX_IMM_S_U_SEL    : in std_logic;
    MUX_R31_SEL        : in std_logic;
    MUX_RS2_SEL        : in std_logic;
    MUX_RD_I_R_SEL     : in std_logic;
    RF_READ1           : in std_logic;
    RF_READ2           : in std_logic;
    RF_EN              : in std_logic;
    RegA_LATCH_EN      : in std_logic;  -- Register A Latch Enable
    RegB_LATCH_EN      : in std_logic;  -- Register B Latch Enable
    RegIMM_LATCH_EN    : in std_logic;  -- Immediate Register Latch Enable

    -- EX Control Signals
    MUXA1_SEL               : in std_logic;  -- MUX-A Sel
    FORWARD_MEM_ALU_A2_SEL  : in std_logic;
	 FORWARD_ALU_ALU_A3_SEL  : in std_logic;
  	 MUXB1_SEL               : in std_logic;  -- MUX-B Sel
    FORWARD_MEM_ALU_B2_SEL  : in std_logic;
	 FORWARD_ALU_ALU_B3_SEL  : in std_logic;
	 ALU_OPCODE1             : in std_logic;    -- ALU Operation Code
    ALU_OPCODE2             : in std_logic;
    ALU_OPCODE3             : in std_logic;
    ALU_OPCODE4             : in std_logic;
    ALU_OUTREG_EN           : in std_logic;  -- ALU Output Register Enable

    -- MEM Control Signals
    LD_SW_FORW_SEL     : in std_logic;
    DRAM_CS            : in std_logic;  -- Data RAM Write Enable
    DRAM_RD            : in std_logic;
    DRAM_WR            : in std_logic;
    LMD_LATCH_EN       : in std_logic;  -- LMD Register Latch Enable

    -- WB Control signals
    RF_WRITE           : in std_logic;  -- Register File Write Enable
    WB_MUX_SEL         : in std_logic;   -- Write Back MUX Sel
    PC_PLUS_8          : in std_logic;

    stall_dec          : in std_logic;
    stall_fetch        : in std_logic;
    stall_fetch_2cc    : in std_logic
    );

end Data_Path;


architecture RTL of Data_Path is

component register_file
	generic (N: integer:= 32;M:integer:=32; MM:integer:=5); --N=64;M=32 is the number of register;MM=log2 of the register number
	 port (  CLK: 		IN std_logic;
			 RESET: 	IN std_logic;
			 ENABLE: 	IN std_logic;
			 RD1: 		IN std_logic;
			 RD2: 		IN std_logic;
			 WR: 		IN std_logic;
			 ADD_WR: 	IN std_logic_vector(MM-1 downto 0);  -- used for the destination register
			 ADD_RD1: 	IN std_logic_vector(MM-1 downto 0);  -- used for the source register
			 ADD_RD2: 	IN std_logic_vector(MM-1 downto 0);  -- used for the source register
			 DATAIN: 	IN std_logic_vector(N-1 downto 0);
			 OUT1: 		OUT std_logic_vector(N-1 downto 0);
			 OUT2: 		OUT std_logic_vector(N-1 downto 0));
end component;

component Data_mem
	generic (N: integer:= 32; M:integer:=64); --N=64;M=32 is the number of register
	 port (CLK: 	IN std_logic;
			 RESET: 	IN std_logic;
			 CS: 	IN std_logic;
			 RD: 		IN std_logic;
			 WR: 		IN std_logic;
			 ADD: 	IN std_logic_vector(N-1 downto 0);
			 DATAIN: 	IN std_logic_vector(N-1 downto 0);
			 OUT1: 		OUT std_logic_vector(N-1 downto 0));
end component;

component ALU
  generic (N : integer := 32);
  port 	 (ALU_OP: 	 IN std_logic_vector (3 downto 0);
           DATA1, DATA2: IN std_logic_vector(N-1 downto 0);
           OUTALU: OUT std_logic_vector(N-1 downto 0));
end component;

component FD_generic
    Generic (NBIT: integer:= 32); --We define the total number of bits using the generic statement
	Port (	D_fd:	In	std_logic_vector(NBIT-1 downto 0); --The input signal and the output signal are arrays of bits
			CK_fd:	In	std_logic;
			RESET_fd:	In	std_logic;
			EN_fd: In std_logic;		
			Q_fd:	Out	std_logic_vector(NBIT-1 downto 0));
end component;

component MUX21_GENERIC
	Generic (NBIT: integer:= 32); 
	Port  (	A_mux:		In	std_logic_vector(NBIT-1 downto 0); --Declaration in a generic way of the various ports
			B_mux:		In	std_logic_vector(NBIT-1 downto 0);
			SEL_mux:	In	std_logic;
			Y_mux:		Out	std_logic_vector(NBIT-1 downto 0));
end component;

component FD
	Port (	D:	In	std_logic;
		CK:	In	std_logic;
		RESET:	In	std_logic;
		ENABLE: In std_logic;
		Q:	Out	std_logic);
end component;

component MUX21
	Port (A_mux:	In	std_logic;
		   B_mux:	In	std_logic;
		   SEL_mux:	In	std_logic;
		   Y_mux:	Out	std_logic);
end component;

component RCA_GEN
	generic (NBIT: INTEGER:= 32);
	Port (A:	In	std_logic_vector(NBIT-1 downto 0);
			B:	In	std_logic_vector(NBIT-1 downto 0);
			Ci:	In	std_logic;
			S:	Out	std_logic_vector(NBIT-1 downto 0);
			Co:	Out	std_logic);
end component;

component lhbu
	generic(N:integer:=32);
	port(data_in: in std_logic_vector(N-1 downto 0);
		  Sel: in std_logic_vector(1 downto 0);
		  data_out: out std_logic_vector(N-1 downto 0));
end component;

component IRAM
  generic (
    RAM_DEPTH : integer := 64;
    IR_SIZE   : integer := 32);
  port (
    Rst  : in  std_logic;
    Addr : in  std_logic_vector(IR_SIZE-1 downto 0);
    Dout : out std_logic_vector(IR_SIZE-1 downto 0));
end component;

   signal out_IRam, out_IR, addr_IRam, out1_RF, out2_RF, out_RegA, out_RegB, out_Imm_Reg, out_forw_MEM : std_logic_vector(IR_SIZE -1 downto 0);
   signal ALU_out, out_ALU_reg, out_add_four, out_pipeRegB, Imm_jmp : std_logic_vector(IR_SIZE -1 downto 0);
   signal out_Dmem, out_LMD, out_muxWB, out_ALU_reg2, out_mux_PC1, out_mux_PC2, Imm_0_32  : std_logic_vector(IR_SIZE -1 downto 0);
   signal out_muxA1, out_muxA2, out_muxA3, out_muxB1, out_muxB2, out_muxB3, out_muxWB1, out_mux_Imm3, Imm_32_sign : std_logic_vector(IR_SIZE -1 downto 0);
   signal out_IR1, out_IR2, out_IR3, out_mux_Imm2, out_lhbu, out_mux_LMD, out_mux_forw_EXE_DEC: std_logic_vector(IR_SIZE -1 downto 0);
   signal Co, lmd_sel0, lmd_sel1, lmd_sel2, lmd_sel3, lhbu_sel_0, lhbu_sel_1, lhbu_sel_2, lhbu_sel_3, lhbu_sel0, lhbu_sel1, lhbu_sel2, lhbu_sel3, BRANCH_OR_NOT, out_stall1, out_stall2, out_stall3, out_stall4, out_stall5, out_stall6, out_stall7, BRANCH_SIG: std_logic;
   signal Imm_32_u, Imm_32_s, out_NPC, out_PC_Imm, store_half, store_byte, out_SB_SH, out_store: std_logic_vector(IR_SIZE -1 downto 0);
   signal pipe1_add_four, pipe2_add_four, pipe3_add_four, pipe4_add_four: std_logic_vector(IR_SIZE -1 downto 0);
   signal regA_eq_0 : std_logic_vector(30 downto 0);
   signal Imm_16: std_logic_vector(15 downto 0);
   signal Imm_26: std_logic_vector(25 downto 0);
   signal out_mux_RS2, out_RD1, out_RD2, out_RD3, out_mux_IR16, out_mux_R31: std_logic_vector(OPERAND_SIZE-1 downto 0);
   signal RS1 : std_logic_vector(OPERAND_SIZE-1 downto 0);
   signal BRNCH : std_logic_vector(6 downto 0);
   signal  BRNCH_1bit, BRNCH_2 : std_logic_vector(5 downto 0);

  begin

  IR_OUT   <= out_IRam;

 -- lmd_sel0 <= out_IRam(27);
 -- lhbu_sel_0 <= out_IRam(26);
 -- lhbu_sel0 <= out_IRam(28);


-- FETCH Stage

  stall1 : MUX21 port map(A_mux => '0', B_mux => '1', SEL_mux => stall_fetch, Y_mux => out_stall1);
  PC_reg: FD_generic generic map(NBIT => 32) port map(D_fd => out_mux_PC2, CK_fd => CLK, RESET_fd => RST, EN_fd => out_stall1, Q_fd => output_from_PC);

  Add_four: RCA_GEN generic map(NBIT => 32) port map(A => addr_IRam, B => "00000000000000000000000000000001", Ci => '0', S => out_add_four, Co => Co);

  add_four_1: FD_generic generic map(NBIT => 32) port map(D_fd => out_add_four, CK_fd => CLK, RESET_fd => RST, EN_fd => '1', Q_fd => pipe1_add_four);

  add_four_2: FD_generic generic map(NBIT => 32) port map(D_fd => pipe1_add_four, CK_fd => CLK, RESET_fd => RST, EN_fd => '1', Q_fd => pipe2_add_four);

  add_four_3: FD_generic generic map(NBIT => 32) port map(D_fd => pipe2_add_four, CK_fd => CLK, RESET_fd => RST, EN_fd => '1', Q_fd => pipe3_add_four);

 -- add_four_4: FD_generic generic map(NBIT => 32) port map(D_fd => pipe3_add_four, CK_fd => CLK, RESET_fd => RST, EN_fd => '1', Q_fd => pipe4_add_four);

  branch0 : MUX21_GENERIC generic map(NBIT => 32) port map(A_mux => out_PC_Imm, B_mux => out_add_four, SEL_mux => BRANCH_OR_NOT, Y_mux => out_mux_PC1);

  Mux_PC_eq_regA: MUX21_GENERIC generic map(NBIT => 32) port map(A_mux => out_mux_forw_EXE_DEC, B_mux => out_mux_PC1, SEL_mux => JR_JALR, Y_mux => out_mux_PC2);

  stall7 : MUX21 port map(A_mux => '0', B_mux => '1', SEL_mux => stall_fetch, Y_mux => out_stall7);
  NPC: FD_generic generic map(NBIT => 32) port map(D_fd => out_mux_PC2, CK_fd => CLK, RESET_fd => RST, EN_fd => out_stall7, Q_fd => out_NPC);

 -- I_RAM: IRAM   generic map(RAM_DEPTH => 64, IR_SIZE => 32) port map(Rst => RST, Addr => addr_IRam, Dout => out_IRam);

  stall2 : MUX21 port map(A_mux => '0', B_mux => '1', SEL_mux => stall_fetch, Y_mux => out_stall2);
  IR: FD_generic generic map(NBIT => 32) port map(D_fd => input_for_IR, CK_fd => CLK, RESET_fd => RST, EN_fd => out_stall2, Q_fd => out_IR);

 -- IR_1: FD_generic generic map(NBIT => 32) port map(D_fd => out_IR, CK_fd => CLK, RESET_fd => RST, EN_fd => '1', Q_fd => out_IR1);

 -- IR_2: FD_generic generic map(NBIT => 32) port map(D_fd => out_IR1, CK_fd => CLK, RESET_fd => RST, EN_fd => '1', Q_fd => out_IR2);

 -- IR_3: FD_generic generic map(NBIT => 32) port map(D_fd => out_IR2, CK_fd => CLK, RESET_fd => RST, EN_fd => '1', Q_fd => out_IR3);

 lhbu_0: FD port map(D => out_IRam(26), CK => CLK, RESET => RST, ENABLE => '1', Q => lhbu_sel_0);

 lhbu0: FD port map(D => out_IRam(28), CK => CLK, RESET => RST, ENABLE => '1', Q => lhbu_sel0);

 lmd0:  FD port map(D => out_IRam(27), CK => CLK, RESET => RST, ENABLE => '1', Q => lmd_sel0);

  RS1 <= out_IR(25 downto 21);


 -- I_R_Type <= IR_opcode(0) OR IR_opcode(1); -- se l'istruzione è R-Type, OPCODE = 0, l'OR deve dare come risultato 0, e seleziono A_mux
  Mux_RS2 : MUX21_GENERIC generic map(NBIT => 5) port map(A_mux => out_IR(20 downto 16), B_mux => "00000", SEL_mux => MUX_RS2_SEL, Y_mux => out_mux_RS2);
  --RS2 <= out_mux_RS2; -- se l'istruzione è R-Type, mando 20 downto 16, altrimenti RS2 non c'è, e mando 000000

  Mux_RD_I_R : MUX21_GENERIC generic map(NBIT => 5) port map(A_mux => out_IR(15 downto 11), B_mux => out_IR(20 downto 16), SEL_mux => MUX_RD_I_R_SEL, Y_mux => out_mux_IR16);
  --RD <= out_mux_RD;
  Mux_R31 : MUX21_GENERIC generic map(NBIT => 5) port map(A_mux => "11111", B_mux => out_mux_IR16, SEL_mux => MUX_R31_SEL, Y_mux => out_mux_R31); -- per scegliere, eventualmente, R31 come reg destinazione

  stall6 : MUX21 port map(A_mux => '0', B_mux => '1', SEL_mux => stall_dec, Y_mux => out_stall6);
  RD_1: FD_generic generic map(NBIT => 5) port map(D_fd => out_mux_R31, CK_fd => CLK, RESET_fd => RST, EN_fd => out_stall6, Q_fd => out_RD1);

  RD_2: FD_generic generic map(NBIT => 5) port map(D_fd => out_RD1, CK_fd => CLK, RESET_fd => RST, EN_fd => '1', Q_fd => out_RD2);

  RD_3: FD_generic generic map(NBIT => 5) port map(D_fd => out_RD2, CK_fd => CLK, RESET_fd => RST, EN_fd => '1', Q_fd => out_RD3);


-- DECODE Stage
  RF: register_file generic map(N => 32, M => 32, MM => 5) port map(CLK => CLK, RESET => RST, ENABLE => RF_EN, RD1 => RF_READ1, RD2 => RF_READ2, WR => RF_WRITE, ADD_WR => out_RD3, ADD_RD1 => RS1, ADD_RD2 => out_mux_RS2, DATAIN => out_muxWB1, OUT1 => out1_RF, OUT2 => out2_RF);

  Imm_32_sign <= (31 downto 16 => out_IRam(15)) & out_IRam(15 downto 0);
  PC_Imm: RCA_GEN generic map(NBIT => 32) port map(A => out_NPC, B => Imm_32_sign, Ci => '0', S => out_PC_Imm, Co => Co);

  forw_EXE_DEC : MUX21_GENERIC generic map(NBIT => 32) port map(A_mux => out_ALU_reg, B_mux => out1_RF, SEL_mux => FORWARD_EXE_DEC_SEL, Y_mux => out_mux_forw_EXE_DEC);

  stall3 : MUX21 port map(A_mux => '0', B_mux => RegA_LATCH_EN, SEL_mux => stall_dec, Y_mux => out_stall3);
  RegA: FD_generic generic map(NBIT => 32) port map(D_fd => out_mux_forw_EXE_DEC, CK_fd => CLK, RESET_fd => RST, EN_fd => out_stall3, Q_fd => out_RegA);

  ZERO: for i in 0 to 30 generate
   ZERO1: if i = 0 generate regA_eq_0(i) <= out_mux_forw_EXE_DEC(0) OR out_mux_forw_EXE_DEC(1);
         end generate;
   ZERO2: if i/= 0 generate regA_eq_0(i) <= regA_eq_0(i-1) OR out_mux_forw_EXE_DEC(i+1);
        end generate;
  end generate;

  BRNCH <= '0' & (out_IRam(31 downto 26) - "000101");

  ONE: for j in 0 to 5 generate
   ONE1: if j = 0 generate BRNCH_1bit(j) <= BRNCH(0) OR BRNCH(1);
         end generate;
   ONE2: if j/= 0 generate BRNCH_1bit(j) <= BRNCH_1bit(j-1) OR BRNCH(j+1);        --- tutto questo per vedere se l'istruzione sia una BNEZ
        end generate;
  end generate;

  --BRNCH_2 <= BRNCH_1bit;
  branch_2: FD_generic generic map(NBIT => 6) port map(D_fd => BRNCH_1bit, CK_fd => CLK, RESET_fd => RST, EN_fd => '1', Q_fd => BRNCH_2);

  BRANCH_SIG <= ((not(regA_eq_0(30))) XNOR BRANCH) AND (not(BRNCH_2(5)) OR BRANCH);
  BRANCH_OR_NOT <= ((not(regA_eq_0(30))) XNOR BRANCH) AND (not(BRNCH_1bit(5)) OR BRANCH); -- se not(regA_eq_0(30)) è uguale a 1 (cioè regA = 0) E se l'istruzione è un BEQZ (BRANCH = 1), oppure se not(regA_eq_0(30)) è uguale a 0 (cioè regA = 1) E se l'istruzione è un BNEZ (BRANCH = 0), allora seleziona l'ingresso del mux proveniente da PC+4+Imm16

 -- branch_def: FD port map(D => BRANCH_SIG, CK => CLK, RESET => RST, ENABLE => '1', Q => BRANCH_OR_NOT);

  stall4 : MUX21 port map(A_mux => '0', B_mux => RegB_LATCH_EN, SEL_mux => stall_dec, Y_mux => out_stall4);
  RegB: FD_generic generic map(NBIT => 32) port map(D_fd => out2_RF, CK_fd => CLK, RESET_fd => RST, EN_fd => out_stall4, Q_fd => out_RegB);

  Imm_16    <= out_IR(15 downto 0);
  Imm_26    <= out_IR(25 downto 0);
  Imm_32_u  <= "0000000000000000" & Imm_16;
  Imm_32_s  <= (31 downto 16 => Imm_16(15)) & Imm_16;
 -- Imm_0_32  <= Imm_16 & "0000000000000000";
  Imm_jmp   <= "000000" & Imm_26;

  Mux_Imm2: MUX21_GENERIC generic map(NBIT => 32) port map(A_mux => Imm_32_u, B_mux =>Imm_32_s, SEL_mux => MUX_IMM_S_U_SEL, Y_mux => out_mux_Imm2);

  Mux_Imm3: MUX21_GENERIC generic map(NBIT => 32) port map(A_mux => Imm_jmp, B_mux =>out_mux_Imm2, SEL_mux => JMP_26, Y_mux => out_mux_Imm3);

  stall5 : MUX21 port map(A_mux => '0', B_mux => RegIMM_LATCH_EN, SEL_mux => stall_dec, Y_mux => out_stall5);
  Imm_Reg: FD_generic generic map(NBIT => 32) port map(D_fd => out_mux_Imm3, CK_fd => CLK, RESET_fd => RST, EN_fd => out_stall5, Q_fd => out_Imm_Reg);


-- EXE Stage
  MuxA1: MUX21_GENERIC generic map(NBIT => 32) port map(A_mux => out_add_four, B_mux => out_RegA, SEL_mux => MUXA1_SEL, Y_mux => out_muxA1);

  MuxA2: MUX21_GENERIC generic map(NBIT => 32) port map(A_mux => out_LMD, B_mux => out_muxA1, SEL_mux => FORWARD_MEM_ALU_A2_SEL, Y_mux => out_muxA2);

  MuxA3: MUX21_GENERIC generic map(NBIT => 32) port map(A_mux => out_ALU_reg, B_mux => out_muxA2, SEL_mux => FORWARD_ALU_ALU_A3_SEL, Y_mux => out_muxA3);  -- suppongo A_mux selezionato quando SEL_mux = 1

  MuxB1: MUX21_GENERIC generic map(NBIT => 32) port map(A_mux => out_RegB, B_mux => out_Imm_Reg, SEL_mux => MUXB1_SEL, Y_mux => out_muxB1);

  MuxB2: MUX21_GENERIC generic map(NBIT => 32) port map(A_mux => out_muxB1, B_mux => out_LMD, SEL_mux => FORWARD_MEM_ALU_B2_SEL, Y_mux => out_muxB2);

  MuxB3: MUX21_GENERIC generic map(NBIT => 32) port map(A_mux => out_muxB2, B_mux => out_ALU_reg, SEL_mux => FORWARD_ALU_ALU_B3_SEL, Y_mux => out_muxB3);

  ALU_struct: ALU generic map(N => 32) port map(ALU_OP(0) => ALU_OPCODE4, ALU_OP(1) => ALU_OPCODE3, ALU_OP(2) => ALU_OPCODE2, ALU_OP(3) => ALU_OPCODE1, DATA1 => out_muxA3, DATA2 => out_muxB3, OUTALU => ALU_out);

  ALU_reg: FD_generic generic map(NBIT => 32) port map(D_fd => ALU_out, CK_fd => CLK, RESET_fd => RST, EN_fd => ALU_OUTREG_EN, Q_fd => out_ALU_reg);

  Pipe_RegB: FD_generic generic map(NBIT => 32) port map(D_fd => out_RegB, CK_fd => CLK, RESET_fd => RST, EN_fd => '1', Q_fd => out_pipeRegB);


-- MEM Stage
  store_byte <= "000000000000000000000000" & out_pipeRegB(7 downto 0);
  store_half <= "0000000000000000" & out_pipeRegB(15 downto 0);

  SB_SH: MUX21_GENERIC generic map(NBIT => 32) port map(A_mux => store_half, B_mux => store_byte, SEL_mux => lhbu_sel_3, Y_mux => out_SB_SH);

  SW_BH: MUX21_GENERIC generic map(NBIT => 32) port map(A_mux => out_pipeRegB, B_mux => out_SB_SH, SEL_mux => lmd_sel3, Y_mux => out_store);  -- lmd_sel3 rappresenta il bit che differisce tra SW e le altre store! 

  forward_MEM: MUX21_GENERIC generic map(NBIT => 32) port map(A_mux => out_LMD, B_mux => out_pipeRegB, SEL_mux => LD_SW_FORW_SEL, Y_mux => out_forw_MEM);

 -- D_Mem: Data_mem generic map(N => 32, M => 64) port map(CLK => CLK, RESET => RST, CS => DRAM_CS, RD => DRAM_RD, WR => DRAM_WR, ADD => out_ALU_reg, DATAIN => out_forw_MEM, OUT1 => out_Dmem);

    output_from_mem <= out_forw_MEM;
 
 -- lmd_sel1 <= lmd_sel0; -- questo è l'unico bit (nell'opcode) che differisce tra la LW e le altre LOAD. Nella LW questo bit è ad '1', nelle altre a '0'. Quindi vedendo il valore di questo bit riesco a capire se l'istruzione 
 -- lmd_sel2 <= lmd_sel1;   -- di load sia una "normale" LW o un altro tipo di load. Questo bit lo devo poi pipelinare per 4 colpi di clock perchè mi deve pilotare il mux nello stage giusto!!!
 -- lmd_sel3 <= lmd_sel2;

 lhbu_1: FD port map(D => lhbu_sel_1, CK => CLK, RESET => RST, ENABLE => '1', Q => lhbu_sel_0);

 lhbu1: FD port map(D => lhbu_sel1, CK => CLK, RESET => RST, ENABLE => '1', Q => lhbu_sel0);

 lmd1:  FD port map(D => lmd_sel1, CK => CLK, RESET => RST, ENABLE => '1', Q => lmd_sel0);


 lhbu_2: FD port map(D => lhbu_sel_2, CK => CLK, RESET => RST, ENABLE => '1', Q => lhbu_sel_1);

 lhbu2: FD port map(D => lhbu_sel2, CK => CLK, RESET => RST, ENABLE => '1', Q => lhbu_sel1);

 lmd2:  FD port map(D => lmd_sel2, CK => CLK, RESET => RST, ENABLE => '1', Q => lmd_sel1);

 -- lhbu_sel_1 <= lhbu_sel_0;
 -- lhbu_sel_2 <= lhbu_sel_1;
 -- lhbu_sel_3 <= lhbu_sel_2; -- per scegliere tra lh, lhu, lb, lbu. Posso sfruttarli anche per le STORE questi segnali!!!!

 -- lhbu_sel1 <= lhbu_sel0;
 -- lhbu_sel2 <= lhbu_sel1;
 -- lhbu_sel3 <= lhbu_sel2;   -- per scegliere tra lh, lhu, lb, lbu. Posso sfruttarli anche per le STORE questi segnali!!!!

  LHBU_chose: lhbu generic map(N => 32) port map(data_in => input_for_mem, Sel(1) => lhbu_sel3, Sel(0) => lhbu_sel_3, data_out => out_lhbu);

  Mux_LMD: MUX21_GENERIC generic map(NBIT => 32) port map(A_mux => input_for_mem, B_mux => out_lhbu, SEL_mux => lmd_sel3, Y_mux => out_mux_LMD);

  LMD: FD_generic generic map(NBIT => 32) port map(D_fd => out_mux_LMD, CK_fd => CLK, RESET_fd => RST, EN_fd => LMD_LATCH_EN, Q_fd => out_LMD);

  ALU_reg_pipe: FD_generic generic map(NBIT => 32) port map(D_fd => out_ALU_reg, CK_fd => CLK, RESET_fd => RST, EN_fd => '1', Q_fd => out_ALU_reg2);


-- WB Stage
  WB_mux: MUX21_GENERIC generic map(NBIT => 32) port map(A_mux => out_LMD, B_mux => out_ALU_reg2, SEL_mux => WB_MUX_SEL, Y_mux => out_muxWB);

  WB1_mux: MUX21_GENERIC generic map(NBIT => 32) port map(A_mux => pipe3_add_four, B_mux => out_muxWB, SEL_mux => PC_PLUS_8, Y_mux => out_muxWB1); -- prende eventualmente il valore da inserire nel registro 

end RTL;