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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SaltPkg.all;

library niltos;

entity NiltosLane_tb is end NiltosLane_tb;

architecture testbed of NiltosLane_tb is

  constant TPD_G : time := 0.6 ns;

  -- constant SSI_NIST_CONFIG_C : AxiStreamConfigType := (
  --   TSTRB_EN_C    => false,
  --   TDATA_BYTES_C => 2,
  --   TDEST_BITS_C  => 8,
  --   TID_BITS_C    => 0,
  --   TKEEP_MODE_C  => TKEEP_COMP_C,
  --   TUSER_BITS_C  => 2,
  --   TUSER_MODE_C  => TUSER_FIRST_LAST_C);

  constant TX_PACKET_LENGTH_C : slv(31 downto 0) := toSlv(256, 32);
  constant NUMBER_PACKET_C    : slv(31 downto 0) := x"0000FFFF";
  constant PRBS_STAB_LENGTH_C : slv(31 downto 0) := x"000000FF";

  constant PRBS_SEED_SIZE_C : positive := 8*SSI_SALT_CONFIG_C.TDATA_BYTES_C;

  signal linkUp   : sl              := '0';
  signal txEn     : sl              := '0';
  signal rxEn     : sl              := '0';
  signal rxErr    : sl              := '0';
  signal errorDet : slv(7 downto 0) := (others => '0');
  signal cnt      : slv(31 downto 0);
  signal trigPrbs : sl;
  signal failed   : sl;

  signal txData : slv(7 downto 0);
  signal rxData : slv(7 downto 0);

  signal mps125MHzClk : sl := '0';
  signal mps125MHzRst : sl := '1';

  signal mps156MHzClk : sl := '0';
  signal mps156MHzRst : sl := '1';

  signal mps625MHzClkP : sl := '0';
  signal mps625MHzClkN : sl := '1';
  signal mps625MHzRst  : sl := '1';

  signal loopbackP : sl := '0';
  signal loopbackN : sl := '1';

begin

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
      EN       => linkUp,
      DATA_OUT => txData);

  NiltosLane_1 : entity niltos.NiltosLane
    generic map (
      TPD_G        => TPD_G,
      SIMULATION_G => true)
    port map (
      txP       => loopbackP,
      txN       => loopbackN,
      rxP       => loopbackP,
      rxN       => loopbackN,
      clk125MHz => mps125MHzClk,
      rst125MHz => mps125MHzRst,
      clk156MHz => mps156MHzClk,
      rst156MHz => mps156MHzRst,
      clk625MHz => mps625MHzClkP,
      linkUp    => linkUp,
      txEn      => txEn,
      txData    => txData,
      rxEn      => rxEn,
      rxErr     => rxErr,
      rxData    => rxData);

  txEn <= linkUp;

  process is
  begin  -- process
    trigPrbs <= '0';
    wait for 30 us;
    wait until rising_edge(mps125MHzClk);
    trigPrbs <= '1';
    wait;
  end process;

  PRBS_ANY_2 : entity niltos.PRBS_ANY
    generic map (
      CHK_MODE    => true,
      INV_PATTERN => false,
      POLY_LENGHT => 7,
      POLY_TAP    => 6,
      NBITS       => 8)
    port map (
      RST      => mps125MHzRst,
      CLK      => mps125MHzClk,
      DATA_IN  => rxData,
      EN       => linkUp,
      DATA_OUT => errorDet);

  p_check : process (mps125MHzClk) is
  begin  -- process p_check
    if rising_edge(mps125MHzClk) then   -- rising clock edge
      if mps125MHzRst = '1' or linkUp = '0' then
        cnt <= NUMBER_PACKET_C;
      else
        cnt <= cnt - 1;
      end if;
    end if;
  end process p_check;

  p_failing_check : process (mps125MHzClk) is
  begin  -- process p_check
    if rising_edge(mps125MHzClk) then   -- rising clock edge
      if mps125MHzRst = '1' or cnt > (NUMBER_PACKET_C - PRBS_STAB_LENGTH_C) then
        failed <= '0';
      else
        if or_reduce(errorDet) = '1' then
          failed <= '1';
        end if;
      end if;
    end if;
  end process p_failing_check;

  p_final_result : process (cnt, failed) is
  begin  -- process p_final_result
    if cnt < NUMBER_PACKET_C - PRBS_STAB_LENGTH_C then
      if failed = '1' then
        assert false
          report "Simulation Failed!" severity failure;
      elsif cnt = 0 then
        assert false
          report "Simulation Passed!" severity failure;
      end if;
    end if;
  end process p_final_result;

end testbed;

