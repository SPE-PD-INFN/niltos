-------------------------------------------------------------------------------
-- Title      : NiltosLane
-- Project    : 
-------------------------------------------------------------------------------
-- File       : NiltosLane.vhd
-- Author     : Filippo Marini  <filippo.marini@pd.infn.it>
-- Company    : INFN Padova
-- Created    : 2025-02-10
-- Last update: 2025-02-11
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

library surf;
use surf.StdRtlPkg.all;

entity NiltosLane is
  generic (
    TPD_G           : time    := 1 ns;
    SIMULATION_G    : boolean := false;
    SIM_DEVICE_G    : string  := "ULTRASCALE_PLUS";
    TX_ENABLE_G     : boolean := true;
    RX_ENABLE_G     : boolean := true;
    IODELAY_GROUP_G : string  := "SALT_GROUP";
    REF_FREQ_G      : real    := 200.0);  -- IDELAYCTRL's REFCLK (in units of Hz)
  port (
    -- 1.25 Gbps LVDS TX
    txP            : out sl;
    txN            : out sl;
    -- 1.25 Gbps LVDS RX
    rxP            : in  sl;
    rxN            : in  sl;
    -- Reference Signals
    clk125MHz      : in  sl;
    rst125MHz      : in  sl;
    clk156MHz      : in  sl;
    rst156MHz      : in  sl;
    clk625MHz      : in  sl;
    -- Status Interface
    linkUp         : out sl;
    -- Configuration Interface
    enUsrDlyCfg    : in  sl               := '0';  -- Enable User delay config
    usrDlyCfg      : in  slv(8 downto 0)  := (others => '0');  -- User delay config
    bypFirstBerDet : in  sl               := '1';  -- Set to '1' if IDELAY full scale range > 2 Unit Intervals (UI) of serial rate (example: IDELAY range 2.5ns  > 1 ns "1Gb/s" )
    minEyeWidth    : in  slv(7 downto 0)  := toSlv(80, 8);  -- Sets the minimum eye width required for locking (units of IDELAY step)
    lockingCntCfg  : in  slv(23 downto 0) := ite(SIMULATION_G, x"00_0064", x"00_FFFF");  -- Number of error-free event before state=LOCKED_S
    -- Slave Port
    txEn           : in  sl;
    txData         : in  slv(7 downto 0);
    -- Master Port
    rxEn           : out sl;
    rxErr          : out sl;
    rxData         : out slv(7 downto 0));
end NiltosLane;

architecture rtl of NiltosLane is

  signal rxLinkUp : sl := '0';

begin

  linkUp <= rxLinkUp and not(rst125MHz);

  TX_ENABLE : if TX_ENABLE_G generate

    U_SaltTxLvds : entity surf.SaltTxLvds
      generic map(
        TPD_G        => TPD_G,
        SIM_DEVICE_G => SIM_DEVICE_G)
      port map(
        -- Clocks and Resets
        clk125MHz => clk125MHz,
        rst125MHz => rst125MHz,
        clk156MHz => clk156MHz,
        rst156MHz => rst156MHz,
        clk625MHz => clk625MHz,
        -- GMII Interface
        txEn      => txEn,
        txData    => txData,
        -- LVDS TX Port
        txP       => txP,
        txN       => txN);

  end generate;

  RX_ENABLE : if RX_ENABLE_G generate

    U_SaltRxLvds : entity surf.SaltRxLvds
      generic map(
        TPD_G           => TPD_G,
        SIMULATION_G    => SIMULATION_G,
        SIM_DEVICE_G    => SIM_DEVICE_G,
        IODELAY_GROUP_G => IODELAY_GROUP_G,
        REF_FREQ_G      => REF_FREQ_G)
      port map(
        -- Clocks and Resets
        clk125MHz      => clk125MHz,
        rst125MHz      => rst125MHz,
        clk156MHz      => clk156MHz,
        rst156MHz      => rst156MHz,
        clk625MHz      => clk625MHz,
        -- GMII Interface
        rxEn           => rxEn,
        rxErr          => rxErr,
        rxData         => rxData,
        rxLinkUp       => rxLinkUp,
        -- Configuration Interface
        enUsrDlyCfg    => enUsrDlyCfg,
        usrDlyCfg      => usrDlyCfg,
        bypFirstBerDet => bypFirstBerDet,
        minEyeWidth    => minEyeWidth,
        lockingCntCfg  => lockingCntCfg,
        -- LVDS RX Port
        rxP            => rxP,
        rxN            => rxN);

  end generate;

end rtl;
