library IEEE;
use IEEE.std_logic_1164.all;


entity DLX is
	generic (
     IR_SIZE      : integer := 32       -- Instruction Register Size
    );
	port (
		CLK						: in std_logic;
		RST						: in std_logic;
    input_for_IR_i         : in std_logic_vector(IR_SIZE-1 downto 0);
    input_for_mem_i       : in std_logic_vector(IR_SIZE-1 downto 0);

   output_from_PC_i     : out std_logic_vector(IR_SIZE-1 downto 0);

   output_from_mem_i     : out std_logic_vector(IR_SIZE-1 downto 0);
	);
end DLX;


architecture dlx_rtl of DLX is

 -------------------------------------------------------------------

-- Data path
component Data_Path
 generic(
    FUNC_SIZE         :     integer := 11;  -- Func Field Size for R-Type Ops
	OPERAND_SIZE       :     integer := 5;
    OPCODE_SIZE      :     integer := 6;  -- Op Code Size
	IR_SIZE            :     integer := 32;
	MM                 :     integer := 5;
	CW_SIZE            :     integer := 33
 );

  port( CLK : in  std_logic;
        RST : in  std_logic;

    IR_OUT            : out std_logic_vector(IR_SIZE-1 downto 0);

  --  IR_LATCH_EN        : in std_logic;  -- Instruction Register Latch Enable
  --  PC_LATCH_EN        : in std_logic;  -- Program Counter Latch Enable

    output_from_PC     : out std_logic_vector(IR_SIZE-1 downto 0);
    input_for_IR       : in std_logic_vector(IR_SIZE-1 downto 0);

    output_from_mem     : out std_logic_vector(IR_SIZE-1 downto 0);
    input_for_mem       : in std_logic_vector(IR_SIZE-1 downto 0);

    JR_JALR            : in std_logic;

    -- ID Control Signals
    JMP_26             : in std_logic;
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
    PC_PLUS_8          : in std_logic;

    -- WB Control signals
    RF_WRITE           : in std_logic;  -- Register File Write Enable
    WB_MUX_SEL         : in std_logic;   -- Write Back MUX Sel

   stall_DEC 	  	        : in std_logic;
   stall_FETCH_2cc        : in std_logic;
   stall_FETCH            : in std_logic
    );
end component;

  -- Control Unit
component DLX_CU
  generic (
	 OPERAND_SIZE       :     integer := 5;
    FUNC_SIZE          :     integer := 11;   -- Func Field Size for R-Type Ops
    OPCODE_SIZE        :     integer := 6;    -- Op Code Size
    IR_SIZE            :     integer := 32;   -- Instruction Register Size
    CW_SIZE            :     integer := 33);  -- Control Word Size
  port (
    CLK                 : in std_logic;
    RST                 : in std_logic;
    IR_IN               : in std_logic_vector(IR_SIZE-1 downto 0);

   stall_DEC 	  	        : in std_logic;
   stall_FETCH_2cc        : in std_logic;
   stall_FETCH            : in std_logic;

    -- IF Control Signal
   -- IR_LATCH_EN        : out std_logic;  -- Instruction Register Latch Enable
   -- PC_LATCH_EN        : out std_logic;  -- Program Counter Latch Enable
    JR_JALR            : out std_logic;

    -- ID Control Signals
    JMP_26             : out std_logic;
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
    MUXA1_SEL           : out std_logic;  -- MUX-A Sel
    FORWARD_MEM_ALU_A2_SEL : out std_logic;
	 FORWARD_ALU_ALU_A3_SEL : out std_logic;
  	 MUXB1_SEL           : out std_logic;  -- MUX-B Sel
    FORWARD_MEM_ALU_B2_SEL  : out std_logic;
	 FORWARD_ALU_ALU_B3_SEL  : out std_logic;
	 ALU_OPCODE1         : out std_logic;    -- ALU Operation Code
    ALU_OPCODE2         : out std_logic;
    ALU_OPCODE3         : out std_logic;
    ALU_OPCODE4         : out std_logic;
    ALU_OUTREG_EN       : out std_logic;  -- ALU Output Register Enable

    -- MEM Control Signals
    LD_SW_FORW_SEL     : out std_logic;	
    DRAM_CS            : out std_logic;  -- Data RAM Write Enable
    DRAM_RD            : out std_logic;
    DRAM_WR            : out std_logic;
    LMD_LATCH_EN       : out std_logic;  -- LMD Register Latch Enable
    PC_PLUS_8          : out std_logic;

    -- WB Control signals
    RF_WRITE           : out std_logic;  -- Register File Write Enable
    WB_MUX_SEL         : out std_logic  -- Write Back MUX Sel
  );

end component;


component stall_unit
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
end component;

  ----------------------------------------------------------------
  -- Signals Declaration
  ----------------------------------------------------------------

  signal stall_DEC_i 	  	        : std_logic;
  signal stall_FETCH_2cc_i        : std_logic;
  signal stall_FETCH_i            : std_logic;

 -- signal  IR_LATCH_EN_i        : std_logic;  -- Instruction Register Latch Enable
 -- signal  PC_LATCH_EN_i        : std_logic;  -- Program Counter Latch Enable


  signal JR_JALR_i             : std_logic;
  signal JMP_26_i                : std_logic;
  signal BRANCH_i                : std_logic;
  signal FORWARD_EXE_DEC_SEL_i : std_logic;
  signal MUX_IMM_S_U_SEL_i          : std_logic;
  signal MUX_R31_SEL_i              : std_logic;
  signal MUX_RS2_SEL_i              : std_logic;
  signal MUX_RD_I_R_SEL_i           : std_logic;
  signal  RF_READ1_i              : std_logic;
  signal  RF_READ2_i           : std_logic;
  signal  RF_EN_i              : std_logic;	
  signal  RegA_LATCH_EN_i      : std_logic;  -- Register A Latch Enable
  signal  RegB_LATCH_EN_i      : std_logic;  -- Register B Latch Enable
  signal  RegIMM_LATCH_EN_i    : std_logic;  -- Immediate Register Latch Enable
  signal  MUXA1_SEL_i           : std_logic;  -- MUX-A Sel
  signal  FORWARD_MEM_ALU_A2_SEL_i : std_logic;
  signal FORWARD_ALU_ALU_A3_SEL_i : std_logic;
  signal MUXB1_SEL_i           : std_logic;  -- MUX-B Sel
  signal FORWARD_MEM_ALU_B2_SEL_i  : std_logic;
  signal FORWARD_ALU_ALU_B3_SEL_i  : std_logic;
  signal ALU_OPCODE1_i         : std_logic;    -- ALU Operation Code
  signal ALU_OPCODE2_i         : std_logic;
  signal ALU_OPCODE3_i         : std_logic;
  signal ALU_OPCODE4_i         : std_logic;
  signal ALU_OUTREG_EN_i       : std_logic;  -- ALU Output Register Enable
  signal LD_SW_FORW_SEL_i     : std_logic;
  signal DRAM_CS_i                 : std_logic;  -- Data RAM Write Enable
  signal DRAM_RD_i                 : std_logic;
  signal DRAM_WR_i                 : std_logic;
  signal LMD_LATCH_EN_i       : std_logic;  -- LMD Register Latch Enable
  signal PC_PLUS_8_i          : std_logic;
  signal PC_PLUS_8            : std_logic;
  signal RF_WRITE_i           : std_logic;  -- Register File Write Enable
  signal WB_MUX_SEL_i         : std_logic;  -- Write Back MUX Sel

  signal IR_DATAPATH_CU       :std_logic_vector(IR_SIZE-1 downto 0);
  
begin
    -- Control Unit Instantiation
    CU_I: DLX_CU
     generic map(
	 OPERAND_SIZE   => 5,
    FUNC_SIZE      => 11,   -- Func Field Size for R-Type Ops
    OPCODE_SIZE   => 6,    -- Op Code Size
    IR_SIZE        => 32,   -- Instruction Register Size
    CW_SIZE        => 33)
	
      port map (
          CLK             => CLK,
          RST             => RST,

         IR_IN => IR_DATAPATH_CU,

   stall_DEC 	     => stall_DEC_i,
   stall_FETCH_2cc  => stall_FETCH_2cc_i,
   stall_FETCH      => stall_FETCH_i,

   	--	IR_LATCH_EN        => IR_LATCH_EN_i,
    	--	PC_LATCH_EN         => PC_LATCH_EN_i,
    		JR_JALR             => JR_JALR_i,
         JMP_26             => JMP_26_i,
         BRANCH              => BRANCH_i,
         FORWARD_EXE_DEC_SEL => FORWARD_EXE_DEC_SEL_i,
   		MUX_IMM_S_U_SEL    => MUX_IMM_S_U_SEL_i,
   		MUX_R31_SEL        => MUX_R31_SEL_i,
   		MUX_RS2_SEL        => MUX_RS2_SEL_i,
   		MUX_RD_I_R_SEL     => MUX_RD_I_R_SEL_i,
    		RF_READ1            => RF_READ1_i,
    		RF_READ2            => RF_READ2_i,
    		RF_EN               => RF_EN_i,
    		RegA_LATCH_EN       => RegA_LATCH_EN_i,
    		RegB_LATCH_EN        => RegB_LATCH_EN_i,
    		RegIMM_LATCH_EN       => RegIMM_LATCH_EN_i,
    		MUXA1_SEL              => MUXA1_SEL_i,
    		FORWARD_MEM_ALU_A2_SEL  => FORWARD_MEM_ALU_A2_SEL_i,
			FORWARD_ALU_ALU_A3_SEL   => FORWARD_ALU_ALU_A3_SEL_i,
  	 		MUXB1_SEL            => MUXB1_SEL_i,
    		FORWARD_MEM_ALU_B2_SEL   => FORWARD_MEM_ALU_B2_SEL_i,
	 		FORWARD_ALU_ALU_B3_SEL   => FORWARD_ALU_ALU_B3_SEL_i,
	 		ALU_OPCODE1          => ALU_OPCODE1_i,
    		ALU_OPCODE2          => ALU_OPCODE2_i,
    		ALU_OPCODE3          => ALU_OPCODE3_i,
    		ALU_OPCODE4          => ALU_OPCODE4_i,
    		ALU_OUTREG_EN        => ALU_OUTREG_EN_i,
    		LD_SW_FORW_SEL      => LD_SW_FORW_SEL_i,
         DRAM_CS              => DRAM_CS_i,
         DRAM_RD              => DRAM_RD_i,
         DRAM_WR              => DRAM_WR_i,
    		LMD_LATCH_EN        => LMD_LATCH_EN_i,
         PC_PLUS_8          => PC_PLUS_8_i,
    		RF_WRITE            => RF_WRITE_i,
    		WB_MUX_SEL          => WB_MUX_SEL_i
	  );

    -- Data Path Instantiation
    DP_I: Data_Path
	 generic map(
		FUNC_SIZE       => 11,  -- Func Field Size for R-Type Ops
		OPERAND_SIZE    => 5,
		OPCODE_SIZE    => 6,  -- Op Code Size
		IR_SIZE         => 32,
		MM              => 5,
		CW_SIZE         => 33)

	  port map (
		   CLK				 => CLK,
  	       RST				 => RST,

    	   IR_OUT => IR_DATAPATH_CU,

       --  IR_LATCH_EN        => IR_LATCH_EN_i,
    	 --	PC_LATCH_EN         => PC_LATCH_EN_i,
         input_for_IR          => input_for_IR_i,
         output_from_PC      => output_from_PC_i,
         output_from_mem     => output_from_mem_i,
    input_for_mem           => input_for_mem_i,

    		JR_JALR             => JR_JALR_i,
         JMP_26             => JMP_26_i,
         BRANCH              => BRANCH_i,
         FORWARD_EXE_DEC_SEL => FORWARD_EXE_DEC_SEL_i,
   		MUX_IMM_S_U_SEL    => MUX_IMM_S_U_SEL_i,
   		MUX_R31_SEL        => MUX_R31_SEL_i,
   		MUX_RS2_SEL        => MUX_RS2_SEL_i,
   		MUX_RD_I_R_SEL     => MUX_RD_I_R_SEL_i,
    		RF_READ1            => RF_READ1_i,
    		RF_READ2            => RF_READ2_i,
    		RF_EN               => RF_EN_i,
    		RegA_LATCH_EN       => RegA_LATCH_EN_i,
    		RegB_LATCH_EN        => RegB_LATCH_EN_i,
    		RegIMM_LATCH_EN       => RegIMM_LATCH_EN_i,
    		MUXA1_SEL              => MUXA1_SEL_i,
    		FORWARD_MEM_ALU_A2_SEL  => FORWARD_MEM_ALU_A2_SEL_i,
			FORWARD_ALU_ALU_A3_SEL   => FORWARD_ALU_ALU_A3_SEL_i,
  	 		MUXB1_SEL            => MUXB1_SEL_i,
    		FORWARD_MEM_ALU_B2_SEL   => FORWARD_MEM_ALU_B2_SEL_i,
	 		FORWARD_ALU_ALU_B3_SEL   => FORWARD_ALU_ALU_B3_SEL_i,
	 		ALU_OPCODE1          => ALU_OPCODE1_i,
    		ALU_OPCODE2          => ALU_OPCODE2_i,
    		ALU_OPCODE3          => ALU_OPCODE3_i,
    		ALU_OPCODE4          => ALU_OPCODE4_i,
    		ALU_OUTREG_EN        => ALU_OUTREG_EN_i,
    		LD_SW_FORW_SEL      => LD_SW_FORW_SEL_i,
         DRAM_CS              => DRAM_CS_i,
         DRAM_RD              => DRAM_RD_i,
         DRAM_WR              => DRAM_WR_i,
    		LMD_LATCH_EN        => LMD_LATCH_EN_i,
         PC_PLUS_8          => PC_PLUS_8_i,
    		RF_WRITE            => RF_WRITE_i,
    		WB_MUX_SEL          => WB_MUX_SEL_i,

   stall_DEC 	     => stall_DEC_i,
   stall_FETCH_2cc  => stall_FETCH_2cc_i,
   stall_FETCH      => stall_FETCH_i
  );


stall_u: stall_unit
 generic map(
  IR_SIZE       => 32,
  OPCODE_SIZE   => 6,   -- Op Code Size
  OPERAND_SIZE  => 5)

 port map(
   CLK   => CLK,
   RST   => RST,

   IR_IN => IR_DATAPATH_CU,

   stall_DEC 	     => stall_DEC_i,
   stall_FETCH_2cc  => stall_FETCH_2cc_i,
   stall_FETCH      => stall_FETCH_i
 );

end dlx_rtl;


configuration CFG_DLX_MAIN of DLX is
	for dlx_rtl
	end for;
end CFG_DLX_MAIN;