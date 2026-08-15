----------------------------------------------------------------------------
--  % NAME        : TX_tb.vhd %
--  % PROJECT     : UART Implementation %
--  % VERSION     : 1.0 %
--  % CREATED_BY  : Samy Gad %
--  % DATE_CREATED: 2026-08-15 %
--                                                                        --
--  DESCRIPTION:                                                          --
--  Testbench for uart transmitter module
--                                                                        --
----------------------------------------------------------------------------
--  REVISION HISTORY                                                      --
--                                                                        --
--  VERSION    DATE        SIGN      CHANGE DESCRIPTION                   --
--  ------- ----------  ----------   ------------------                   --
--  1.0     2026-08-15  Gamy   Initial version.
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
  ENTITY TX_tb IS
    GENERIC(runner_cfg : string := runner_cfg_default;
            freq: integer := 50_000_000;
            baud: integer := 115200);
  END ENTITY TX_tb;

----------------------------------------------------------------------------
-- ARCHITECTURE DECLARATION.
----------------------------------------------------------------------------
ARCHITECTURE tb OF TX_tb IS

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
  CONSTANT C_CLK_PERIOD : time :=  ns;
  CONSTANT bittime : integer := freq/baud; -- in cycles
  -- FSM DECLARATION --

  -- TYPES DECLARATION --

  -- INTERNAL SIGNALS DECLARATION --
  -- DUT interface
  SIGNAL clk   : STD_LOGIC := '0';
  SIGNAL rst : STD_LOGIC := '1';
  

  -- simulation signals
  SIGNAL data : std_logic_vector(7 DOWNTO 0) := (others => '0');
  SIGNAL data_rdy : std_logic := '0';
  SIGNAL sent_data : std_logic;



BEGIN  -- start of architecture --
  --------------------------------------------------------------------------
  -- DUT INSTANTIATION.
  --------------------------------------------------------------------------
  TX_inst : ENTITY SRC_LIB.TX(rtl)
    GENERIC MAP(freq => freq, baud => baud)
    PORT MAP(
      clk   => clk,
      rst => rst,
      data_in   => data,
      data_rdy  => data_rdy,
      data_out  => sent_data
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

      ----------------------------------------------------------------------
      -- TEST CASE DESCRIPTION:
      -- loops 100 cycles and checks sent_data on every cycle
      -- Expected Result: High logic level over the entire test duration
      --
      ----------------------------------------------------------------------
      IF run("idle_test") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: idle_test");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        -- data line has to be high the entire time
        check(sent_data = '1', "Expected dataline to idle '1'");
        for i in 0 to 100 loop
          wait until rising_edge(clk);
          wait for 1 ps;
          check(sent_data = '1', "Expected dataline to idle '1'");
        end loop;
        info("===== TEST CASE FINISHED =====");
      ELSIF run("send_byte_test") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: send_byte_test");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        -- data line should idle
        check(sent_data = '1', "Expected dataline to idle '1'");
        data <= "10010001";
        wait for 1 ps;
        data_rdy <= '1';
        wait for 1 ps;
        -- start bit should go low for 1 bittime
        check(sent_data = '0', "Expected dataline to signal start of data '0'");
        wait_N_cycles(bittime,clk);
        WAIT FOR 1 ps; 
        -- tx_enable is high, so the first bit should be sent out
        check(sent_data = '1', "Expected '1'");
        wait_N_cycles(bittime,clk);
        WAIT FOR 1 ps;
        check(sent_data = '0', "Expected '0'");

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
