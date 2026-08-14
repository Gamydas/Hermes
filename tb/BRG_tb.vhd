----------------------------------------------------------------------------
--  % NAME        : BRG_tb.vhd %
--  % PROJECT     : Hermes UART %
--  % VERSION     : 1.0 %
--  % CREATED_BY  : Samy Gad %
--  % DATE_CREATED: 2026-08-14 %
--                                                                        --
--  DESCRIPTION:                                                          --
--  Testbench for Baud Rate Generator
--                                                                        --
----------------------------------------------------------------------------
--  REVISION HISTORY                                                      --
--                                                                        --
--  VERSION    DATE        SIGN      CHANGE DESCRIPTION                   --
--  ------- ----------  ----------   ------------------                   --
--  1.0     2026-08-14  Gamy   Initial version.
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
  ENTITY BRG_tb IS
    GENERIC(runner_cfg : string := runner_cfg_default;
            freq: integer := 50_000_000;
            baud: integer := 115200;
             OSR: integer := 16);
  END ENTITY BRG_tb;

----------------------------------------------------------------------------
-- ARCHITECTURE DECLARATION.
----------------------------------------------------------------------------
ARCHITECTURE tb OF BRG_tb IS

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
  CONSTANT C_CLK_PERIOD : time := 20 ns;

  -- FSM DECLARATION --

  -- TYPES DECLARATION --

  -- INTERNAL SIGNALS DECLARATION --
  -- DUT interface
  SIGNAL clk    : STD_LOGIC := '0';
  SIGNAL rst    : STD_LOGIC := '1';
  SIGNAL enable : STD_LOGIC := '1';
  SIGNAL tx_enable, rx_enable : STD_LOGIC;

  -- simulation signals
  constant tick          : integer := freq/(OSR*baud);
  constant mid_bit_point : integer := OSR/2;
  -- VUnit signals
  

BEGIN  -- start of architecture --
  --------------------------------------------------------------------------
  -- DUT INSTANTIATION.
  --------------------------------------------------------------------------
  BRG_inst : ENTITY SRC_LIB.BRG(rtl)
    GENERIC MAP(freq => freq, baud => baud, OSR => OSR)
    PORT MAP(
      clk   => clk,
      rst => rst,
      enable    => enable,
      tx_enable => tx_enable,
      rx_enable => rx_enable
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
    
    reset_dut(rst,clk);
    test_cases_loop : WHILE test_suite LOOP

      ----------------------------------------------------------------------
      -- TEST CASE DESCRIPTION:
      -- checks if tx_enable behaves as intended 
      -- Expected Result: tx_enable = '0' at every time except after OSR * tick cycles
      --
      ----------------------------------------------------------------------
      IF run("tx_enable_test") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: tx_enable_test");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        check(tx_enable = '0', "Expection transmition enable to be low");
        wait_N_cycles((OSR * tick) - tick,clk);
        WAIT FOR 1 ps;
        check(tx_enable = '0', "Expection transmition enable to be low");
        wait_N_cycles(tick,clk);
        WAIT FOR 1 ps;
        check(tx_enable = '1', "Expected transmition enable to be active");
        wait_N_cycles(1,clk);
        WAIT FOR 1 ps;
        check(tx_enable = '0', "Expection transmition enable to be low");
        info("===== TEST CASE FINISHED =====");
      
      ----------------------------------------------------------------------
      -- TEST CASE DESCRIPTION:
      -- checks if rx_enable behaves correctly
      -- Expected Result: rx_enable = '0' at every time except
      -- at mid_bit_point, mid_bit_point +1 and mid_bit_point + 2 
      ----------------------------------------------------------------------
      ELSIF run("rx_enable_test") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: rx_enable_test");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        check(rx_enable = '0', "Expected receive enable to be low");
        wait_N_cycles(mid_bit_point*tick - tick,clk);
        WAIT FOR 1 ps;
        check(rx_enable = '0', "Expected receive enable to be low");
        wait_N_cycles(tick,clk);
        WAIT FOR 1 ps;
        check(rx_enable = '1', "Expected receive enable to be high");
        wait_N_cycles(tick,clk);
        WAIT FOR 1 ps;
        check(rx_enable = '1', "Expected receive enable to be high");
        wait_N_cycles(tick,clk);
        WAIT FOR 1 ps;
        check(rx_enable = '1', "Expected receive enable to be high");
        wait_N_cycles(tick,clk);
        WAIT FOR 1 ps;
        check(rx_enable = '0', "Expected receive enable to be low");

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
