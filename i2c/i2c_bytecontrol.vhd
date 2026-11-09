----------------------------------------------------------------------------
--  % NAME        : i2c_bytecontrol.vhd %
--  % PROJECT     : hermes %
--  % VERSION     : 1.0 %
--  % CREATED_BY  : Samy Gad %
--  % DATE_CREATED: 2026-11-07 %
--                                                                        --
--  DESCRIPTION:                                                          --
--  Byte Controller for an I2C Master

--                                                                        --
----------------------------------------------------------------------------
--  REVISION HISTORY                                                      --
--                                                                        --
--  VERSION    DATE        SIGN      CHANGE DESCRIPTION                   --
--  ------- ----------  ----------   ------------------                   --
--  1.0     2026-11-07  Gamy   Initial version.
--                                                                        --


----------------------------------------------------------------------------
-- CONFIGURATION DECLARATION.
----------------------------------------------------------------------------

----------------------------------------------------------------------------
-- LIBRARY DECLARATION.
----------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


----------------------------------------------------------------------------
-- ENTITY DECLARATION.
----------------------------------------------------------------------------
  ENTITY i2c_bytecontrol IS
    PORT(clk: IN  STD_LOGIC;
         rst: IN  STD_LOGIC;
         -- message signals
         poll: IN STD_LOGIC;
         send: IN STD_LOGIC;
         address: IN STD_LOGIC;
         data: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         ack: OUT STD_LOGIC;
         -- Signals for communication with top level
         load: OUT STD_LOGIC;
         -- Signals for communication with bit controller  
         bit_i: IN STD_LOGIC;
         bit_o: OUT STD_LOGIC;
         cmd: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         bit_done: IN STD_LOGIC; 
    );
  END ENTITY;

----------------------------------------------------------------------------
-- ARCHITECTURE DECLARATION.
----------------------------------------------------------------------------
ARCHITECTURE rtl OF i2c_bytecontrol IS

  --------------------------------------------------------------------------
  -- TYPES, RECORDS, INTERNAL SIGNALS, FSM, CONSTANTS DECLARATION.
  --------------------------------------------------------------------------
  

  --------------------------------------------------------------------------
  -- COMPONENTS DECLARATION
  --------------------------------------------------------------------------



BEGIN  -- start of architecture --


  --------------------------------------------------------------------------
  -- COMPONENTS INSTANTIATION
  --------------------------------------------------------------------------


  --------------------------------------------------------------------------
  -- COMBINATIONAL LOGIC
  --------------------------------------------------------------------------

  
  --------------------------------------------------------------------------
  -- SEQUENTIAL LOGIC
  --------------------------------------------------------------------------


  --------------------------------------------------------------------------
  -- OUTPUTS ASSIGNMENT
  --------------------------------------------------------------------------
  


END ARCHITECTURE;
