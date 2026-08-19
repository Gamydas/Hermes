----------------------------------------------------------------------------
--  % NAME        : RX_tb.vhd %
--  % PROJECT     : UART Implementation %
--  % VERSION     : 1.0 %
--  % CREATED_BY  : Samy Gad %
--  % DATE_CREATED: 2026-08-18 %
--                                                                        --
--  DESCRIPTION:                                                          --
--  Testbench of UART receiver
--                                                                        --
----------------------------------------------------------------------------
--  REVISION HISTORY                                                      --
--                                                                        --
--  VERSION    DATE        SIGN      CHANGE DESCRIPTION                   --
--  ------- ----------  ----------   ------------------                   --
--  1.0     2026-08-18  Gamy   Initial version.
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
  ENTITY RX_tb IS
    GENERIC(runner_cfg : string := runner_cfg_default;
            freq: integer := 50_000_000;
            baud: integer := 115200);
  END ENTITY;

----------------------------------------------------------------------------
-- ARCHITECTURE DECLARATION.
----------------------------------------------------------------------------
ARCHITECTURE tb OF RX_tb IS

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
  CONSTANT C_CLK_PERIOD : time :=  1 sec / freq;
  CONSTANT bittime : integer := freq/baud; -- in cycles
  -- INTERNAL SIGNALS DECLARATION --
  -- DUT interface
  SIGNAL clk   : STD_LOGIC := '0';
  SIGNAL rst : STD_LOGIC := '1';
  

  -- simulation signals
  SIGNAL src_data, dst_data : std_logic_vector(7 DOWNTO 0) := (others => '0');
  SIGNAL data_rdy : std_logic := '0';
  SIGNAL tb_line : std_logic := '1';
  SIGNAL tx_line : std_logic;
  SIGNAL use_tx : boolean := false;
  SIGNAL dataline : std_logic;
  SIGNAL status : std_logic;
  SIGNAL parity_err : std_logic;
  SIGNAL frame_err : std_logic;



BEGIN  -- start of architecture --
  --------------------------------------------------------------------------
  -- DUT INSTANTIATION.
  --------------------------------------------------------------------------
  RX_inst : ENTITY SRC_LIB.RX(rtl)
  GENERIC MAP(freq => freq, baud => baud)
    PORT MAP(
      clk   => clk,
      rst => rst,
      Rx         => dataline,
      data_out   => dst_data,
      parity_err => parity_err,
      frame_err => frame_err
      );
  
  TX_inst : ENTITY SRC_LIB.TX(rtl)
    GENERIC MAP(freq => freq, baud => baud)
    PORT MAP(
      clk   => clk,
      rst => rst,
      data_in   => src_data,
      data_rdy  => data_rdy,
      data_out  => tx_line,
      status    => status 
      );

  -- dataline mux to for loopback tests
  dataline <= tx_line WHEN use_tx = true ELSE
              tb_line;
  --------------------------------------------------------------------------
  -- CLOCK AND RESET.
  --------------------------------------------------------------------------
  clk   <= NOT clk after C_CLK_PERIOD / 2;

  --------------------------------------------------------------------------
  --------------------------------------------------------------------------
  -------------------------- TEST_RUNNER PROCESS ---------------------------
  --------------------------------------------------------------------------
  --------------------------------------------------------------------------

  test_runner : PROCESS
    -- VARIABLE DECLARATION.

    -- FUNCTIONS/PROCEDURES DECLARATION.
    -- simple function to calculate the even parity of a byte
    FUNCTION even_par(data : std_logic_vector(7 DOWNTO 0)) RETURN std_logic IS
      VARIABLE p : std_logic := '0';
    BEGIN
      FOR i IN 0 TO 7 LOOP
        p := p XOR data(i);
      END LOOP;
      RETURN p;
    END FUNCTION;

    -- Procedure to drive the dataline, can be used to send bits and also to 
    -- test bit sampling by calling the function multiple times in 1 bittime
    -- with different values
    PROCEDURE drive_dataline(SIGNAL dataline : OUT std_logic;
                             SIGNAL clk      : IN std_logic;
                             CONSTANT value  : IN std_logic;
                             CONSTANT cycles : IN integer) IS
    BEGIN
      dataline <= value;
      wait_N_cycles(cycles,clk);
    END PROCEDURE;
    
    PROCEDURE send_frame(SIGNAL dataline : OUT std_logic;
                         SIGNAL clk      : IN std_logic;
                         CONSTANT start: IN std_logic;
                         CONSTANT data : IN std_logic_vector(7 DOWNTO 0);
                         CONSTANT par  : IN std_logic;
                         CONSTANT stop : IN std_logic;
                         CONSTANT cycles : IN integer) IS
    BEGIN
      -- set dataline low for 1 cycle to start receiver FSM 
      drive_dataline(dataline, clk, '0', 1);
      drive_dataline(dataline, clk, start, cycles-1);
      FOR i IN 0 TO 7 LOOP
        drive_dataline(dataline, clk, data(i), cycles);
      END LOOP;
      drive_dataline(dataline, clk, par, cycles);
      drive_dataline(dataline, clk, stop, cycles);
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
      IF run("idle_test") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: idle_test");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        for i in 0 to 100 loop
          wait_N_cycles(1,clk);
          WAIT FOR 1 ps;
          check(dataline = '1', "Expected dataline to be high during idle");
          check_equal(dst_data, 0, result("for destination buffer"));
          check(parity_err = '0', "Expected parity error to be 0 while no data is send");
        END LOOP;
        info("===== TEST CASE FINISHED =====");
      ELSIF run("receive_one_byte") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: receive_one_byte");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        send_frame(tb_line, clk, '0', "10010001", even_par("10010001"), '1', bittime);    
        WAIT FOR 1 ps;
        check_equal(dst_data, std_logic_vector'("10010001"), result("for Rx output buffer"));
        check(parity_err = '0', "Expected parity error to be '0'");
        check(frame_err = '0', "Expected frame error to be '0'");
        info("===== TEST CASE FINISHED =====");
      ELSIF run("receive_multiple_bytes") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: receive_multiple_bytes");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        send_frame(tb_line, clk, '0', "11110010", even_par("11110010"), '1', bittime);
        WAIT FOR 1 ps;
        check_equal(dst_data, std_logic_vector'("11110010"), result("for Rx output buffer"));
        check(parity_err = '0', "Expected parity error to be '0'");
        check(frame_err = '0', "Expected frame error to be '0'");

        send_frame(tb_line, clk, '0', "01001111", even_par("01001111"), '1', bittime);
        WAIT FOR 1 ps;
        check_equal(dst_data, std_logic_vector'("01001111"), result("for Rx output buffer"));
        check(parity_err = '0', "Expected parity error to be '0'");
        check(frame_err = '0', "Expected frame error to be '0'");

        send_frame(tb_line, clk, '0', "01001001", even_par("01001001"), '1', bittime);
        WAIT FOR 1 ps;
        check_equal(dst_data, std_logic_vector'("01001001"), result("for Rx output buffer"));
        check(parity_err = '0', "Expected parity error to be '0'");
        check(frame_err = '0', "Expected frame error to be '0'");

        send_frame(tb_line, clk, '0', "00111100", even_par("00111100"), '1', bittime);
        WAIT FOR 1 ps;
        check_equal(dst_data, std_logic_vector'("00111100"), result("for Rx output buffer"));
        check(parity_err = '0', "Expected parity error to be '0'");
        check(frame_err = '0', "Expected frame error to be '0'");

        send_frame(tb_line, clk, '0', "10101010", even_par("10101010"), '1', bittime);
        WAIT FOR 1 ps;
        check_equal(dst_data, std_logic_vector'("10101010"), result("for Rx output buffer"));
        check(parity_err = '0', "Expected parity error to be '0'");
        check(frame_err = '0', "Expected frame error to be '0'");

        send_frame(tb_line, clk, '0', "01010101", even_par("01010101"), '1', bittime);
        WAIT FOR 1 ps;
        check_equal(dst_data, std_logic_vector'("01010101"), result("for Rx output buffer"));
        check(parity_err = '0', "Expected parity error to be '0'");
        check(frame_err = '0', "Expected frame error to be '0'");
        info("===== TEST CASE FINISHED =====");
      ELSIF run("receive_with_idle_gaps") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: receive_with_idle_gaps");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        send_frame(tb_line, clk, '0', "11110010", even_par("11110010"), '1', bittime);
        WAIT FOR 1 ps;
        check_equal(dst_data, std_logic_vector'("11110010"), result("for Rx output buffer"));
        check(parity_err = '0', "Expected parity error to be '0'");
        check(frame_err = '0', "Expected frame error to be '0'");
        
        -- idle
        drive_dataline(tb_line, clk, '1', 2*bittime);

        send_frame(tb_line, clk, '0', "01001111", even_par("01001111"), '1', bittime);
        WAIT FOR 1 ps;
        check_equal(dst_data, std_logic_vector'("01001111"), result("for Rx output buffer"));
        check(parity_err = '0', "Expected parity error to be '0'");
        check(frame_err = '0', "Expected frame error to be '0'");
        
        -- idle
        drive_dataline(tb_line, clk, '1', 4*bittime);

        send_frame(tb_line, clk, '0', "01001001", even_par("01001001"), '1', bittime);
        WAIT FOR 1 ps;
        check_equal(dst_data, std_logic_vector'("01001001"), result("for Rx output buffer"));
        check(parity_err = '0', "Expected parity error to be '0'");
        check(frame_err = '0', "Expected frame error to be '0'");
        info("===== TEST CASE FINISHED =====");
      ELSIF run("error_tests") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: error_tests");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0'; 
        -- force parity error
        send_frame(tb_line, clk, '0', "01001111", not even_par("01001111"), '1', bittime);
        WAIT FOR 1 ps;
        check_equal(dst_data, std_logic_vector'("01001111"), result("for Rx output buffer"));
        check(parity_err = '1', "Expected parity error to be '1'");
        check(frame_err = '0', "Expected frame error to be '0'");
        
        -- force stopbit error
        send_frame(tb_line, clk, '0', "10101010", even_par("10101010"), '0', bittime);
        WAIT FOR 1 ps;
        check_equal(dst_data, std_logic_vector'("10101010"), result("for Rx output buffer"));
        check(parity_err = '0', "Expected parity error to be '0'");
        check(frame_err = '1', "Expected frame error to be '1'");
        
        -- force startbit error, output should remain unchanged
        send_frame(tb_line, clk, '1', "00111100", even_par("00111100"), '1', bittime);
        WAIT FOR 1 ps;
        check_equal(dst_data, std_logic_vector'("10101010"), result("for Rx output buffer"));
        check(parity_err = '0', "Expected parity error to be '0'");
        check(frame_err = '1', "Expected frame error to be '1'");
        
        -- force stop and parity error
        send_frame(tb_line, clk, '0', "00111100", not even_par("00111100"), '0', bittime);
        WAIT FOR 1 ps;
        check_equal(dst_data, std_logic_vector'("00111100"), result("for Rx output buffer"));
        check(parity_err = '1', "Expected parity error to be '1'");
        check(frame_err = '1', "Expected frame error to be '1'");
        info("===== TEST CASE FINISHED =====");

      ELSIF run("error_then_valid_test") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: error_then_valid_test");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        -- force startbit error, output should remain unchanged
        send_frame(tb_line, clk, '0', "00111100", not even_par("00111100"), '1', bittime);
        WAIT FOR 1 ps;
        check_equal(dst_data, std_logic_vector'("00111100"), result("for Rx output buffer"));
        check(parity_err = '1', "Expected parity error to be '1'");
        check(frame_err = '1', "Expected frame error to be '1'");
       
        send_frame(tb_line, clk, '0', "01001111", even_par("01001111"), '1', bittime);
        WAIT FOR 1 ps;
        check_equal(dst_data, std_logic_vector'("01001111"), result("for Rx output buffer"));
        check(parity_err = '0', "Expected parity error to be '0'");
        check(frame_err = '0', "Expected frame error to be '0'");
        info("===== TEST CASE FINISHED =====");
      
      END IF; -- for test_suite
    END LOOP test_cases_loop;

    WAIT FOR 20 ns;
    test_runner_cleanup(runner); -- end of simulation
  END PROCESS;

  --------------------------------------------------------------------------
  -- MONITOR PROCESSES AND CONCURRENT CHECKS.
  --------------------------------------------------------------------------
  

END ARCHITECTURE;
