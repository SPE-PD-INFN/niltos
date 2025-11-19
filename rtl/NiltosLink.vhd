-------------------------------------------------------------------------------
-- Title      : NILT (Neighboring INFN LVDS Transmission) over SALT
-- Project    : 
-------------------------------------------------------------------------------
-- File       : Niltos.vhd
-- Author     : Filippo Marini  <filippo.marini@pd.infn.it>
-- Company    : INFN Padova
-- Created    : 2025-02-11
-- Last update: 2025-02-19
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2025 INFN Padova
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2025-02-11  1.0      fmarini Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.Code8b10bPkg.all;

library niltos;
use niltos.NiltosPkg.all;

library unisim;
use unisim.vcomponents.all;

entity NiltosLink is
  generic (
    TPD_G                : time                   := 1 ns;
    NUM_LANES_G          : positive               := 4;
    SYNC_LANES_G         : boolean                := true;
    SHIFT_ARRAY_LENGTH_G : positive range 1 to 16 := 5;
    SIMULATION_G         : boolean                := false;
    SIM_DEVICE_G         : string                 := "ULTRASCALE_PLUS";
    IODELAY_GROUP_G      : string                 := "SALT_GROUP";
    REF_FREQ_G           : real                   := 200.0);  -- IDELAYCTRL's REFCLK (in units of Hz)
  port (
    -- 1.25 Gbps LVDS TX
    txP            : out slv(NUM_LANES_G-1 downto 0);
    txN            : out slv(NUM_LANES_G-1 downto 0);
    -- 1.25 Gbps LVDS RX
    rxP            : in  slv(NUM_LANES_G-1 downto 0);
    rxN            : in  slv(NUM_LANES_G-1 downto 0);
    -- Reference Signals
    clk125MHz      : in  sl;
    rst125MHz      : in  sl;
    -- clkNoBuf625MHz : in  sl;
    clk625MHz : in sl;
    clk156MHz : in sl;
    -- Status Interface
    linkUp         : out sl;
    singleLinkUp   : out slv(NUM_LANES_G-1 downto 0);
    -- Configuration Interface
    enUsrDlyCfg    : in  sl               := '0';  -- Enable User delay config
    usrDlyCfg      : in  slv(8 downto 0)  := (others => '0');  -- User delay config
    bypFirstBerDet : in  sl               := '1';  -- Set to '1' if IDELAY full scale range > 2 Unit Intervals (UI) of serial rate (example: IDELAY range 2.5ns  > 1 ns "1Gb/s" )
    minEyeWidth    : in  slv(7 downto 0)  := toSlv(80, 8);  -- Sets the minimum eye width required for locking (units of IDELAY step)
    lockingCntCfg  : in  slv(23 downto 0) := ite(SIMULATION_G, x"00_0064", x"00_FFFF");  -- Number of error-free event before state=LOCKED_S
    -- Slave Port
    txEn           : in  sl;
    txData         : in  slv((8*NUM_LANES_G)-1 downto 0);
    -- Master Port
    rxEn           : out sl;
    rxErr          : out sl;
    rxData         : out slv((8*NUM_LANES_G)-1 downto 0));
end NiltosLink;

architecture rtl of NiltosLink is

  constant SR_WAIT_C : positive := SHIFT_ARRAY_LENGTH_G * 2;

  type IntegerArrayWRange is array (natural range <>) of integer range 0 to 127;

  type TxStateType is (
    IDLE_S,
    MOVE_S,
    GO_S);

  type RxStateType is (
    IDLE_S,
    SR_WAIT_S,
    SYNC_S,
    ALIGN_S,
    RX_LOCKED_S,
    TXRX_LOCKED_S);

  type TxRegType is record
    txData : Slv8Array(NUM_LANES_G-1 downto 0);
    index  : slv(3 downto 0);
    state  : TxStateType;
  end record TxRegType;

  type RxRegType is record
    rxData        : slv(7 downto 0);
    shiftRegister : Slv8VectorArray(NUM_LANES_G-1 downto 0, SHIFT_ARRAY_LENGTH_G-1 downto 0);
    shiftIndex    : IntegerArrayWRange(NUM_LANES_G-1 downto 0);
    laneAlignment : Slv7Array(NUM_LANES_G-1 downto 1);
    srWaitCnt     : natural range 0 to SR_WAIT_C-1;
    rxLocked      : sl;
    txLocked      : sl;
    state         : RxStateType;
  end record RxRegType;

  constant TX_REG_INIT_C : TxRegType := (
    txData => (others => K_28_5_C),
    index  => (others => '0'),
    state  => IDLE_S);

  constant RX_REG_INIT_C : RxRegType := (
    rxData        => (others => '0'),
    shiftRegister => (others => (others => (others => '0'))),
    shiftIndex    => (others => SHIFT_ARRAY_LENGTH_G/2),
    laneAlignment => (others => (others => '0')),
    srWaitCnt     => 0,
    rxLocked      => '0',
    txLocked      => '0',
    state         => IDLE_S);

  signal txR   : TxRegType := TX_REG_INIT_C;
  signal txRin : TxRegType;

  signal rxR   : RxRegType := RX_REG_INIT_C;
  signal rxRin : RxRegType;

  signal s_clk156MHz    : sl;
  signal s_clk625MHz    : sl;
  signal s_txData       : slv((8*NUM_LANES_G)-1 downto 0);
  signal s_rxData       : slv((8*NUM_LANES_G)-1 downto 0);
  signal s_singleLinkUp : slv(NUM_LANES_G-1 downto 0);
  signal s_rxEn         : slv(NUM_LANES_G-1 downto 0);
  signal s_rxErr        : slv(NUM_LANES_G-1 downto 0);
  signal s_txEn         : slv(NUM_LANES_G-1 downto 0);

begin  -- architecture rtl

  -----------------------------------------------------------------------------
  -- Clocking
  -----------------------------------------------------------------------------
  -- CLKDIV
  -- BUFGCE_DIV_inst : BUFGCE_DIV
  --   generic map (
  --     BUFGCE_DIVIDE => 4,
  --     SIM_DEVICE    => SIM_DEVICE_G
  --     )
  --   port map (
  --     O   => s_clk156MHz,               -- 1-bit output: Buffer
  --     CE  => '1',                       -- 1-bit input: Buffer enable
  --     CLR => '0',                       -- 1-bit input: Asynchronous clear
  --     I   => clkNoBuf625MHz             -- 1-bit input: Buffer
  --     );

  -- BUFG_INST : BUFG
  --   port map (
  --     I => clkNoBuf625MHz,
  --     O => s_clk625MHz);

  GEN_SALT_LANES : for i in 0 to NUM_LANES_G-1 generate
    NiltosLane_1 : entity work.NiltosLane
      generic map (
        TPD_G           => TPD_G,
        SIMULATION_G    => SIMULATION_G,
        SIM_DEVICE_G    => SIM_DEVICE_G,
        TX_ENABLE_G     => true,
        RX_ENABLE_G     => true,
        IODELAY_GROUP_G => IODELAY_GROUP_G,
        REF_FREQ_G      => REF_FREQ_G)
      port map (
        txP            => txP(i),
        txN            => txN(i),
        rxP            => rxP(i),
        rxN            => rxN(i),
        clk125MHz      => clk125MHz,
        rst125MHz      => rst125MHz,
        clk156MHz      => clk156MHz,
        rst156MHz      => '0',
        clk625MHz      => clk625MHz,
        linkUp         => s_singleLinkUp(i),
        enUsrDlyCfg    => enUsrDlyCfg,
        usrDlyCfg      => usrDlyCfg,
        bypFirstBerDet => bypFirstBerDet,
        minEyeWidth    => minEyeWidth,
        lockingCntCfg  => lockingCntCfg,
        txEn           => s_txEn(i),
        txData         => s_txData((8*i)+7 downto (8*i)),
        rxEn           => s_rxEn(i),
        rxErr          => s_rxErr(i),
        rxData         => s_rxData((8*i)+7 downto (8*i)));
  end generate GEN_SALT_LANES;

  s_txEn <= s_singleLinkUp;

  SYNC_LANES : if SYNC_LANES_G generate
    comb : process (rst125MHz, rxR, s_rxData, s_rxEn, s_singleLinkUp,
                    s_rxErr, txData, txEn, txR) is
      variable txV : TxRegType;
      variable rxV : RxRegType;

      variable laneEqual     : slv(NUM_LANES_G-2 downto 0);
      variable txAligned     : slv(NUM_LANES_G-1 downto 0);
      variable baseAlignment : slv(6 downto 0);
    begin  -- process comb
      -- Latch the current value
      txV := txR;
      rxV := rxR;

      -- Reset flags
      laneEqual    := (others => '0');
      txAligned    := (others => '0');
      rxV.rxLocked := '0';
      rxV.txLocked := '0';

      -- Fill the shift register
      for lane in 0 to NUM_LANES_G-1 loop
        for stage in SHIFT_ARRAY_LENGTH_G-1 downto 1 loop
          rxV.shiftRegister(lane, stage) := rxR.shiftRegister(lane, stage-1);
        end loop;  -- stage
        rxV.shiftRegister(lane, 0) := s_rxData((8*lane)+7 downto (8*lane));
      end loop;  -- lane

      -- TX FSM
      case txR.state is
        -------------------------------------------------------------------------
        when IDLE_S =>
          txV.txData := (others => K_28_5_C);
          -- Check if all the links are locked
          if and_reduce(s_singleLinkUp) = '1' then
            txV.state := MOVE_S;
          end if;
        -----------------------------------------------------------------------
        when MOVE_S =>
          for lane in 0 to NUM_LANES_G-1 loop
            -- Send lane aligment flag if RX locked
            if rxR.rxLocked = '1' then
              txV.txData(lane)(7) := '1';
            else
              txV.txData(lane)(7) := '0';
            end if;
            -- Reserved
            txV.txData(lane)(6 downto 4) := (others => '0');
            -- Send index on LSBs
            txV.txData(lane)(3 downto 0) := txR.index;
          end loop;  -- lane
          -- Update index
          txV.index := std_logic_vector(unsigned(txR.index) + 1);
          -- Are the links single locked
          if and_reduce(s_singleLinkUp) = '0' then
            txV.state := IDLE_S;
          -- Is both TX and RX lane aligned
          elsif rxR.rxLocked = '1' and rxR.txLocked = '1' then
            txV.state := GO_S;
          end if;
        -----------------------------------------------------------------------
        when GO_S =>
          for lane in 0 to NUM_LANES_G-1 loop
            if txEn = '1' then
              txV.txData(lane) := txData((8*lane)+7 downto (8*lane));
            else
              txV.txData(lane) := K_28_5_C;
            end if;
          end loop;  -- lane
        -----------------------------------------------------------------------
        when others =>
          txV.state := IDLE_S;
      -----------------------------------------------------------------------
      end case;

      -- RX FSM
      case rxR.state is
        -------------------------------------------------------------------------
        when IDLE_S =>
          if and_reduce(s_singleLinkUp) = '1' and and_reduce(s_rxEn) = '1' then
            rxV.state := SR_WAIT_S;
          end if;
        -----------------------------------------------------------------------
        when SR_WAIT_S =>
          -- Check the counter
          if rxR.srWaitCnt = SR_WAIT_C-1 then
            -- Reset the counter
            rxV.srWaitCnt := 0;
            -- Go to next state
            rxV.state     := SYNC_S;
          else
            -- Increment the counter
            rxV.srWaitCnt := rxR.srWaitCnt + 1;
          end if;
        -----------------------------------------------------------------------
        when SYNC_S =>
          -- Check if lanes are equalized
          for i in 0 to NUM_LANES_G-2 loop
            if rxR.shiftRegister(i, rxR.shiftIndex(i)) = rxR.shiftRegister(i+1, rxR.shiftIndex(i+1)) then
              laneEqual(i) := '1';
            else
              laneEqual(i) := '0';
            end if;
          end loop;  -- i
          -- Lanes are equalized
          if and_reduce(laneEqual) = '1' then
            rxV.state := RX_LOCKED_S;
          -- Lanes are not equalized
          else
            rxV.state := ALIGN_S;
          end if;
        -----------------------------------------------------------------------
        when ALIGN_S =>
          -- Wait until lane 0 is in the middle of pattern
          if rxR.shiftRegister(0, 0)(3 downto 0) = x"8" then
            -- Check how to adjust the other lanes
            for la in NUM_LANES_G-1 downto 1 loop
              rxV.shiftIndex(la) := rxR.shiftIndex(la) + to_integer(signed(rxR.shiftRegister(la, 0)(3 downto 0)) - 8);
            end loop;  -- i
            rxV.state := SYNC_S;
          end if;
        -----------------------------------------------------------------------
        when RX_LOCKED_S =>
          rxV.rxLocked := '1';
          for i in 0 to NUM_LANES_G-1 loop
            if rxR.shiftRegister(i, rxR.shiftIndex(i))(7) = '1' then
              txAligned(i) := '1';
            else
              txAligned(i) := '0';
            end if;
          end loop;  -- i
          if and_reduce(txAligned) = '1' then
            rxV.state := TXRX_LOCKED_S;
          end if;
        -----------------------------------------------------------------------
        when TXRX_LOCKED_S =>
          rxV.txLocked := '1';
          rxV.rxLocked := '1';
          if and_reduce(s_singleLinkUp) = '0' then
            rxV.state := IDLE_S;
          end if;
        -----------------------------------------------------------------------
        when others =>
          rxV.state := IDLE_S;
      -----------------------------------------------------------------------
      end case;

      -- Outputs
      for i in 0 to NUM_LANES_G-1 loop
        s_txData((8*i)+7 downto (8*i)) <= txR.txData(i);
        rxData((8*i)+7 downto (8*i))   <= rxR.shiftRegister(i, rxR.shiftIndex(i));
      end loop;  -- i
      singleLinkUp <= s_singleLinkUp;
      linkUp       <= rxR.txLocked and rxR.rxLocked;
      rxEn         <= and_reduce(s_rxEn);
      rxErr        <= or_reduce(s_rxErr);

      -- Reset
      if (rst125MHz = '1') then
        txV := TX_REG_INIT_C;
        rxV := RX_REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      txRin <= txV;
      rxRin <= rxV;

    end process comb;
  end generate SYNC_LANES;

  NO_SYNC_LANES : if (not SYNC_LANES_G) generate
    comb : process (rst125MHz, rxR, s_rxData, s_rxEn, s_singleLinkUp,
                    s_rxErr, txData, txEn, txR) is
      variable txV : TxRegType;
      variable rxV : RxRegType;

      variable laneEqual     : slv(NUM_LANES_G-2 downto 0);
      variable txAligned     : slv(NUM_LANES_G-1 downto 0);
      variable baseAlignment : slv(6 downto 0);
    begin  -- process comb
      -- Latch the current value
      txV := txR;
      rxV := rxR;

      -- Reset flags
      laneEqual    := (others => '0');
      txAligned    := (others => '0');
      rxV.rxLocked := '0';
      rxV.txLocked := '0';

      -- TX FSM
      case txR.state is
        -------------------------------------------------------------------------
        when IDLE_S =>
          txV.txData := (others => K_28_5_C);
          -- Check if all the links are locked
          if and_reduce(s_singleLinkUp) = '1' then
            txV.state := GO_S;
          end if;
        -----------------------------------------------------------------------
        when GO_S =>
          for lane in 0 to NUM_LANES_G-1 loop
            if txEn = '1' then
              txV.txData(lane) := txData((8*lane)+7 downto (8*lane));
            else
              txV.txData(lane) := K_28_5_C;
            end if;
          end loop;  -- lane
        -----------------------------------------------------------------------
        when others =>
          txV.state := IDLE_S;
      -----------------------------------------------------------------------
      end case;

      -- RX FSM
      case rxR.state is
        -------------------------------------------------------------------------
        when IDLE_S =>
          if and_reduce(s_singleLinkUp) = '1' and and_reduce(s_rxEn) = '1' then
            rxV.state := TXRX_LOCKED_S;
          end if;
        -----------------------------------------------------------------------
        when TXRX_LOCKED_S =>
          rxV.txLocked := '1';
          rxV.rxLocked := '1';
          if and_reduce(s_singleLinkUp) = '0' then
            rxV.state := IDLE_S;
          end if;
        -----------------------------------------------------------------------
        when others =>
          rxV.state := IDLE_S;
      -----------------------------------------------------------------------
      end case;

      -- Outputs
      for i in 0 to NUM_LANES_G-1 loop
        s_txData((8*i)+7 downto (8*i)) <= txR.txData(i);
        rxData((8*i)+7 downto (8*i))   <= rxR.shiftRegister(i, rxR.shiftIndex(i));
      end loop;  -- i
      singleLinkUp <= s_singleLinkUp;
      linkUp       <= rxR.txLocked and rxR.rxLocked;
      rxEn         <= and_reduce(s_rxEn);
      rxErr        <= or_reduce(s_rxErr);

      -- Reset
      if (rst125MHz = '1') then
        txV := TX_REG_INIT_C;
        rxV := RX_REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      txRin <= txV;
      rxRin <= rxV;

    end process comb;
  end generate NO_SYNC_LANES;

  seq : process (clk125MHz) is
  begin
    if rising_edge(clk125MHz) then
      txR <= txRin after TPD_G;
      rxR <= rxRin after TPD_G;
    end if;
  end process seq;

end architecture rtl;
