-------------------------------------------------------------------------------
-- Title      : NILToS Tb
-- Project    : 
-------------------------------------------------------------------------------
-- File       : Nilt_Tb.vhd
-- Author     : Filippo Marini  <filippo.marini@pd.infn.it>
-- Company    : INFN Padova
-- Created    : 2025-02-05
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
-- 2025-02-05  1.0      fmarini Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_misc.all;
use ieee.math_real.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SaltPkg.all;

library niltos;

entity Niltos_tb is end Niltos_tb;

architecture testbed of Niltos_tb is

  -----------------------------------------------------------------------------
  -- Settings
  -----------------------------------------------------------------------------
  constant DELAY_BITS_C         : positive := 16;
  constant MAX_DELAY_VALUE_C    : real     := 16.0;  -- * 0.8 ns
  constant DELAY_SEEDS_C        : integer  := 42;
  constant NUM_LANES_G          : positive := 8;
  constant SHIFT_ARRAY_LENGTH_G : positive := 5;
  constant SYNC_LANES_G         : boolean  := false;
  -----------------------------------------------------------------------------

  impure function rand_int(min_val, max_val : integer) return integer is
    variable r            : real;
    variable seed1, seed2 : integer := 42;
  begin
    uniform(seed1, seed2, r);
    return integer(
      round(r * real(max_val - min_val + 1) + real(min_val) - 0.5));
  end function;

  constant TPD_G              : time             := 0.6 ns;
  constant TX_PACKET_LENGTH_C : slv(31 downto 0) := toSlv(256, 32);
  constant NUMBER_PACKET_C    : slv(31 downto 0) := x"0000FFFF";
  constant PRBS_STAB_LENGTH_C : slv(31 downto 0) := x"000000FF";
  constant PRBS_SEED_SIZE_C   : positive         := 8*SSI_SALT_CONFIG_C.TDATA_BYTES_C;

  signal delayValues  : integerArray(NUM_LANES_G-1 downto 0);
  signal linkUp       : sl                          := '0';
  signal singleLinkUp : slv(NUM_LANES_G-1 downto 0) := (others => '0');
  signal txEn         : sl                          := '0';
  signal rxEn         : sl                          := '0';
  signal rxErr        : sl                          := '0';
  signal errorDet     : slv(7 downto 0)             := (others => '0');
  signal cnt          : slv(31 downto 0);
  signal trigPrbs     : sl;
  signal failed       : sl;

  signal prbsData : Slv8Array(NUM_LANES_G-1 downto 0);
  signal txData   : slv((8*NUM_LANES_G)-1 downto 0);
  signal rxData   : slv((8*NUM_LANES_G)-1 downto 0);

  signal mps125MHzClk : sl := '0';
  signal mps125MHzRst : sl := '1';

  signal mps156MHzClk : sl := '0';
  signal mps156MHzRst : sl := '1';

  signal mps625MHzClkP : sl := '0';
  signal mps625MHzClkN : sl := '1';
  signal mps625MHzRst  : sl := '1';

  signal mps1250MHzClkP : sl := '0';
  signal mps1250MHzClkN : sl := '1';
  signal mps1250MHzRst  : sl := '1';

  signal loopbackP : slv(NUM_LANES_G-1 downto 0) := (others => '0');
  signal loopbackN : slv(NUM_LANES_G-1 downto 0) := (others => '1');
  signal txP       : slv(NUM_LANES_G-1 downto 0) := (others => '0');
  signal txN       : slv(NUM_LANES_G-1 downto 0) := (others => '1');
  signal rxP       : slv(NUM_LANES_G-1 downto 0) := (others => '0');
  signal rxN       : slv(NUM_LANES_G-1 downto 0) := (others => '1');

begin

  -- Set delays
  process is
    variable seed1, seed2 : integer := DELAY_SEEDS_C;  -- Random seeds
    variable rand_real    : real;
  begin  -- process
    -- If lanes are synchronized...
    if SYNC_LANES_G then
      -- ... fill them with different random values
      for i in 0 to NUM_LANES_G-1 loop
        uniform(seed1, seed2, rand_real);
        delayValues(i) <= integer(rand_real * MAX_DELAY_VALUE_C);  -- Random integer from 0 to MAX_DELAY_VALUE_C
      end loop;  -- i
    -- If lanes are not synchronized...
    else
      -- ... fill them with the same random value
      uniform(seed1, seed2, rand_real);
      for i in 0 to NUM_LANES_G-1 loop
        delayValues(i) <= integer(rand_real * MAX_DELAY_VALUE_C);  -- Random integer from 0 to MAX_DELAY_VALUE_C
      end loop;  -- i
    end if;
    wait;
  end process;

  U_125MHz : entity surf.ClkRst
    generic map (
      CLK_PERIOD_G      => 8.0 ns,
      RST_START_DELAY_G => 0 ns,
      RST_HOLD_TIME_G   => 1000 ns)
    port map (
      clkP => mps125MHzClk,
      rst  => mps125MHzRst);

  U_156MHz : entity surf.ClkRst
    generic map (
      CLK_PERIOD_G      => 6.4 ns,
      RST_START_DELAY_G => 0 ns,
      RST_HOLD_TIME_G   => 1000 ns)
    port map (
      clkP => mps156MHzClk,
      rst  => mps156MHzRst);

  U_625MHz : entity surf.ClkRst
    generic map (
      CLK_PERIOD_G      => 1.6 ns,
      RST_START_DELAY_G => 0 ns,
      RST_HOLD_TIME_G   => 1000 ns)
    port map (
      clkP => mps625MHzClkP,
      clkN => mps625MHzClkN,
      rst  => mps625MHzRst);

  U_1250MHz : entity surf.ClkRst
    generic map (
      CLK_PERIOD_G      => 0.8 ns,
      RST_START_DELAY_G => 0 ns,
      RST_HOLD_TIME_G   => 1000 ns)
    port map (
      clkP => mps1250MHzClkP,
      clkN => mps1250MHzClkN,
      rst  => mps1250MHzRst);

  GEN_LANE_PRBS : for lp in 0 to NUM_LANES_G-1 generate
    PRBS_ANY_1 : entity niltos.PRBS_ANY
      generic map (
        CHK_MODE    => false,
        INV_PATTERN => false,
        POLY_LENGHT => 7,
        POLY_TAP    => 6,
        NBITS       => 8)
      port map (
        RST      => mps125MHzRst,
        CLK      => mps125MHzClk,
        DATA_IN  => (others => '0'),
        EN       => singleLinkUp(lp),
        DATA_OUT => prbsData(lp));
  end generate GEN_LANE_PRBS;

  GEN_TX_DATA : for ld in 0 to NUM_LANES_G-1 generate
    txData((8*ld)+7 downto (8*ld)) <= prbsData(ld);
  end generate GEN_TX_DATA;

  Niltos_1 : entity niltos.Niltos
    generic map (
      TPD_G                => TPD_G,
      NUM_LANES_G          => NUM_LANES_G,
      SYNC_LANES_G         => SYNC_LANES_G,
      SHIFT_ARRAY_LENGTH_G => SHIFT_ARRAY_LENGTH_G,
      SIMULATION_G         => true)
    port map (
      txP          => txP,
      txN          => txN,
      rxP          => rxP,
      rxN          => rxN,
      clk125MHz    => mps125MHzClk,
      rst125MHz    => mps125MHzRst,
      clk156MHz    => mps156MHzClk,
      rst156MHz    => mps156MHzRst,
      clk625MHz    => mps625MHzClkP,
      linkUp       => linkUp,
      singleLinkUp => singleLinkUp,
      txEn         => txEn,
      txData       => txData,
      rxEn         => rxEn,
      rxErr        => rxErr,
      rxData       => rxData);

  txEn <= linkUp;

  GEN_DELAY : for lane in 0 to NUM_LANES_G-1 generate
    SlvDelay_P : entity surf.SlvDelay
      generic map (
        TPD_G   => TPD_G,
        DELAY_G => DELAY_BITS_C
        )
      port map (
        clk     => mps1250MHzClkP,
        rst     => mps1250MHzRst,
        en      => '1',
        delay   => toSlv(delayValues(lane), log2(DELAY_BITS_C)),
        din(0)  => txP(lane),
        dout(0) => rxP(lane));

    SlvDelay_N : entity surf.SlvDelay
      generic map (
        TPD_G   => TPD_G,
        DELAY_G => DELAY_BITS_C
        )
      port map (
        clk     => mps1250MHzClkP,
        rst     => mps1250MHzRst,
        en      => '1',
        delay   => toSlv(delayValues(lane), log2(DELAY_BITS_C)),
        din(0)  => txN(lane),
        dout(0) => rxN(lane));
  end generate GEN_DELAY;

end testbed;

