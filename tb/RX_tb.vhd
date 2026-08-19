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
  END ENTITY RX_tb;

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
  -- FSM DECLARATION --

  -- TYPES DECLARATION --

  -- INTERNAL SIGNALS DECLARATION --
  -- DUT interface
  SIGNAL clk   : STD_LOGIC := '0';
  SIGNAL rst : STD_LOGIC := '1';
  

  -- simulation signals
  SIGNAL src_data, dst_data : std_logic_vector(7 DOWNTO 0) := (others => '0');
  SIGNAL data_rdy : std_logic := '0';
  SIGNAL dataline : std_logic;
  SIGNAL status : std_logic;
  SIGNAL parity_err : std_logic;



  -- VUnit signals
  SIGNAL enable : STD_LOGIC := '0';
  

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
      parity_err => parity_err
    );
  
  TX_inst : ENTITY SRC_LIB.TX(rtl)
    GENERIC MAP(freq => freq, baud => baud)
    PORT MAP(
      clk   => clk,
      rst => rst,
      data_in   => src_data,
      data_rdy  => data_rdy,
      data_out  => dataline,
      status    => status 
    );
  --------------------------------------------------------------------------
  -- SIGNAL DEFINITION OF UNUSED OUTPUT PORTS AND FIXED SIGNALS.
  --------------------------------------------------------------------------
  

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
      ELSIF run("send_and_receive_test") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: send_and_receive_test");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        src_data <= "10000001";
        wait_N_cycles(1,clk);
        WAIT FOR 1 ps;
        data_rdy <= '1';
        wait_N_cycles(1,clk);
        WAIT FOR 1 ps;
        FOR i IN 0 TO 9 LOOP
          wait_N_cycles(bittime,clk);
          WAIT FOR 1 ps;
        END LOOP;
        wait_N_cycles(bittime,clk);
        WAIT FOR 1 ps; 
        check_equal(dst_data, 129, result("for Rx output buffer"));
        info("===== TEST CASE FINISHED =====");
        END IF; -- for test_suite
    END LOOP test_cases_loop;

    WAIT FOR 20 ns;
    test_runner_cleanup(runner); -- end of simulation
  END PROCESS test_runner;

  --------------------------------------------------------------------------
  -- MONITOR PROCESSES AND CONCURRENT CHECKS.
  --------------------------------------------------------------------------
  

END ARCHITECTURE tb;
