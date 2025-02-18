-------------------------------------------------------------------------------
-- Title      : Niltos clk manager
-- Project    : 
-------------------------------------------------------------------------------
-- File       : SaltClkManager.vhd
-- Author     : Filippo Marini  <filippo.marini@pd.infn.it>
-- Company    : INFN Padova
-- Created    : 2025-02-10
-- Last update: 2025-02-18
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2025 INFN Padova
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2025-02-10  1.0      fmarini Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library unisim;
use unisim.vcomponents.all;


library surf;
use surf.StdRtlPkg.all;

entity NiltosClockManagerUltraScale is
  generic (
    TPD_G                  : time                             := 1 ns;
    SIMULATION_G           : boolean                          := false;
    NUM_CLOCKS_G           : integer range 1 to 7;
    FAST_CLK_G             : integer range 0 to 6             := 0;
    DIVCLK_G               : positive range 1 to 8            := 4;
    SIM_DEVICE_G           : string                           := "ULTRASCALE_PLUS";
    -- MMCM attributes
    BANDWIDTH_G            : string                           := "OPTIMIZED";
    CLKIN_PERIOD_G         : real                             := 10.0;  -- Input period in ns );
    DIVCLK_DIVIDE_G        : integer range 1 to 106           := 1;
    CLKFBOUT_MULT_F_G      : real range 1.0 to 128.0          := 1.0;
    CLKOUT0_DIVIDE_F_G     : real range 1.0 to 128.0          := 1.0;
    CLKOUT1_DIVIDE_G       : integer range 1 to 128           := 1;
    CLKOUT2_DIVIDE_G       : integer range 1 to 128           := 1;
    CLKOUT3_DIVIDE_G       : integer range 1 to 128           := 1;
    CLKOUT4_DIVIDE_G       : integer range 1 to 128           := 1;
    CLKOUT5_DIVIDE_G       : integer range 1 to 128           := 1;
    CLKOUT6_DIVIDE_G       : integer range 1 to 128           := 1;
    CLKOUT0_PHASE_G        : real range -360.0 to 360.0       := 0.0;
    CLKOUT1_PHASE_G        : real range -360.0 to 360.0       := 0.0;
    CLKOUT2_PHASE_G        : real range -360.0 to 360.0       := 0.0;
    CLKOUT3_PHASE_G        : real range -360.0 to 360.0       := 0.0;
    CLKOUT4_PHASE_G        : real range -360.0 to 360.0       := 0.0;
    CLKOUT5_PHASE_G        : real range -360.0 to 360.0       := 0.0;
    CLKOUT6_PHASE_G        : real range -360.0 to 360.0       := 0.0;
    CLKOUT0_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
    CLKOUT1_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
    CLKOUT2_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
    CLKOUT3_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
    CLKOUT4_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
    CLKOUT5_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
    CLKOUT6_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
    CLKOUT0_RST_HOLD_G     : integer range 3 to positive'high := 3;
    CLKOUT1_RST_HOLD_G     : integer range 3 to positive'high := 3;
    CLKOUT2_RST_HOLD_G     : integer range 3 to positive'high := 3;
    CLKOUT3_RST_HOLD_G     : integer range 3 to positive'high := 3;
    CLKOUT4_RST_HOLD_G     : integer range 3 to positive'high := 3;
    CLKOUT5_RST_HOLD_G     : integer range 3 to positive'high := 3;
    CLKOUT6_RST_HOLD_G     : integer range 3 to positive'high := 3;
    CLKOUT0_RST_POLARITY_G : sl                               := '1';
    CLKOUT1_RST_POLARITY_G : sl                               := '1';
    CLKOUT2_RST_POLARITY_G : sl                               := '1';
    CLKOUT3_RST_POLARITY_G : sl                               := '1';
    CLKOUT4_RST_POLARITY_G : sl                               := '1';
    CLKOUT5_RST_POLARITY_G : sl                               := '1';
    CLKOUT6_RST_POLARITY_G : sl                               := '1');
  port (
    clkP_i      : in  sl;
    clkN_i      : in  sl;
    rst_i       : in  sl := '0';
    MmcmClks_o  : out slv(NUM_CLOCKS_G-1 downto 0);
    MmcmRsts_o  : out slv(NUM_CLOCKS_G-1 downto 0);
    divClk_o    : out sl;
    rstDivClk_o : out sl := '0';
    locked_o    : out sl);
end entity NiltosClockManagerUltraScale;

architecture rtl of NiltosClockManagerUltraScale is

  signal s_clkInBufg  : sl;
  signal s_clkIn      : sl;
  signal s_clkFbOut   : sl;
  signal s_clkFbIn    : sl;
  signal s_clkOutMmcm : slv(6 downto 0) := (others => '0');
  signal s_clkOutLoc  : slv(6 downto 0) := (others => '0');
  signal s_divClk     : sl;
  signal s_locked     : sl;

begin  -- architecture rtl

  -- MMCM_GEN : if (not SIMULATION_G) generate

  -- Buffers
  U_IBUFDS : IBUFDS
    port map (
      I  => clkP_i,
      IB => clkN_i,
      O  => s_clkInBufg);

  U_BufgSysClk : BUFG
    port map (
      I => s_clkInBufg,
      O => s_clkIn
      );

  U_BufgFbClk : BUFG
    port map (
      I => s_clkFbOut,
      O => s_clkFbIn);

  -- MMCM
  U_Mmcm : MMCME4_ADV
    generic map (
      BANDWIDTH          => BANDWIDTH_G,
      CLKOUT4_CASCADE    => "FALSE",
      STARTUP_WAIT       => "FALSE",
      CLKIN1_PERIOD      => CLKIN_PERIOD_G,
      DIVCLK_DIVIDE      => DIVCLK_DIVIDE_G,
      CLKFBOUT_MULT_F    => CLKFBOUT_MULT_F_G,
      CLKOUT0_DIVIDE_F   => CLKOUT0_DIVIDE_F_G,
      CLKOUT1_DIVIDE     => CLKOUT1_DIVIDE_G,
      CLKOUT2_DIVIDE     => CLKOUT2_DIVIDE_G,
      CLKOUT3_DIVIDE     => CLKOUT3_DIVIDE_G,
      CLKOUT4_DIVIDE     => CLKOUT4_DIVIDE_G,
      CLKOUT5_DIVIDE     => CLKOUT5_DIVIDE_G,
      CLKOUT6_DIVIDE     => CLKOUT6_DIVIDE_G,
      CLKOUT0_PHASE      => CLKOUT0_PHASE_G,
      CLKOUT1_PHASE      => CLKOUT1_PHASE_G,
      CLKOUT2_PHASE      => CLKOUT2_PHASE_G,
      CLKOUT3_PHASE      => CLKOUT3_PHASE_G,
      CLKOUT4_PHASE      => CLKOUT4_PHASE_G,
      CLKOUT5_PHASE      => CLKOUT5_PHASE_G,
      CLKOUT6_PHASE      => CLKOUT6_PHASE_G,
      CLKOUT0_DUTY_CYCLE => CLKOUT0_DUTY_CYCLE_G,
      CLKOUT1_DUTY_CYCLE => CLKOUT1_DUTY_CYCLE_G,
      CLKOUT2_DUTY_CYCLE => CLKOUT2_DUTY_CYCLE_G,
      CLKOUT3_DUTY_CYCLE => CLKOUT3_DUTY_CYCLE_G,
      CLKOUT4_DUTY_CYCLE => CLKOUT4_DUTY_CYCLE_G,
      CLKOUT5_DUTY_CYCLE => CLKOUT5_DUTY_CYCLE_G,
      CLKOUT6_DUTY_CYCLE => CLKOUT6_DUTY_CYCLE_G)
    port map (
      DCLK     => '0',
      DRDY     => open,
      DEN      => '0',
      DWE      => '0',
      DADDR    => (others => '0'),
      DI       => (others => '0'),
      DO       => open,
      CDDCREQ  => '0',
      PSCLK    => '0',
      PSEN     => '0',
      PSINCDEC => '0',
      PWRDWN   => '0',
      RST      => rst_i,
      CLKIN1   => s_clkIn,
      CLKIN2   => '0',
      CLKINSEL => '1',
      CLKFBOUT => s_clkFbOut,
      CLKFBIN  => s_clkFbIn,
      LOCKED   => s_locked,
      CLKOUT0  => s_clkOutMmcm(0),
      CLKOUT1  => s_clkOutMmcm(1),
      CLKOUT2  => s_clkOutMmcm(2),
      CLKOUT3  => s_clkOutMmcm(3),
      CLKOUT4  => s_clkOutMmcm(4),
      CLKOUT5  => s_clkOutMmcm(5),
      CLKOUT6  => s_clkOutMmcm(6));
  -- end generate MMCM_GEN;

  -- MmcmEmu : if (SIMULATION_G) generate
  --   U_Mmcm : entity surf.MmcmEmulation
  --     generic map (
  --       CLKIN_PERIOD_G       => CLKIN_PERIOD_G,
  --       DIVCLK_DIVIDE_G      => DIVCLK_DIVIDE_G,
  --       CLKFBOUT_MULT_F_G    => CLKFBOUT_MULT_F_C,
  --       CLKOUT0_DIVIDE_F_G   => CLKOUT0_DIVIDE_F_C,
  --       CLKOUT1_DIVIDE_G     => CLKOUT1_DIVIDE_G,
  --       CLKOUT2_DIVIDE_G     => CLKOUT2_DIVIDE_G,
  --       CLKOUT3_DIVIDE_G     => CLKOUT3_DIVIDE_G,
  --       CLKOUT4_DIVIDE_G     => CLKOUT4_DIVIDE_G,
  --       CLKOUT5_DIVIDE_G     => CLKOUT5_DIVIDE_G,
  --       CLKOUT6_DIVIDE_G     => CLKOUT6_DIVIDE_G,
  --       CLKOUT0_PHASE_G      => CLKOUT0_PHASE_G,
  --       CLKOUT1_PHASE_G      => CLKOUT1_PHASE_G,
  --       CLKOUT2_PHASE_G      => CLKOUT2_PHASE_G,
  --       CLKOUT3_PHASE_G      => CLKOUT3_PHASE_G,
  --       CLKOUT4_PHASE_G      => CLKOUT4_PHASE_G,
  --       CLKOUT5_PHASE_G      => CLKOUT5_PHASE_G,
  --       CLKOUT6_PHASE_G      => CLKOUT6_PHASE_G,
  --       CLKOUT0_DUTY_CYCLE_G => CLKOUT0_DUTY_CYCLE_G,
  --       CLKOUT1_DUTY_CYCLE_G => CLKOUT1_DUTY_CYCLE_G,
  --       CLKOUT2_DUTY_CYCLE_G => CLKOUT2_DUTY_CYCLE_G,
  --       CLKOUT3_DUTY_CYCLE_G => CLKOUT3_DUTY_CYCLE_G,
  --       CLKOUT4_DUTY_CYCLE_G => CLKOUT4_DUTY_CYCLE_G,
  --       CLKOUT5_DUTY_CYCLE_G => CLKOUT5_DUTY_CYCLE_G,
  --       CLKOUT6_DUTY_CYCLE_G => CLKOUT6_DUTY_CYCLE_G)
  --     port map (
  --       CLKIN   => s_clkIn,
  --       RST     => rst_i,
  --       LOCKED  => s_locked,
  --       CLKOUT0 => s_clkOutMmcm(0),
  --       CLKOUT1 => s_clkOutMmcm(1),
  --       CLKOUT2 => s_clkOutMmcm(2),
  --       CLKOUT3 => s_clkOutMmcm(3),
  --       CLKOUT4 => s_clkOutMmcm(4),
  --       CLKOUT5 => s_clkOutMmcm(5),
  --       CLKOUT6 => s_clkOutMmcm(6));
  -- end generate MmcmEmu;

  -- Output buffers
  ClkOutGen : for i in NUM_CLOCKS_G-1 downto 0 generate
    U_Bufg : BUFG
      port map (
        I => s_clkOutMmcm(i),
        O => s_clkOutLoc(i));

    MmcmClks_o(i) <= s_clkOutLoc(i);
  end generate;

  -- CLKDIV
  BUFGCE_DIV_inst : BUFGCE_DIV
    generic map (
      BUFGCE_DIVIDE => DIVCLK_G,
      SIM_DEVICE    => SIM_DEVICE_G
      )
    port map (
      O   => s_divClk,                  -- 1-bit output: Buffer
      CE  => '1',                       -- 1-bit input: Buffer enable
      CLR => '0',                       -- 1-bit input: Asynchronous clear
      I   => s_clkOutMmcm(FAST_CLK_G)   -- 1-bit input: Buffer
      );

  -- Output
  locked_o <= s_locked;
  divClk_o <= s_divClk;


  -- Resets
  RstOutGen : for i in NUM_CLOCKS_G-1 downto 0 generate
    SKIP_FAST_CLK : if i /= FAST_CLK_G generate
      RstSync_1 : entity surf.RstSync
        generic map (
          TPD_G           => TPD_G,
          IN_POLARITY_G   => '0',
          OUT_POLARITY_G  => '1',
          BYPASS_SYNC_G   => false,
          RELEASE_DELAY_G => 3)
        port map (
          clk      => s_clkOutLoc(i),
          asyncRst => s_locked,
          syncRst  => MmcmRsts_o(i));
    end generate SKIP_FAST_CLK;
    BYP_RST_FAST : if i = FAST_CLK_G generate
      MmcmRsts_o(i) <= '0';
    end generate BYP_RST_FAST;
  end generate;

  RstSyncDivClk_1 : entity surf.RstSync
    generic map (
      TPD_G           => TPD_G,
      IN_POLARITY_G   => '0',
      OUT_POLARITY_G  => '1',
      BYPASS_SYNC_G   => false,
      RELEASE_DELAY_G => 3)
    port map (
      clk      => s_divClk,
      asyncRst => s_locked,
      syncRst  => rstDivClk_o);

end architecture rtl;
