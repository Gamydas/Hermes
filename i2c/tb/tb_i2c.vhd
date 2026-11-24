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
  GENERIC(
    runner_cfg : STRING  := runner_cfg_default;
    sys_freq   : INTEGER := 125_000_000;
    scl_freq   : INTEGER := 100_000;
    thd_sta    : INTEGER := 4000;
    tsu_sta    : INTEGER := 4700;
    tsu_sto    : INTEGER := 4000;
    t_buf      : INTEGER := 4700;
    tsu_dat    : INTEGER := 250;
    t_low      : INTEGER := 4700;
    t_high     : INTEGER := 4000);
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
  CONSTANT C_CLK_PERIOD : TIME := 1 sec / sys_freq;
  CONSTANT C_THD_STA    : TIME := thd_sta * 1 ns;
  CONSTANT C_TSU_STA    : TIME := tsu_sta * 1 ns;
  CONSTANT C_TSU_STO    : TIME := tsu_sto * 1 ns;
  CONSTANT C_T_BUF      : TIME := t_buf   * 1 ns;
  CONSTANT C_T_LOW      : TIME := t_low   * 1 ns;
  CONSTANT C_T_HIGH     : TIME := t_high  * 1 ns;
  CONSTANT C_TSU_DAT    : TIME := tsu_dat * 1 ns;

  -- Arrays to store read and write data in
  TYPE byte_array IS ARRAY(NATURAL RANGE <>) OF STD_LOGIC_VECTOR(7 DOWNTO 0);

  -- data that slave sends to master
  CONSTANT SL_W_BYTES : byte_array(15 DOWNTO 0)         := (x"FF", x"FE", x"FD", x"FC", x"FB", x"FA", x"F9", x"F8", x"F7", x"F6", x"F5", x"F4", x"A1", x"B2", x"C3", x"D4");
  SIGNAL   sl_w_idx   : INTEGER RANGE 0 TO SL_W_BYTES'HIGH := 0; -- integer exactly the size of w_bytes length

  -- data that slave receives
  SIGNAL sl_r_bytes : byte_array(15 DOWNTO 0)           := (OTHERS => (OTHERS => '0'));
  SIGNAL sl_r_idx   : INTEGER RANGE 0 TO sl_r_bytes'LENGTH := 0; -- integer exactly the size of w_bytes length

  -- data that master sends
  SIGNAL m_w_bytes : byte_array(15 DOWNTO 0)             := (OTHERS => (OTHERS => '0'));
  SIGNAL m_w_idx   : INTEGER RANGE 0 TO m_w_bytes'LENGTH := 0; -- integer exactly the size of m_w_bytes length

  SIGNAL m_r_bytes : byte_array(15 DOWNTO 0)             := (OTHERS => (OTHERS => '0'));
  SIGNAL m_r_idx   : INTEGER RANGE 0 TO m_r_bytes'LENGTH := 0; -- integer exactly the size of m_r_bytes length

  -- SCL Monitor

  -- VARIABLE start_time : time := 0 ns;
  -- VARIABLE stop_time  : time := 0 ns;

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
  SIGNAL SL_ADDR     : STD_LOGIC_VECTOR(6 DOWNTO 0) := "0011010";
  SIGNAL sl_w_data   : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
  SIGNAL sl_data_val : STD_LOGIC;
  SIGNAL sl_r_data   : STD_LOGIC_VECTOR(7 DOWNTO 0);
  -- I2C Lines
  SIGNAL SDA    : STD_LOGIC;
  SIGNAL SCL    : STD_LOGIC;
  SIGNAL SDA_in : STD_LOGIC;
  SIGNAL SCL_in : STD_LOGIC;

  SIGNAL nack_flag : STD_LOGIC;

  -- Timing Constraints
  -- SIGNAL th_s : time := 0 ns;
  -- SIGNAL tsu_sr :time := 0 ns;
  -- SIGNAL tsu_p : time := 0 ns;
  -- SIGNAL tbuf : time := 0 ns;


  -- Test Block for WM8731 Audichip


  -- I2C Daten: 7 Bit Registeradresse plus 9 Datenbits
  CONSTANT i2c_data : byte_array(15 DOWNTO 0) :=
 (
    "00000001",
 "00010010",
    "00000000",
 "00010010", -- R9  Deaktiviere Audio
    "00000010",
 "00010000", -- R8  Normal mode, 384fs, sr=0 (mclk@18.432mhz, fs=48khz)
    "00000011",
 "00001110", -- R7  Slave, DSP Modus, 16 Bit, msb 1bclk,
    "01100111",
 "00001100", -- R6  DAC on, out on
    "00000000",
 "00001010", -- R5  DAC Mute off
    "00010000",
 "00001000", -- R4  DAC Sel
    "00000000",
 "00011110"  -- R15 Reset Chip
  );


BEGIN  -- start of architecture --

  --------------------------------------------------------------------------
  -- DUT INSTANTIATION.
  --------------------------------------------------------------------------
  master: ENTITY SRC_LIB.i2c_master(rtl)
    GENERIC MAP (
      sys_freq => sys_freq,
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

  SDA_in <= to_x01(SDA);
  SCL_in <= to_x01(SCL);
  --------------------------------------------------------------------------
  -- CLOCK AND RESET.
  --------------------------------------------------------------------------
  clk   <= NOT clk AFTER C_CLK_PERIOD / 2;

  --------------------------------------------------------------------------
  --------------------------------------------------------------------------
  -------------------------- TEST_RUNNER PROCESS ---------------------------
  --------------------------------------------------------------------------
  --------------------------------------------------------------------------

  test_runner_watchdog(runner, 50 ms);

  test_runner: PROCESS

    -- VARIABLE DECLARATION.

    -- FUNCTIONS/PROCEDURES DECLARATION.


    -- procedure to start an i2c write transaction

    PROCEDURE i2c_write (
      CONSTANT PnSr: STD_LOGIC;
      CONSTANT Addr: STD_LOGIC_VECTOR(6 DOWNTO 0);
      CONSTANT w_amt: STD_LOGIC_VECTOR(6 DOWNTO 0);
      CONSTANT data: byte_array(3 DOWNTO 0);
      SIGNAL start: OUT STD_LOGIC
    ) IS
    BEGIN

      m_pnsr <= PnSr;
      m_addr <= Addr;
      m_w_amt <= w_amt;
      m_w_bytes(3 DOWNTO 0) <= data;
      WAIT FOR 1 ps;
      -- pulse start
      start <= '1';
      WAIT UNTIL rising_edge(clk);
      WAIT FOR 1 ps;
      start <= '0';
      WAIT FOR 1 ps;

    END PROCEDURE i2c_write;

    -- procedure to start an i2c read transaction

    PROCEDURE i2c_read (
      CONSTANT PnSr: STD_LOGIC;
      CONSTANT Addr: STD_LOGIC_VECTOR(6 DOWNTO 0);
      CONSTANT r_amt: STD_LOGIC_VECTOR(6 DOWNTO 0);
      SIGNAL start: OUT STD_LOGIC
    ) IS
    BEGIN

      m_pnsr <= PnsR;
      m_addr <= Addr;
      m_r_amt <= r_amt;
      -- pulse start
      start <= '1';
      WAIT UNTIL rising_edge(clk);
      WAIT FOR 1 ps;
      start <= '0';

    END PROCEDURE i2c_read;

    PROCEDURE test_addr (
      CONSTANT Addr: STD_LOGIC_VECTOR(6 DOWNTO 0);
      SIGNAL start: OUT STD_LOGIC
    ) IS
    BEGIN

      m_pnsr <= '1';
      m_addr <= Addr;
      m_r_amt <= (OTHERS => '0');
      m_w_amt <= (OTHERS => '0');
      -- pulse start
      start <= '1';
      WAIT UNTIL rising_edge(clk);
      WAIT FOR 1 ps;
      start <= '0';
      WAIT FOR 1 ps;

    END PROCEDURE test_addr;


    PROCEDURE configure_WM8731 IS
    BEGIN

      m_pnsr <= '1';
      m_addr <= sl_addr;
      m_w_amt <= std_logic_vector(to_unsigned(16, m_w_amt'LENGTH));
      m_w_bytes <= i2c_data;
      WAIT FOR 1 ps;
      m_S <= '1';
      WAIT UNTIL rising_edge(clk);
      WAIT FOR 1 ps;
      m_S <= '0';
      WAIT FOR 1 ps;


    END PROCEDURE configure_WM8731;

    PROCEDURE wait_for_master IS
    BEGIN

      IF (m_busy = '0') THEN
        WAIT UNTIL m_busy = '1' FOR 10 * C_CLK_PERIOD;
      END IF;
      check(m_busy = '1', "Master did not assert busy after start");
      IF (m_busy = '1') THEN
        WAIT UNTIL m_busy = '0';
      END IF;
      WAIT FOR 1 ps;

    END PROCEDURE wait_for_master;

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
        wait_for_master;
        check(nack_flag = '0', "Expected no NACK");
        check_equal(sl_r_idx, 0, "Slave must not report data reception");
        info("===== TEST CASE FINISHED =====");

      ----------------------------------------------------------------------
      -- TEST CASE DESCRIPTION:
      -- Master Transmits one byte over SDA
      -- Expected Result:
      -- Slave acknowledges address and byte and transaction stops without error
      ----------------------------------------------------------------------
      ELSIF run("Transmit_one_byte") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: transmit_one_byte");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        i2c_write('1', SL_ADDR, std_logic_vector(to_unsigned(1, m_w_amt'length)), (x"A1", x"FF", x"32", x"10"), m_S);
        wait_for_master;
        check_equal(sl_r_bytes(0), std_logic_vector'(x"10"), result("For slave read buffer"));
        check_equal(sl_r_idx, 1, "Bytes received by slave");
        check_equal(m_w_idx, 1, "Expected only 1 data_load pulse");
        check(nack_flag = '0', "Expected no NACK");
        info("===== TEST CASE FINISHED =====");

      ----------------------------------------------------------------------
      -- TEST CASE DESCRIPTION:
      -- Master Transmits four byte over SDA
      -- Expected Result:
      -- Slave acknowledges address and all bytes and transaction stops without error
      ----------------------------------------------------------------------
      ELSIF run("Transmit_multiple_bytes") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: transmit_multiple_bytes");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        i2c_write('1', SL_ADDR, std_logic_vector(to_unsigned(4, m_w_amt'length)), (x"A1", x"FF", x"32", x"10"), m_S);
        wait_for_master;
        check_equal(sl_r_idx, 4, "Bytes received by slaved");
        check_equal(m_w_idx, 4, "data_load pulses");
        check_equal(sl_r_bytes(0), std_logic_vector'(x"10"), result("For slave read buffer pos(0)"));
        check_equal(sl_r_bytes(1), std_logic_vector'(x"32"),  result("For slave read buffer pos(1)"));
        check_equal(sl_r_bytes(2), std_logic_vector'(x"FF"), result("For slave read buffer pos(2)"));
        check_equal(sl_r_bytes(3), std_logic_vector'(x"A1"),  result("For slave read buffer pos(3)"));
        check(nack_flag = '0', "Expected no NACK");
        info("===== TEST CASE FINISHED =====");

      ----------------------------------------------------------------------
      -- TEST CASE DESCRIPTION:
      -- Master requests one byte from the slave
      -- Expected Result:
      -- Slave acknowledges address and sends exactly one byte and transaction stops without error
      ----------------------------------------------------------------------
      ELSIF run("read_one_byte") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: read_one_byte");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        i2c_read('1', SL_ADDR, std_logic_vector(to_unsigned(1, m_r_amt'length)), m_S);
        wait_for_master;
        check_equal(m_r_bytes(0), std_logic_vector'(x"D4"), result("For master read buffer pos(0)"));
        check_equal(m_r_idx, 1, "r_valid pulses");
        check(nack_flag = '0', "Expected no NACK");
        info("===== TEST CASE FINISHED =====");

      ----------------------------------------------------------------------
      -- TEST CASE DESCRIPTION:
      -- Master requests four bytes from the slave
      -- Expected Result:
      -- Slave acknowledges address and sends exactly four bytes and transaction stops without error
      ----------------------------------------------------------------------
      ELSIF run("read_multiple_bytes") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: read_multiple_bytes");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        i2c_read('1', SL_ADDR, std_logic_vector(to_unsigned(4, m_r_amt'length)), m_S);
        wait_for_master;
        check_equal(m_r_bytes(0), std_logic_vector'(x"D4"), result("For master read buffer pos(0)"));
        check_equal(m_r_bytes(1), std_logic_vector'(x"C3"), result("For master read buffer pos(1)"));
        check_equal(m_r_bytes(2), std_logic_vector'(x"B2"), result("For master read buffer pos(2)"));
        check_equal(m_r_bytes(3), std_logic_vector'(x"A1"), result("For master read buffer pos(3)"));
        check(nack_flag = '0', "Expected no NACK");
        wait_n_cycles(10000, clk); -- waiting some time to test whether activity happens on the bus during idle
        check_equal(m_r_idx, 4, "r_valid pulses");
        check_equal(sl_w_idx, 4, "Expected slave to write no more than 4 bytes");
        info("===== TEST CASE FINISHED =====");

      ----------------------------------------------------------------------
      -- TEST CASE DESCRIPTION:
      -- Master sends four bytes, then stops -> starts and then another 4 bytes
      -- so the concurrent monitor can check the bus free time constraint
      -- Expected Result:
      -- t_buf is met as required by the i2c specifications
      ----------------------------------------------------------------------
      ELSIF run("test_tbuf") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: test_tbuf");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        i2c_write('1', SL_ADDR, std_logic_vector(to_unsigned(4, m_w_amt'length)), (x"A1", x"FF", x"32", x"10"), m_S);
        wait_for_master;
        check_equal(sl_r_bytes(0), std_logic_vector'(x"10"), result("For slave read buffer pos(0)"));
        check_equal(sl_r_bytes(1), std_logic_vector'(x"32"),  result("For slave read buffer pos(1)"));
        check_equal(sl_r_bytes(2), std_logic_vector'(x"FF"), result("For slave read buffer pos(2)"));
        check_equal(sl_r_bytes(3), std_logic_vector'(x"A1"),  result("For slave read buffer pos(3)"));
        check(nack_flag = '0', "Expected no NACK");
        i2c_read('1', SL_ADDR, std_logic_vector(to_unsigned(4, m_r_amt'length)), m_S);
        wait_for_master;
        check_equal(m_r_bytes(0), std_logic_vector'(x"D4"), result("For master read buffer pos(0)"));
        check_equal(m_r_bytes(1), std_logic_vector'(x"C3"), result("For master read buffer pos(1)"));
        check_equal(m_r_bytes(2), std_logic_vector'(x"B2"), result("For master read buffer pos(2)"));
        check_equal(m_r_bytes(3), std_logic_vector'(x"A1"), result("For master read buffer pos(3)"));
        info("===== TEST CASE FINISHED =====");
   
      ----------------------------------------------------------------------
      -- TEST CASE DESCRIPTION:
      -- Master sends one byte, triggers repeat start and then sends another byte
      -- so the concurrent monitor can check the start setup time constraint
      -- Expected Result:
      -- tsu_sta is met as required by the i2c specifications
      ----------------------------------------------------------------------
      ELSIF run("test_tsu_sta") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: test_tsu_sta");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        i2c_write('0', SL_ADDR, std_logic_vector(to_unsigned(1, m_w_amt'length)), (x"94", x"FF", x"32", x"33"), m_S);
        WAIT ON m_data_load;
        WAIT ON m_addr_cnt_load;
        i2c_write('1', SL_ADDR, std_logic_vector(to_unsigned(1, m_w_amt'length)), (x"A1", x"FF", x"22", x"F0"), m_S);
        wait_for_master;
        check_equal(sl_r_bytes(0), std_logic_vector'(x"33"), result("For slave read buffer pos(0)"));
        check_equal(sl_r_bytes(1), std_logic_vector'(x"22"), result("For slave read buffer pos(0)"));
        check(nack_flag = '0', "Expected no NACK");
        info("===== TEST CASE FINISHED =====");

      ----------------------------------------------------------------------
      -- TEST CASE DESCRIPTION:
      -- Master sends 1 bytes, triggers reapeat start and then requests 4 bytes.
      -- This is important to test as a lot of slaves need to be configured first before
      -- they can send data.
      -- Expected Result:
      -- Exactly one byte is written by the master and exactly 4 bytes are sent by the
      -- slave
      ----------------------------------------------------------------------
      ELSIF run("test_write_sr_read") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: test_write_sr_read");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        i2c_write('0', SL_ADDR, std_logic_vector(to_unsigned(1, m_w_amt'length)), (x"94", x"FF", x"32", x"33"), m_S);
        WAIT ON m_data_load;
        i2c_read('0', SL_ADDR, std_logic_vector(to_unsigned(4, m_r_amt'length)), m_S);
        WAIT ON m_addr_cnt_load;
        m_PnSr <= '1';
        wait_for_master;
        check_equal(sl_r_bytes(0), std_logic_vector'(x"33"), result("For slave read buffer pos(0)"));
        check_equal(m_r_bytes(0), std_logic_vector'(x"D4"), result("For master read buffer pos(0)"));
        check_equal(m_r_bytes(1), std_logic_vector'(x"C3"), result("For master read buffer pos(1)"));
        check_equal(m_r_bytes(2), std_logic_vector'(x"B2"), result("For master read buffer pos(2)"));
        check_equal(m_r_bytes(3), std_logic_vector'(x"A1"), result("For master read buffer pos(3)"));
        check_equal(sl_r_idx, 1, "Bytes received by slave");
        check_equal(m_r_idx, 4, "r_valid pulses");
        info("===== TEST CASE FINISHED =====");

      ----------------------------------------------------------------------
      -- TEST CASE DESCRIPTION:
      -- This test is specifically for the WM8731 Audio Codec chip and simulates
      -- the chips configuration
      -- Expected Result:
      -- All bytes sent are being received and acknowledged
      ----------------------------------------------------------------------
      ELSIF run("WM8731_test") THEN
        configure_WM8731;
        wait_for_master;
        check_equal(sl_r_bytes(0), std_logic_vector'("00011110"), result("For slave read buf(0)"));
        check_equal(sl_r_bytes(1), std_logic_vector'("00000000"), result("For slave read buf(1)"));
        check_equal(sl_r_bytes(2), std_logic_vector'("00001000"), result("For slave read buf(2)"));
        check_equal(sl_r_bytes(3), std_logic_vector'("00010000"), result("For slave read buf(3)"));
        check_equal(sl_r_bytes(4), std_logic_vector'("00001010"), result("For slave read buf(4)"));
        check_equal(sl_r_bytes(5), std_logic_vector'("00000000"), result("For slave read buf(5)"));
        check_equal(sl_r_bytes(6), std_logic_vector'("00001100"), result("For slave read buf(6)"));
        check_equal(sl_r_bytes(7), std_logic_vector'("01100111"), result("For slave read buf(7)"));
        check_equal(sl_r_bytes(8), std_logic_vector'("00001110"), result("For slave read buf(8)"));
        check_equal(sl_r_bytes(9), std_logic_vector'("00000011"), result("For slave read buf(9)"));
        check_equal(sl_r_bytes(10), std_logic_vector'("00010000"), result("For slave read buf(10)"));
        check_equal(sl_r_bytes(11), std_logic_vector'("00000010"), result("For slave read buf(11)"));
        check_equal(sl_r_bytes(12), std_logic_vector'("00010010"), result("For slave read buf(12)"));
        check_equal(sl_r_bytes(13), std_logic_vector'("00000000"), result("For slave read buf(13)"));
        check_equal(sl_r_bytes(14), std_logic_vector'("00010010"), result("For slave read buf(14)"));
        check_equal(sl_r_bytes(15), std_logic_vector'("00000001"), result("For slave read buf(15)"));
        check_equal(sl_r_idx, 16, "Bytes received by slave");
        check(nack_flag = '0', "Expected no NACK");
      END IF; -- for test_suite

    END LOOP test_cases_loop;

    WAIT FOR 20 ns;
    test_runner_cleanup(runner); -- end of simulation
  END PROCESS;


  --------------------------------------------------------------------------
  -- MONITOR PROCESSES AND CONCURRENT CHECKS.
  --------------------------------------------------------------------------

  -- This Proccess is responsibly for monitoring all activity on the bus
  -- and checking whether the (generically) passed timing constraints are
  -- being met as required by the i2c specifications
  i2c_monitor: PROCESS

    VARIABLE start_flag : STD_LOGIC := '0';
    VARIABLE stop_flag : STD_LOGIC  := '0';
    VARIABLE Sr_flag   : STD_LOGIC  := '0';
    VARIABLE buf_flag  : STD_LOGIC  := '0';
    VARIABLE t_hi_flag : STD_LOGIC  := '0';
    VARIABLE t_lo_flag : STD_LOGIC  := '0';
    VARIABLE dat_flag  : STD_LOGIC  := '0';

    -- Timing Constraints
    VARIABLE th_s   : TIME := 0 ns;
    VARIABLE tsu_sr : TIME := 0 ns;
    VARIABLE tsu_p  : TIME := 0 ns;
    VARIABLE tbuf   : TIME := 0 ns;
    VARIABLE t_hi   : TIME := 0 ns;
    VARIABLE t_lo   : TIME := 0 ns;
    VARIABLE tsu_d  : TIME := 0 ns;

  BEGIN
    WAIT ON SCL_in, SDA_in;
    
    -- SDA Branch
    IF (SDA_in'event) THEN

      -- Check for Start Condition
      IF (SDA_in = '0' AND SCL_in = '1') THEN
        start_flag := '1'; -- start detected
        th_s := now - SDA_in'LAST_EVENT;

        -- check that setup time for a repeated start has been met
        IF (Sr_flag = '1') THEN
          tsu_sr := now - tsu_sr;
          Sr_flag := '0';
          check(tsu_sr >= C_TSU_STA, "Expected start set up time to be atleast: " & to_string(C_TSU_STA, us) & " but instead got " & to_string(tsu_sr, us));
        END IF;
        
        -- check that bus free time has been met
        IF (buf_flag = '1') THEN
          tbuf := now - tbuf;
          check(tbuf >= C_T_BUF, "Expected bus to be free for atleast: " & to_string(C_T_BUF, us) & " but instead got " & to_string(tbuf, us));
          buf_flag := '0';
        END IF;

      -- Stop condition confirmed
      ELSIF (SDA_in = '1' AND SCL_in = '1' AND stop_flag = '1') THEN
        tsu_p := now - tsu_p; -- meassure time between SCL rising edge and SDA rising edge
        stop_flag := '0';
        check(tsu_p >= C_TSU_STO, "Expected stop setup time to be atleast: " & to_string(C_TSU_STO, us) & " but instead got " & to_string(tsu_p, us));
        buf_flag := '1';
        tbuf := now - SDA_in'LAST_EVENT;
      END IF;

      -- Check for changing data on SDA during SCL low
      IF (SCL_in = '0') THEN
        dat_flag := '1';
        tsu_d := now - SDA_in'LAST_EVENT; -- take timestamp of sda change
      END IF;
    END IF;


    -- SCL Branch
    IF (SCL_in'event) THEN

      -- Start condition confirmed
      IF (SDA_in = '0' AND SCL_in = '0' AND start_flag = '1') THEN
        th_s := now - th_s; -- meassure time between SDA falling and SCL falling
        check(th_s >= C_THD_STA, "Expected Start Hold time to be atleast " & to_string(C_THD_STA, us) & " but instead got " & to_string(th_s, us));
        start_flag := '0'; -- reset start flag

      -- Check for Stop Conditon
      ELSIF (SDA_in = '0' AND SCL_in = '1') THEN
        stop_flag := '1';
        tsu_p := now - SCL_in'LAST_EVENT; -- take timestamp of scl rising edge

      -- Check for repeat start
      ELSIF (SDA_in = '1' AND SCL_in = '1') THEN
        Sr_flag := '1';              -- indicate possible repeat start
        tsu_sr := now - SDA_in'LAST_EVENT; -- take timestamp of sda rising edge
      END IF;


      -- This branch tests if SCL's low and high times are correct
      -- and the setup and hold time of data on sda
      IF (SCL_in = '0') THEN

        -- Checks if required high time for scl has been met
        IF (t_hi_flag = '1') THEN
          t_hi := now - t_hi;             -- meassure time between SCL rising and falling edge
          t_hi_flag := '0';
          check(t_hi >= C_T_HIGH, "Expected SCL high time to be atleast: " & to_string(C_T_HIGH, us) & " but instead got " & to_string(t_hi, us));
        END IF;
        t_lo_flag := '1';
        t_lo := now - SCL_in'LAST_EVENT;  -- take timestamp of scl falling edge

      ELSIF (SCL_in = '1') THEN
        
        -- Checks if required low time for scl has been met 
        IF (t_lo_flag = '1') THEN
          t_lo := now - t_lo;             -- meassure time between SCL falling and rising edge
          t_lo_flag := '0';
          check(t_lo >= C_T_LOW, "Expected SCL low time to be atleast: " & to_string(C_T_LOW, us) & " but instead got " & to_string(t_lo, us));
        END IF;

        -- Checks if required setup time for data on sda has been met
        IF (dat_flag = '1') THEN
          tsu_d := now - tsu_d;           -- meassure time between last SDA change and SCL rising edge
          dat_flag := '0';
          check(tsu_d >= C_TSU_DAT, "Expected data setup time to be atleast: " & to_string(C_TSU_DAT, ns) & " but instead got " & to_string(tsu_d, ns));
        END IF;
        t_hi_flag := '1';
        t_hi := now - SCL_in'LAST_EVENT;  -- take timestamp of scl rising edge
      END IF;
    END IF;
  END PROCESS;


  -- concurrently put data on slave
  sl_w_data <= SL_W_BYTES(sl_w_idx);

  -- This process controls the extern write register for the slave
  -- to write data to the master
  sl_write_proc: PROCESS(clk, rst)
  BEGIN
    IF (rst = '1') THEN
      sl_w_idx <= 0;
    ELSIF (clk = '1' AND clk'event) THEN
      IF (sl_req = '1' AND sl_w_idx < SL_W_BYTES'HIGH) THEN
        sl_w_idx <= sl_w_idx + 1;
      END IF;
    END IF;
  END PROCESS;

  -- This process controls the external read register for the slave
  -- to monitor its data reception during transactions
  sl_read_proc: PROCESS(clk, rst)
  BEGIN
    IF (rst = '1') THEN
      sl_r_idx <= 0;
      sl_r_bytes <= (OTHERS => (OTHERS => '0'));
    ELSIF (clk = '1' AND clk'event) THEN
      IF (sl_data_val = '1' AND sl_r_idx < sl_r_bytes'LENGTH) THEN
        sl_r_bytes(sl_r_idx) <= sl_r_data;
        sl_r_idx <= sl_r_idx + 1;
      END IF;
    END IF;
  END PROCESS;

  -- process pushes new data every time master has loaded a byte
  m_data_i <= m_w_bytes(m_w_idx);

  m_write_proc: PROCESS(clk, rst)
  BEGIN
    IF (rst = '1') THEN
      m_w_idx <= 0;
    ELSIF (clk = '1' AND clk'event) THEN
      -- master loaded last byte
      IF (m_data_load = '1' AND m_w_idx < m_w_bytes'HIGH) THEN
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
    ELSIF (clk = '1' AND clk'event) THEN
      IF (m_r_valid = '1' AND m_r_idx < m_r_bytes'LENGTH) THEN
        m_r_bytes(m_r_idx) <= m_data_o;
        m_r_idx <= m_r_idx + 1;
      END IF;
    END IF;
  END PROCESS;

  -- This process monitors the slave acknowledge signal
  -- and sets a flag if a NACK has been received
  ack_monitor: PROCESS(clk, rst)
  BEGIN
    IF (rst = '1') THEN
      nack_flag <= '0';
    ELSIF (clk = '1' AND clk'event) THEN
      IF (m_sl_nack = '1') THEN
        nack_flag <= '1';
      END IF;
    END IF;
  END PROCESS;

END ARCHITECTURE;
