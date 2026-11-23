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
            scl_freq: integer := 100_000;
            thd_sta: integer := 4000;
            tsu_sta: integer := 4700;
            tsu_sto: integer := 4000;
            t_buf  : integer := 4700);
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
  CONSTANT C_THD_STA: time := thd_sta * 1 ns;
  CONSTANT C_TSU_STA: time := tsu_sta * 1 ns;
  CONSTANT C_TSU_STO: time := tsu_sto * 1 ns;
  CONSTANT C_T_BUF  : time := t_buf * 1 ns;

  -- Arrays to store read and write data in
  TYPE byte_array IS ARRAY (NATURAL RANGE <>) of STD_LOGIC_VECTOR(7 DOWNTO 0);

  -- data that slave sends to master
  CONSTANT R_BYTES : byte_array(3 DOWNTO 0) := (x"A1", x"B2", x"C3", x"D4");
  SIGNAL r_idx : INTEGER RANGE 0 TO  R_BYTES'high := 0; -- integer exactly the size of w_bytes length
  
  -- data that slave receives
  SIGNAL w_bytes : byte_array(15 DOWNTO 0) := (OTHERS => (OTHERS => '0'));
  SIGNAL w_idx : INTEGER RANGE 0 TO  w_bytes'length := 0; -- integer exactly the size of w_bytes length
  
  -- data that master sends
  SIGNAL m_w_bytes : byte_array(15 DOWNTO 0) := (OTHERS => (OTHERS => '0'));
  SIGNAL m_w_idx : INTEGER RANGE 0 TO  m_w_bytes'length := 0; -- integer exactly the size of m_w_bytes length
  
  SIGNAL m_r_bytes : byte_array(3 DOWNTO 0) := (OTHERS => (OTHERS => '0'));
  SIGNAL m_r_idx : INTEGER RANGE 0 TO  m_r_bytes'length := 0; -- integer exactly the size of m_r_bytes length
  
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
  SIGNAL SL_ADDR     : STD_LOGIC_VECTOR(6 DOWNTO 0) := "0011010";
  SIGNAL sl_w_data   : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
  SIGNAL sl_data_val : STD_LOGIC;
  SIGNAL sl_r_data   : STD_LOGIC_VECTOR(7 DOWNTO 0);
  -- I2C Lines
  SIGNAL SDA : STD_LOGIC;
  SIGNAL SCL : STD_LOGIC;
  SIGNAL SDA_in : STD_LOGIC;
  SIGNAL SCL_in : STD_LOGIC;

  SIGNAL nack_flag : STD_LOGIC;

  -- Timing Constraints
  --SIGNAL th_s : time := 0 ns;
  --SIGNAL tsu_sr :time := 0 ns; 
  --SIGNAL tsu_p : time := 0 ns;
  --SIGNAL tbuf : time := 0 ns;


  -- Test Block for WM8731 Audichip


  -- I2C Daten: 7 Bit Registeradresse plus 9 Datenbits 
  constant i2c_data : byte_array(15 DOWNTO 0) := (
    "00000001","00010010",
    "00000000","00010010", -- R9  Deaktiviere Audio 
    "00000010","00010000", -- R8  Normal mode, 384fs, sr=0 (mclk@18.432mhz, fs=48khz)
    "00000011","00001110", -- R7  Slave, DSP Modus, 16 Bit, msb 1bclk,
    "01100111","00001100", -- R6  DAC on, out on
    "00000000","00001010", -- R5  DAC Mute off
    "00010000","00001000", -- R4  DAC Sel
    "00000000","00011110"  -- R15 Reset Chip
  );


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

  SDA_in <= to_x01(SDA);
  SCL_in <= to_x01(SCL);
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


  PROCEDURE configure_WM8731 IS
  BEGIN
    m_pnsr <= '1';
    m_addr <= sl_addr;
    m_w_amt <= std_logic_vector(to_unsigned(16, m_w_amt'length));
    m_w_bytes <= i2c_data;
    wait for 1 ps;
    m_S <= '1';
    WAIT UNTIL rising_edge(clk);
    WAIT FOR 1 ps;
    m_S <= '0';
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
      ELSIF run("test_tbuf") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: test_tbuf");
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
      ELSIF run("test_tsu_sta") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: test_tsu_sta");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        i2c_write('0', SL_ADDR, std_logic_vector(to_unsigned(1, m_w_amt'length)), (x"94", x"FF", x"32", x"33"), m_S);
        WAIT ON m_data_load;
        WAIT ON m_addr_cnt_load;
        i2c_write('1', SL_ADDR, std_logic_vector(to_unsigned(1, m_w_amt'length)), (x"A1", x"FF", x"22", x"F0"), m_S);
        IF (m_busy = '1') THEN
          WAIT UNTIL m_busy = '0';
        END IF;
        WAIT FOR 1 ps; 
        check_equal(w_bytes(0), std_logic_vector'(x"33"), result("For slave read buffer pos(0)"));
        check_equal(w_bytes(1), std_logic_vector'(x"22"), result("For slave read buffer pos(0)"));
        check(nack_flag = '0', "Expected no NACK");
        info("===== TEST CASE FINISHED =====");
      ELSIF run("test_write_sr_read") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: test_write_sr_read");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        i2c_write('0', SL_ADDR, std_logic_vector(to_unsigned(1, m_w_amt'length)), (x"94", x"FF", x"32", x"33"), m_S);
        WAIT ON m_data_load;
        i2c_read('0', SL_ADDR, std_logic_vector(to_unsigned(4, m_r_amt'length)), m_S);
        WAIT ON m_addr_cnt_load;
        m_pnsr <= '1';
        IF (m_busy = '1') THEN
          WAIT UNTIL m_busy = '0';
        END IF;
        WAIT FOR 1 ps;
        check_equal(w_bytes(0), std_logic_vector'(x"33"), result("For slave read buffer pos(0)"));
        check_equal(m_r_bytes(0), std_logic_vector'(x"D4"), result("For master read buffer pos(0)"));
        check_equal(m_r_bytes(1), std_logic_vector'(x"C3"), result("For master read buffer pos(1)"));
        check_equal(m_r_bytes(2), std_logic_vector'(x"B2"), result("For master read buffer pos(2)"));
        check_equal(m_r_bytes(3), std_logic_vector'(x"A1"), result("For master read buffer pos(3)"));
        info("===== TEST CASE FINISHED =====");
      ELSIF run("WM8731_test") THEN
        configure_WM8731;
        IF (m_busy = '1') THEN
          WAIT UNTIL m_busy = '0';
        END IF;
        WAIT FOR 1 ps; 
        check_equal(w_bytes(0), std_logic_vector'("00011110"), result("For slave read buf(0)"));
        check_equal(w_bytes(1), std_logic_vector'("00000000"), result("For slave read buf(1)"));
        check_equal(w_bytes(2), std_logic_vector'("00001000"), result("For slave read buf(2)"));
        check_equal(w_bytes(3), std_logic_vector'("00010000"), result("For slave read buf(3)"));
        check_equal(w_bytes(4), std_logic_vector'("00001010"), result("For slave read buf(4)"));
        check_equal(w_bytes(5), std_logic_vector'("00000000"), result("For slave read buf(5)"));
        check_equal(w_bytes(6), std_logic_vector'("00001100"), result("For slave read buf(6)"));
        check_equal(w_bytes(7), std_logic_vector'("01100111"), result("For slave read buf(7)"));
        check_equal(w_bytes(8), std_logic_vector'("00001110"), result("For slave read buf(8)"));
        check_equal(w_bytes(9), std_logic_vector'("00000011"), result("For slave read buf(9)"));
        check_equal(w_bytes(10), std_logic_vector'("00010000"), result("For slave read buf(10)"));
        check_equal(w_bytes(11), std_logic_vector'("00000010"), result("For slave read buf(11)"));
        check_equal(w_bytes(12), std_logic_vector'("00010010"), result("For slave read buf(12)"));
        check_equal(w_bytes(13), std_logic_vector'("00000000"), result("For slave read buf(13)"));
        check_equal(w_bytes(14), std_logic_vector'("00010010"), result("For slave read buf(14)"));
        check_equal(w_bytes(15), std_logic_vector'("00000001"), result("For slave read buf(15)"));
  
      END IF; -- for test_suite
    END LOOP test_cases_loop;

    WAIT FOR 20 ns;
    test_runner_cleanup(runner); -- end of simulation
  END PROCESS;
  

  --------------------------------------------------------------------------
  -- MONITOR PROCESSES AND CONCURRENT CHECKS.
  --------------------------------------------------------------------------
  i2c_monitor : PROCESS
  VARIABLE start_flag : std_logic := '0';
  VARIABLE stop_flag : std_logic := '0';
  VARIABLE Sr_flag : std_logic := '0';
  VARIABLE buf_flag : std_logic := '0';

  -- Timing Constraints
  VARIABLE th_s : time := 0 ns;
  VARIABLE tsu_sr :time := 0 ns; 
  VARIABLE tsu_p : time := 0 ns;
  VARIABLE tbuf : time := 0 ns;
  BEGIN
  WAIT ON SCL_in, SDA_in;
  --check(SDA_in'event /= SCL_in'event, "Expected only one line to change not both.");
  IF (SDA_in'event) THEN
    
    -- Check for Start Condition
    IF (SDA_in = '0' AND SCL_in = '1') THEN
      start_flag := '1'; -- start detected
      th_s := now - SDA_in'last_event;
      
      -- check that Setup time for a repeated start has been respected
      IF (Sr_flag = '1') THEN
        tsu_sr := now - tsu_sr;
        Sr_flag := '0';
        check(tsu_sr >= C_TSU_STA, "Expected start set up time to be atleast: " & to_string(C_TSU_STA, us) & " but instead got " & to_string(tsu_sr, us)); 
      END IF;
      
      IF (buf_flag = '1') THEN 
        tbuf := now - tbuf;
        check(tbuf >= C_T_BUF, "Expected bus to be free for atleast: " & to_string(C_T_BUF, us) & " but instead got " & to_string(tbuf, us));
        buf_flag := '0';
      END IF;

      -- Stop condition confirmed
    ELSIF (SDA_in = '1' AND SCL_in = '1' AND stop_flag = '1') THEN 
      tsu_p := now - tsu_p; -- meassure time between SCL rising edge and SDA rising edge
      stop_flag := '0';
      check(tsu_p >= C_TSU_STO,"Expected stop setup time to be atleast: " & to_string(C_TSU_STO, us) & " but instead got " & to_string(tsu_p, us));
      buf_flag := '1';
      tbuf := now - SDA_in'last_event;
    END IF; 
  END IF;
  IF (SCL_in'event) THEN
 
    -- Start condition confirmed
    IF (SDA_in = '0' AND SCL_in = '0' AND start_flag = '1') THEN
      th_s := now - th_s; -- meassure time between SDA falling and SCL falling 
      check(th_s >= C_THD_STA, "Expected Start Hold time to be atleast " & to_string(C_THD_STA, us) & " but instead got " & to_string(th_s, us));
      start_flag := '0'; -- reset start flag 

    -- Check for Stop Conditon
    ELSIF (SDA_in = '0' AND SCL_in = '1') THEN
      stop_flag := '1';
      tsu_p := now - SCL_IN'last_event; -- take timestamp of scl rising edge 
    
    -- Check for repeat start
    ELSIF (SDA_in = '1' AND SCL_in = '1') THEN 
      Sr_flag := '1';              -- indicate possible repeat start
      tsu_sr := now - SDA_in'last_event; -- take timestamp of sda rising edge
    END IF;
  END IF;

  END PROCESS;


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
