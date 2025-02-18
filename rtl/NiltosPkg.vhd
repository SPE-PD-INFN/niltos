-------------------------------------------------------------------------------
-- Title      : NILToS Pkg
-- Project    : 
-------------------------------------------------------------------------------
-- File       : NiltosPkg.vhd<src>
-- Author     : Filippo Marini  <filippo.marini@pd.infn.it>
-- Company    : INFN Padova
-- Created    : 2025-02-18
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
-- 2025-02-18  1.0      fmarini	Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

package NiltosPkg is

  type NiltosLinksType is array (natural range <>) of std_logic_vector(natural range <>);

end package NiltosPkg;
