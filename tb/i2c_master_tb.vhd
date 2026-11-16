----------------------------------------------------------------------------
--  % NAME        : i2c_master_tb.vhd %
--  % PROJECT     : Hermes I2C Master Testbench %
--  % VERSION     : 1.0 %
--  % CREATED_BY  : Samy Gad %
--  % DATE_CREATED: 2026-11-16 %
--                                                                        --
--  DESCRIPTION:                                                          --
--  Testbench for an I2C Master using the Open Source FPGA I2C Minion
--  Module by Peter Samarin <peter.samarin@gmail.com>
--                                                                        --
----------------------------------------------------------------------------
--  REVISION HISTORY                                                      --
--                                                                        --
--  VERSION    DATE        SIGN      CHANGE DESCRIPTION                   --
--  ------- ----------  ----------   ------------------                   --
--  1.0     2026-11-16  Gamy   Initial version.
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

ENTITY i2c_master_tb IS
END ENTITY;

----------------------------------------------------------------------------
-- ARCHITECTURE DECLARATION.
----------------------------------------------------------------------------

ARCHITECTURE tb OF i2c_master_tb IS

  --------------------------------------------------------------------------
  -- FUNCTIONS/PROCEDURES DECLARATION.
  --------------------------------------------------------------------------

  --------------------------------------------------------------------------
  -- COMPONENTS DECLARATION.
  --------------------------------------------------------------------------
  COMPONENT i2c_master IS
    GENERIC(
      sys_freq : INTEGER := 125_000_000;
      scl_freq : INTEGER := 100_000);
    PORT(
      clk           : IN    STD_LOGIC;
      rst           : IN    STD_LOGIC;
      busy          : OUT   STD_LOGIC;                    -- Signals that a transaction is happening
      sl_nack       : OUT   STD_LOGIC;                    -- Signals slave not acknowleding transaction
      addr          : IN    STD_LOGIC_VECTOR(6 DOWNTO 0); -- addr gets loaded here, addr & rw makes address byte
      PnSr          : IN    STD_LOGIC;
      S             : IN    STD_LOGIC;                    -- Stop/(not reapeat) and start signals for transitions
      w_amt         : IN    STD_LOGIC_VECTOR(6 DOWNTO 0);
      r_amt         : IN    STD_LOGIC_VECTOR(6 DOWNTO 0); -- Amount of bytes that are written/read in this transaction
      data_i        : IN    STD_LOGIC_VECTOR(7 DOWNTO 0); -- data that is to be written
      data_o        : OUT   STD_LOGIC_VECTOR(7 DOWNTO 0); -- data that has been read
      r_valid       : OUT   STD_LOGIC;                    -- Signals read data is valid now
      data_load     : OUT   STD_LOGIC;
      addr_cnt_load : OUT   STD_LOGIC;                    -- Signals when and which information has been loaded
      SDA           : INOUT STD_LOGIC;                    -- open drain data line
      SCL           : INOUT STD_LOGIC);                   -- open drain, no clock stretching supported yet
  END COMPONENT;

  COMPONENT I2C_minion IS
    GENERIC(
      MINION_ADDR : STD_LOGIC_VECTOR(6 DOWNTO 0);
      -- noisy SCL/SDA lines can confuse the minion
      -- use low-pass filter to smooth the signal
      -- (this might not be necessary!)
      USE_INPUT_DEBOUNCING : BOOLEAN := false;
      -- play with different number of wait cycles
      -- larger wait cycles increase the resource usage
      DEBOUNCING_WAIT_CYCLES : INTEGER := 4);
    PORT(
      scl : INOUT STD_LOGIC;
      sda : INOUT STD_LOGIC;
      clk : IN    STD_LOGIC;
      rst : IN    STD_LOGIC;
      -- User interface
      read_req         : OUT   STD_LOGIC;
      data_to_master   : IN    STD_LOGIC_VECTOR(7 DOWNTO 0);
      data_valid       : OUT   STD_LOGIC;
      data_from_master : OUT   STD_LOGIC_VECTOR(7 DOWNTO 0));
  END COMPONENT;

  --------------------------------------------------------------------------
  -- TYPES, RECORDS, INTERNAL SIGNALS, FSM, CONSTANTS DECLARATION.
  --------------------------------------------------------------------------
  -- CONSTANTS DECLARATION --
  -- simulation constants
  CONSTANT C_CLK_PERIOD : TIME := 20 ns;


  -- TYPES DECLARATION --

  -- INTERNAL SIGNALS DECLARATION --
  -- Master Interface
  SIGNAL clk             : STD_LOGIC                    := '0';
  SIGNAL rst             : STD_LOGIC                    := '1';
  SIGNAL m_busy          : STD_LOGIC                    := '0';
  SIGNAL m_sl_nack       : STD_LOGIC                    := '1'; -- nack as default
  SIGNAL m_addr          : STD_LOGIC_VECTOR(6 DOWNTO 0);
  SIGNAL m_PnSr          : STD_LOGIC                    := '0'; -- stop as default
  SIGNAL m_S             : STD_LOGIC                    := '0'; -- NOT Start as default
  SIGNAL m_w_amt         : STD_LOGIC_VECTOR(6 DOWNTO 0) := (OTHERS => '0');
  SIGNAL m_r_amt         : STD_LOGIC_VECTOR(6 DOWNTO 0) := (OTHERS => '0');
  SIGNAL m_data_i        : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL m_data_o        : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
  SIGNAL m_r_valid       : STD_LOGIC                    := '0'; -- NOT valid as defauklt
  SIGNAL m_data_load     : STD_LOGIC                    := '0'; -- NOT loaded as default
  SIGNAL m_addr_cnt_load : STD_LOGIC                    := '0';

  -- Slave Interface
  SIGNAL sl_req      : STD_LOGIC                    := '0';
  SIGNAL SL_ADDR     : STD_LOGIC_VECTOR(6 DOWNTO 0) := "0000011";
  SIGNAL sl_w_data   : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
  SIGNAL sl_data_val : STD_LOGIC;
  SIGNAL sl_r_data   : STD_LOGIC_VECTOR(7 DOWNTO 0);
  -- I2C Lines
  SIGNAL SDA_sig : STD_LOGIC;
  SIGNAL SCL_sig : STD_LOGIC;
-- simulation signals


BEGIN  -- start of architecture --

  --------------------------------------------------------------------------
  -- DUT INSTANTIATION.
  --------------------------------------------------------------------------
  master: i2c_master
    GENERIC MAP (
      sys_freq => 50_000_000,
      scl_freq => 100_000)
    PORT MAP(
      clk => clk,
      rst => rst,
      busy => m_busy,
      sl_nack => m_sl_nack,
      addr => m_addr,
      PnSr => m_PnSr,
      S => m_S,
      w_amt => m_w_amt,
      r_amt => m_r_amt,
      data_i => m_data_i,
      data_o => m_data_o,
      r_valid => m_r_valid,
      data_load => m_data_load,
      addr_cnt_load => m_addr_cnt_load,
      SDA => SDA_sig,
      SCL => SCL_sig);

  slave: i2c_minion
    GENERIC MAP (
      minion_addr => SL_ADDR,
      use_input_debouncing => false,
      debouncing_wait_cycles => 0)

    PORT MAP(
      scl => SCL_sig,
      sda => SDA_sig,
      clk => clk,
      rst => rst,
      read_req => sl_req,
      data_to_master => sl_w_data,
      data_valid => sl_data_val,
      data_from_master => sl_r_data);

  --------------------------------------------------------------------------
  -- SIGNAL DEFINITION OF UNUSED OUTPUT PORTS AND FIXED SIGNALS.
  --------------------------------------------------------------------------


  --------------------------------------------------------------------------
  -- CLOCK AND RESET.
  --------------------------------------------------------------------------
  clk   <= NOT clk AFTER C_CLK_PERIOD / 2;

  --------------------------------------------------------------------------
  -- MONITOR PROCESSES AND CONCURRENT CHECKS.
  --------------------------------------------------------------------------
  

END ARCHITECTURE;
