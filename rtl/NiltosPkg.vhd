-------------------------------------------------------------------------------
-- Title      : NILToS Pkg
-- Project    : 
-------------------------------------------------------------------------------
-- File       : NiltosPkg.vhd<src>
-- Author     : Filippo Marini  <filippo.marini@pd.infn.it>
-- Company    : INFN Padova
-- Created    : 2025-02-18
-- Last update: 2025-02-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2025 INFN Padova
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2025-02-18  1.0      fmarini	Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

package NiltosPkg is

  constant NUM_LANES_C : positive := 8;

  subtype LanesType is std_logic_vector(NUM_LANES_C-1 downto 0);
  subtype LanesDataType is std_logic_vector((8*NUM_LANES_C)-1 downto 0);
  type NiltosLinksType is array (natural range <>) of LanesType;
  type NiltosLinksDataType is array (natural range <>) of LanesDataType;

end package NiltosPkg;
