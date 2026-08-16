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
  CONSTANT C_CLK_PERIOD : time := 1 sec / freq;

  -- TYPES DECLARATION --

  -- INTERNAL SIGNALS DECLARATION --
  -- DUT interface
  SIGNAL clk  : STD_LOGIC := '0';
  SIGNAL rst  : STD_LOGIC := '1';
  -- sync is low active
  SIGNAL sync : STD_LOGIC := '0';
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
      clk  => clk,
      rst  => rst,
      sync => sync,
      tx_enable => tx_enable,
      rx_enable => rx_enable
    );

  --------------------------------------------------------------------------
  -- SIGNAL DEFINITION OF UNUSED OUTPUT PORTS AND FIXED SIGNALS.
  --------------------------------------------------------------------------
  

  --------------------------------------------------------------------------
  -- CLOCK
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
    -- brief: Procedure to check tx_enable and rx_enable signal for every cycle
    -- over a full bit_time
    -- Tx: tx_enable signal
    -- Rx: rx_enable signal
    PROCEDURE check_TxRx(SIGNAL Tx: IN std_logic;
                         SIGNAL Rx: IN std_logic;
                         SIGNAL clk : IN std_logic;
                         constant line_num : natural :=0;
                         constant file_name : string  := "") is
    BEGIN
      -- 0 to bit_mid - 1 ticks
      for i in 1 to ((tick*mid_bit_point)-tick)-1 loop
        wait until rising_edge(clk);
        wait for 1 ps;
        check(Tx = '0', "Expected Tx to be '0'", line_num => line_num, file_name => file_name); 
        check(Rx = '0', "Expected Rx to be '0'", line_num => line_num, file_name => file_name); 
      end loop;
      -- next rising edge puts us at exactle bit_mid-1 ticks, so Rx has to pulse high for 1 cycle
      wait until rising_edge(clk);
      wait for 1 ps;
      check(Tx = '0', "Expected Tx to be '0'", line_num => line_num, file_name => file_name); 
      check(Rx = '1', "Expected Rx to be '1'", line_num => line_num, file_name => file_name);
      -- bridges the 1 tick to bit_mid_point
      for i in 1 to tick-1 loop
        wait until rising_edge(clk);
        wait for 1 ps;
        check(Tx = '0', "Expected Tx to be '0'", line_num => line_num, file_name => file_name); 
        check(Rx = '0', "Expected Rx to be '0'", line_num => line_num, file_name => file_name); 
      end loop;
      -- next rising edge puts us exactly at bit_mid_point, Rx has to go high
      wait until rising_edge(clk);
      WAIT FOR 1 ps;
      check(Tx = '0', "Expected Tx to be '0'", line_num => line_num, file_name => file_name); 
      check(Rx = '1', "Expected Rx to be '1'", line_num => line_num, file_name => file_name);
      -- bridges the 1 tick to bit_mid_point + 1
      for i in 1 to tick-1 loop
        wait until rising_edge(clk);
        wait for 1 ps;
        check(Tx = '0', "Expected Tx to be '0'", line_num => line_num, file_name => file_name); 
        check(Rx = '0', "Expected Rx to be '0'", line_num => line_num, file_name => file_name); 
      end loop;
      -- next rising edge puts us exactly at bit_mid_point + 1, Rx has to go high
      wait until rising_edge(clk);
      WAIT FOR 1 ps;
      check(Tx = '0', "Expected Tx to be '0'", line_num => line_num, file_name => file_name); 
      check(Rx = '1', "Expected Rx to be '1'", line_num => line_num, file_name => file_name);
      -- checks every rising edge from bit_mid_point + 1 to the end of the bittime
      for i in 1 to (tick*mid_bit_point) - tick - 1 loop
        wait until rising_edge(clk);
        wait for 1 ps;
        check(Tx = '0', "Expected Tx to be '0'", line_num => line_num, file_name => file_name); 
        check(Rx = '0', "Expected Rx to be '0'", line_num => line_num, file_name => file_name); 
      end loop;
      -- next rising edge completes this bit time
      wait until rising_edge(clk);
      wait for 1 ps;
      check(Tx = '1', "Expected Tx to be '1'", line_num => line_num, file_name => file_name); 
      check(Rx = '0', "Expected Rx to be '0'", line_num => line_num, file_name => file_name); 
    END PROCEDURE check_TxRx;




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
      -- test to see wether tx and rx behave like they are expected to, i.e. 
      -- there are always 3 rx pulses in the around the mid_bit_point and one 
      -- tx pulse at the end of a bittime
      -- Expected Result: tx_enable = '0' at every time except after OSR * tick cycles
      --                  rx_enable = '1' at bit_mid_point - 1, bit_mid_point and bmp + 1
      ----------------------------------------------------------------------
      IF run("tx_rx_test") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: tx_rx_test");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        check(tx_enable = '0', "Expected Tx to be '0'");
        check(rx_enable = '0', "Expected Rx to be '0'");
        check_TxRx(tx_enable, rx_enable, clk);
        info("===== TEST CASE FINISHED =====");
      ----------------------------------------------------------------------
      -- TEST CASE DESCRIPTION:
      -- checks that tx and rx behave correctly over more than one period and 
      -- dont drift apart
      -- Expected Result: tx_enable = '0' at every time except after OSR * tick cycles
      --                  rx_enable = '1' at bit_mid_point - 1, bit_mid_point and bmp + 1
      -- For 10 full bittimes
      ----------------------------------------------------------------------
      ELSIF run("tx_rx_over_10_bittimes") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: tx_rx_over_10_bittimes");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        check(tx_enable = '0', "Expected Tx to be '0'");
        check(rx_enable = '0', "Expected Rx to be '0'");
        for i in 1 to 10 loop
          check_TxRx(tx_enable, rx_enable, clk);
        end loop;
        info("===== TEST CASE FINISHED =====");
      ----------------------------------------------------------------------
      -- TEST CASE DESCRIPTION:
      -- checks that resynchronisation works 
      -- Expected Result: sync = 1 stops counter and after sync goes low the
      --                  counter start from the beginning
      ----------------------------------------------------------------------
      ELSIF run("sync_test") THEN 
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: sync_test");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        -- 0 to bit_mid - 1 ticks
        for i in 1 to ((tick*mid_bit_point)-tick)-1 loop
          wait until rising_edge(clk);
          wait for 1 ps;
          check(tx_enable = '0', "Expected Tx to be '0'"); 
          check(rx_enable = '0', "Expected Rx to be '0'"); 
        end loop;
        -- next rising edge puts us at exactle bit_mid-1 ticks, so Rx has to pulse high for 1 cycle
        wait until rising_edge(clk);
        wait for 1 ps;
        check(tx_enable = '0', "Expected Tx to be '0'"); 
        check(rx_enable = '1', "Expected Rx to be '1'");
        -- bridges the 1 tick to bit_mid_point
        for i in 1 to tick-1 loop
          wait until rising_edge(clk);
          wait for 1 ps;
          check(tx_enable = '0', "Expected Tx to be '0'"); 
          check(rx_enable = '0', "Expected Rx to be '0'"); 
        end loop;
        -- next rising edge puts us exactly at bit_mid_point, Rx has to go high
        wait until rising_edge(clk);
        WAIT FOR 1 ps;
        check(tx_enable = '0', "Expected Tx to be '0'"); 
        check(rx_enable = '1', "Expected Rx to be '1'");  
        -- stop the BRG
        sync <= '1';
        wait for 1 ps;
          wait until rising_edge(clk);
        wait for 1 ps;
        check(tx_enable = '0', "Expected Tx to be '0'"); 
        check(rx_enable = '0', "Expected Rx to be '0'");   
        sync <= '0';
        wait for 1 ps;  
        check_TxRx(tx_enable,rx_enable, clk);
        info("===== TEST CASE FINISHED =====");


      ----------------------------------------------------------------------
      -- TEST CASE DESCRIPTION:
      -- sync is pulsed two cycles before the end of a bittime, where tick_cnt
      -- is on its last value and about to wrap
      -- Expected Result: counter restarts from 0, no leftover carry
      ----------------------------------------------------------------------
      ELSIF run("sync_before_tx_pulse") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: sync_before_tx_pulse");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        wait_N_cycles((OSR*tick)-2, clk);
        wait for 1 ps;
        sync <= '1';
        wait until rising_edge(clk);
        wait for 1 ps;
        sync <= '0';
        check_TxRx(tx_enable, rx_enable, clk);
        info("===== TEST CASE FINISHED =====");


      ----------------------------------------------------------------------
      -- TEST CASE DESCRIPTION:
      -- checks that the async reset works 
      -- Expected Result: rst = 1 resets counter and after rst goes low the
      --                  counter start from the beginning
      ----------------------------------------------------------------------
      ELSIF run("reset_test") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: reset_test");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        -- 0 to bit_mid - 1 ticks
        for i in 1 to ((tick*mid_bit_point)-tick)-1 loop
          wait until rising_edge(clk);
          wait for 1 ps;
          check(tx_enable = '0', "Expected Tx to be '0'"); 
          check(rx_enable = '0', "Expected Rx to be '0'"); 
        end loop;
        -- next rising edge puts us at exactle bit_mid-1 ticks, so Rx has to pulse high for 1 cycle
        wait until rising_edge(clk);
        wait for 1 ps;
        check(tx_enable = '0', "Expected Tx to be '0'"); 
        check(rx_enable = '1', "Expected Rx to be '1'");
        -- bridges the 1 tick to bit_mid_point
        for i in 1 to tick-1 loop
          wait until rising_edge(clk);
          wait for 1 ps;
          check(tx_enable = '0', "Expected Tx to be '0'"); 
          check(rx_enable = '0', "Expected Rx to be '0'"); 
        end loop;
        -- next rising edge puts us exactly at bit_mid_point, Rx has to go high
        wait until rising_edge(clk);
        WAIT FOR 1 ps;
        check(tx_enable = '0', "Expected Tx to be '0'"); 
        check(rx_enable = '1', "Expected Rx to be '1'");  
        -- stop the BRG
        rst <= '1';
        wait for 1 ps;
        for i in 1 to 1000 loop
          wait until rising_edge(clk);
          wait for 1 ps;
          check(tx_enable = '0', "Expected Tx to be '0'"); 
          check(rx_enable = '0', "Expected Rx to be '0'");   
        end loop;
        rst <= '0';
        wait for 1 ps;  
        check_TxRx(tx_enable,rx_enable, clk); 
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
