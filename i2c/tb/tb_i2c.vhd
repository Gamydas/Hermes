----------------------------------------------------------------------------
--  % NAME        : tb_i2c.vhd %
--  % PROJECT     : Hermes I2C Master %
--  % VERSION     : 1.0 %
--  % CREATED_BY  : Samy Gad %
--  % DATE_CREATED: 2026-11-17 %
--                                                                        --
--  DESCRIPTION:                                                          --
--  - description
--                                                                        --
----------------------------------------------------------------------------
--  REVISION HISTORY                                                      --
--                                                                        --
--  VERSION    DATE        SIGN      CHANGE DESCRIPTION                   --
--  ------- ----------  ----------   ------------------                   --
--  1.0     2026-11-17  Gamy   Initial version.
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

LIBRARY VUNIT_LIB;
CONTEXT VUNIT_LIB.VUNIT_CONTEXT;

LIBRARY SRC_LIB;

LIBRARY TB_LIB;

USE TB_LIB.generic_procedures.ALL;

----------------------------------------------------------------------------
-- ENTITY DECLARATION.
----------------------------------------------------------------------------
  ENTITY tb_i2c IS
    GENERIC(runner_cfg : string := runner_cfg_default;
            sys_freq: integer := 125_000_000;
            scl_freq: integer := 100_000);
  END ENTITY;

----------------------------------------------------------------------------
-- ARCHITECTURE DECLARATION.
----------------------------------------------------------------------------
ARCHITECTURE tb OF tb_i2c IS

  --------------------------------------------------------------------------
  -- ALIASES DECLARATION.
  --------------------------------------------------------------------------

  --------------------------------------------------------------------------
  -- FUNCTIONS/PROCEDURES DECLARATION.
  --------------------------------------------------------------------------

  --------------------------------------------------------------------------
  -- COMPONENTS DECLARATION.
  --------------------------------------------------------------------------

  --------------------------------------------------------------------------
  -- TYPES, RECORDS, INTERNAL SIGNALS, FSM, CONSTANTS DECLARATION.
  --------------------------------------------------------------------------
  -- CONSTANTS DECLARATION --
  -- simulation constants
  CONSTANT C_CLK_PERIOD : time := 1 sec / sys_freq; 
  --CONSTANT C_SCL_PERIOD : time := 1 sec / scl_freq;

  -- Arrays to store read and write data in
  TYPE byte_array IS ARRAY (NATURAL RANGE <>) of STD_LOGIC_VECTOR(7 DOWNTO 0);

  -- data that slave sends to master
  CONSTANT R_BYTES : byte_array(3 DOWNTO 0) := (x"A1", x"B2", x"C3", x"D4");
  SIGNAL r_idx : INTEGER RANGE 0 TO  R_BYTES'high := 0; -- integer exactly th size of R_bytes length
  
  -- data that slave receives
  SIGNAL w_bytes : byte_array(3 DOWNTO 0) := (OTHERS => (OTHERS => '0'));
  SIGNAL w_idx : INTEGER RANGE 0 TO  w_bytes'length := 0; -- integer exactly th size of R_bytes length
  
  -- data that master sends
  SIGNAL m_w_bytes : byte_array(3 DOWNTO 0) := (OTHERS => (OTHERS => '0'));
  SIGNAL m_w_idx : INTEGER RANGE 0 TO  m_w_bytes'length := 0; -- integer exactly th size of R_bytes length
  
  SIGNAL m_r_bytes : byte_array(3 DOWNTO 0) := (OTHERS => (OTHERS => '0'));
  SIGNAL m_r_idx : INTEGER RANGE 0 TO  m_r_bytes'length := 0; -- integer exactly th size of R_bytes length
  
  -- SCL Monitor

  --VARIABLE start_time : time := 0 ns;
  --VARIABLE stop_time  : time := 0 ns;

  -- INTERNAL SIGNALS DECLARATION --
  -- Master Interface
  SIGNAL clk             : STD_LOGIC                    := '0';
  SIGNAL rst             : STD_LOGIC                    := '1';
  SIGNAL m_busy          : STD_LOGIC                    := '0';
  SIGNAL m_sl_nack       : STD_LOGIC                    := '0'; 
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
  SIGNAL SDA : STD_LOGIC;
  SIGNAL SCL : STD_LOGIC;
 
  SIGNAL nack_flag : STD_LOGIC;


BEGIN  -- start of architecture --
  --------------------------------------------------------------------------
  -- DUT INSTANTIATION.
  --------------------------------------------------------------------------
  master: ENTITY SRC_LIB.i2c_master(rtl)
    GENERIC MAP(sys_freq => sys_freq, 
                scl_freq => scl_freq)
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
      SDA => SDA,
      SCL => SCL);

  slave: ENTITY TB_LIB.i2c_minion(arch)
    GENERIC MAP (
      minion_addr => SL_ADDR,
      use_input_debouncing => false,
      debouncing_wait_cycles => 0)

    PORT MAP(
      scl => SCL,
      sda => SDA,
      clk => clk,
      rst => rst,
      read_req => sl_req,
      data_to_master => sl_w_data,
      data_valid => sl_data_val,
      data_from_master => sl_r_data);
  
    
    

  --------------------------------------------------------------------------
  -- SIGNAL DEFINITION OF UNUSED OUTPUT PORTS AND FIXED SIGNALS.
  --------------------------------------------------------------------------
  SDA <= 'H'; -- Pull up
  SCL <= 'H'; -- Pull up
  --------------------------------------------------------------------------
  -- CLOCK AND RESET.
  --------------------------------------------------------------------------
  clk   <= NOT clk after C_CLK_PERIOD / 2;

  --------------------------------------------------------------------------
  --------------------------------------------------------------------------
  -------------------------- TEST_RUNNER PROCESS ---------------------------
  --------------------------------------------------------------------------
  --------------------------------------------------------------------------

  test_runner_watchdog(runner, 10 ms);
  test_runner : PROCESS
    -- VARIABLE DECLARATION.

    -- FUNCTIONS/PROCEDURES DECLARATION.
           

  -- procedure to start an i2c write transaction
  PROCEDURE i2c_write(CONSTANT PnSr: STD_LOGIC;
                      CONSTANT Addr: STD_LOGIC_VECTOR(6 DOWNTO 0);
                      CONSTANT w_amt: STD_LOGIC_VECTOR(6 DOWNTO 0);
                      CONSTANT data: byte_array(3 DOWNTO 0);
                      SIGNAL start: OUT STD_LOGIC) is
  BEGIN
    m_pnsr <= PnSr;
    m_addr <= Addr;
    m_w_amt <= w_amt;
    m_w_bytes <= data;
    WAIT FOR 1 ps;
    -- pulse start 
    start <= '1'; 
    WAIT UNTIL rising_edge(clk);
    wait FOR 1 ps;
    start <= '0';
    WAIT FOR 1 ps;
  END PROCEDURE;
   
  -- procedure to start an i2c read transaction
  PROCEDURE i2c_read(CONSTANT PnSr: STD_LOGIC;
                     CONSTANT Addr: STD_LOGIC_VECTOR(6 DOWNTO 0);
                     CONSTANT r_amt: STD_LOGIC_VECTOR(6 DOWNTO 0);
                     SIGNAL start: OUT STD_LOGIC) IS
  BEGIN
    m_pnsr <= PnsR;
    m_addr <= Addr;
    m_r_amt <= r_amt;
    -- pulse start 
    start <= '1'; 
    WAIT UNTIL rising_edge(clk);
    wait for 1 ps;
    start <= '0'; 
  END PROCEDURE;

  PROCEDURE test_addr(CONSTANT Addr: STD_LOGIC_VECTOR(6 DOWNTO 0);
                      SIGNAL start: OUT STD_LOGIC) IS
  BEGIN
    m_pnsr <= '1';
    m_addr <= Addr;
    m_r_amt <= (OTHERS => '0');
    m_w_amt <= (OTHERS => '0');
    -- pulse start 
    start <= '1'; 
    WAIT UNTIL rising_edge(clk);
    wait for 1 ps;
    start <= '0';
    WAIT FOR 1 ps;
  END PROCEDURE;

  BEGIN
    -- setup VUnit
    test_runner_setup(runner, runner_cfg);
    -- tests are not cancelled after they fail one check
    set_stop_level(failure);
    -- enable logging for passing checks
    show(get_logger(default_checker), display_handler, pass);
    reset_dut(rst, clk);
    test_cases_loop : WHILE test_suite LOOP

      ----------------------------------------------------------------------
      -- TEST CASE DESCRIPTION:
      -- Master sends the Slaves address, waits for ACK and then stops 
      -- transaction
      -- Expected Result: 
      -- Slave acknowledges address and transmission ends without error
      ----------------------------------------------------------------------
      IF run("addr_no_data") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: addr_no_data");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        -- set transition type to stop, address to slave and counters to 0
        test_addr(SL_ADDR, m_S);
        -- wait for transaction end
        IF (m_busy = '1') THEN
          WAIT UNTIL m_busy = '0';
        END IF;
        WAIT FOR 1 ps;
        info("===== TEST CASE FINISHED =====");
      ELSIF run("Transmit_one_byte") THEN 
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: transmit_one_byte");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        i2c_write('1', SL_ADDR, std_logic_vector(to_unsigned(1, m_w_amt'length)), (x"A1", x"FF", x"32", x"10"), m_S);
        IF (m_busy = '1') THEN
          report "waiting on master";
          WAIT UNTIL m_busy = '0';
        END IF;
        report "master returned";
        WAIT FOR 1 ps;
        check_equal(w_bytes(0), std_logic_vector'(x"10"), result("For slave read buffer"));
        check(nack_flag = '0', "Expected no NACK");
        info("===== TEST CASE FINISHED =====");
      ELSIF run("Transmit_multiple_bytes") THEN 
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: transmit_multiple_bytes");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        i2c_write('1', SL_ADDR, std_logic_vector(to_unsigned(4, m_w_amt'length)), (x"A1", x"FF", x"32", x"10"), m_S);
        IF (m_busy = '1') THEN
          WAIT UNTIL m_busy = '0';
        END IF;
        WAIT FOR 1 ps;
        check_equal(w_bytes(0), std_logic_vector'(x"10"), result("For slave read buffer pos(0)"));
        check_equal(w_bytes(1), std_logic_vector'(x"32"),  result("For slave read buffer pos(1)"));
        check_equal(w_bytes(2), std_logic_vector'(x"FF"), result("For slave read buffer pos(2)"));
        check_equal(w_bytes(3), std_logic_vector'(x"A1"),  result("For slave read buffer pos(3)"));
        check(nack_flag = '0', "Expected no NACK");
        info("===== TEST CASE FINISHED =====");
      ELSIF run("read_one_byte") THEN 
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: read_one_byte");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        i2c_read('1', SL_ADDR, std_logic_vector(to_unsigned(1, m_r_amt'length)), m_S);
        IF (m_busy = '1') THEN
          WAIT UNTIL m_busy = '0';
        END IF;
        WAIT FOR 1 ps;
        check_equal(m_r_bytes(0), std_logic_vector'(x"D4"), result("For master read buffer pos(0)"));
        info("===== TEST CASE FINISHED =====");
      ELSIF run("read_multiple_bytes") THEN 
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: read_multiple_bytes");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        i2c_read('1', SL_ADDR, std_logic_vector(to_unsigned(4, m_r_amt'length)), m_S);
        IF (m_busy = '1') THEN
          WAIT UNTIL m_busy = '0';
        END IF;
        WAIT FOR 1 ps;
        check_equal(m_r_bytes(0), std_logic_vector'(x"D4"), result("For master read buffer pos(0)"));
        check_equal(m_r_bytes(1), std_logic_vector'(x"C3"), result("For master read buffer pos(1)"));
        check_equal(m_r_bytes(2), std_logic_vector'(x"B2"), result("For master read buffer pos(2)"));
        check_equal(m_r_bytes(3), std_logic_vector'(x"A1"), result("For master read buffer pos(3)"));
        info("===== TEST CASE FINISHED =====");
      END IF; -- for test_suite
    END LOOP test_cases_loop;

    WAIT FOR 20 ns;
    test_runner_cleanup(runner); -- end of simulation
  END PROCESS;
  

  --------------------------------------------------------------------------
  -- MONITOR PROCESSES AND CONCURRENT CHECKS.
  --------------------------------------------------------------------------
  --i2c_monitor : PROCESS
  --BEGIN
  --WAIT ON SCL_in, SDA_in;
  --IF (SDA_in'event) THEN
    -- Start Condition
  --  IF (SDA_in = '0' AND SCL_in = '1') THEN 

  --ELSIF (SCL_in'event) THEN
  --  IF (SCL_in = '1') THEN
  --    check_equal()
  --ELSE 

  -- concurrently put data on slave
  sl_w_data <= R_BYTES(r_idx);
  sl_read_proc: PROCESS(clk, rst)
  BEGIN
    IF (rst = '1') THEN
      r_idx <= 0;
    ELSIF clk = '1' AND clk'event THEN
      IF sl_req = '1' AND r_idx < R_BYTES'high THEN
        r_idx <= r_idx + 1;
      END IF;
    END IF;
  END PROCESS;

  sl_write_proc: PROCESS(clk, rst)
  BEGIN
    IF (rst = '1') THEN
      w_idx <= 0;
      w_bytes <= (OTHERS => (OTHERS => '0'));
    ELSIF clk = '1' AND clk'event THEN
      IF sl_data_val = '1' AND w_idx < w_bytes'length THEN
        w_bytes(w_idx) <= sl_r_data;
        w_idx <= w_idx + 1;
      END IF;
    END IF;
  END PROCESS;

  -- process pushes new data every time master has loaded a byte
  m_data_i <= m_w_bytes(m_w_idx);
  m_write_proc: PROCESS(clk, rst) 
  BEGIN
    IF (rst = '1') THEN
      m_w_idx <= 0;
    ELSIF clk = '1' AND clk'event THEN
      -- master loaded last byte
      IF (m_data_load = '1' AND m_w_idx < m_w_bytes'high) THEN
        m_w_idx <= m_w_idx + 1;
      END IF;
    END IF;
  END PROCESS;

  -- process reads stores data that master read
  m_read_proc: PROCESS(clk, rst)
  BEGIN 
    IF (rst = '1') THEN 
      m_r_bytes <= (OTHERS => (OTHERS => '0'));
      m_r_idx <= 0;
    ELSIF clk = '1' AND clk'event THEN 
      IF (m_r_valid = '1' AND m_r_idx < m_r_bytes'length) THEN 
        m_r_bytes(m_r_idx) <= m_data_o;
        m_r_idx <= m_r_idx + 1;
      END IF;
    END IF;
  END PROCESS;

  ack_monitor: PROCESS(clk, rst)
  BEGIN
    IF rst = '1' THEN
      nack_flag <= '0';
    ELSIF clk = '1' AND clk'event THEN
      IF m_sl_nack = '1' THEN
        nack_flag <= '1';
      END IF;
    END IF;
  END PROCESS;

END ARCHITECTURE;
