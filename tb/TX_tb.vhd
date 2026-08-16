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
  CONSTANT C_CLK_PERIOD : time := 1 sec / freq;
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
  SIGNAL dataline : std_logic;
  SIGNAL status : std_logic;


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
  VARIABLE parity : std_logic;
  VARIABLE old_data : std_logic_vector(7 downto 0);
    -- FUNCTIONS/PROCEDURES DECLARATION.

  PROCEDURE strobe_bit(CONSTANT expected : std_logic;
                       CONSTANT name : string;
                       CONSTANT bittime : integer;
                       SIGNAL dataline : IN std_logic;
                       SIGNAL clk : IN std_logic;
                       CONSTANT line_num : IN natural :=0;        
                       CONSTANT file_name : IN string  := "") is                               
  BEGIN
    wait_N_cycles(bittime/2,clk);
    WAIT FOR 1 ps;
    check_equal(dataline, expected, result("for " & name), line_num => line_num, file_name => file_name);
    -- wait remaining bittime so next call doesnt check at the wrong spot
    wait_N_cycles(bittime/2, clk);
    WAIT FOR 1 ps;
  END PROCEDURE strobe_bit;
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
        check(dataline = '1', "Expected dataline to idle '1'");
        for i in 0 to 100 loop
          wait until rising_edge(clk);
          wait for 1 ps;
          check(dataline = '1', "Expected dataline to idle '1'");
        end loop;
        info("===== TEST CASE FINISHED =====");
      ELSIF run("send_byte_test") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: send_byte_test");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        -- data line should idle
        check(dataline = '1', "Expected dataline to idle '1'");
        data <= "10010001";
        wait_N_cycles(1,clk);
        WAIT FOR 1 ps;
        data_rdy <= '1';
        wait_N_cycles(1,clk);
        WAIT FOR 1 ps; 
        
        -- strobing transmission
        parity := xor data; 
        strobe_bit('0', "start bit", bittime, dataline, clk);
        FOR i IN 0 TO 7 LOOP
          strobe_bit(data(i), "data bit" & to_string(i), bittime, dataline, clk);
        END LOOP;

        -- strobe parity and stop bit
        strobe_bit(parity, "parity bit", bittime, dataline, clk);
        strobe_bit('1', "stop bit", bittime, dataline, clk);
        


        info("===== TEST CASE FINISHED =====");
      ELSIF run("send_multiple_bytes") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: send_multiple_bytes");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        check(dataline = '1', "Expected dataline to idle '1'");
        data <= x"FF";
        wait until rising_edge(clk);
        wait for 1 ps;
        data_rdy <= '1';
        wait_N_cycles(1,clk);
        WAIT FOR 1 ps; 
        data_rdy <= '0';
        -- transmission
        parity := xor data; 
        strobe_bit('0', "start bit", bittime, dataline, clk);
        FOR i IN 0 TO 7 LOOP
          strobe_bit(data(i), "data bit" & to_string(i), bittime, dataline, clk);
        END LOOP;

        -- set new byte
        data <= "11000001";
        data_rdy <= '1';
        
        -- strobe parity and stop bit
        strobe_bit(parity, "parity bit", bittime, dataline, clk);
        strobe_bit('1', "stop bit", bittime, dataline, clk);
        
        -- seamless transmittion
        parity := xor data; 
        strobe_bit('0', "start bit", bittime, dataline, clk);
        FOR i IN 0 TO 7 LOOP
          strobe_bit(data(i), "data bit" & to_string(i), bittime, dataline, clk);
        END LOOP;

        -- strobe parity and stop bit
        strobe_bit(parity, "parity bit", bittime, dataline, clk);
        strobe_bit('1', "stop bit", bittime, dataline, clk);
        info("===== TEST CASE FINISHED =====");
      ELSIF run("change_data_during_transmission") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: change_data_during_transmission");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        data <= "10010001";
        wait_N_cycles(1,clk);
        WAIT FOR 1 ps;
        data_rdy <= '1';
        wait_N_cycles(1,clk);
        WAIT FOR 1 ps; 
        data_rdy <= '0';
        -- strobing transmission
        parity := xor data; 
        strobe_bit('0', "start bit", bittime, dataline, clk);
        FOR i IN 0 TO 3 LOOP
          strobe_bit(data(i), "data bit" & to_string(i), bittime, dataline, clk);
        END LOOP;
        -- store old data for comparison
        old_data := data;
        -- next bit needs to be one regardless of what is data is loaded in the the hold register
        data <= x"00";
        data_rdy <= '1';
        wait for 1 ps;
        -- new data gets asserted during the strobing procedure on the first possible rising edge
        FOR i IN 4 TO 7 LOOP
           strobe_bit(old_data(i), "data bit" & to_string(i), bittime, dataline, clk);
        END LOOP;
        -- strobe parity and stop bit
        strobe_bit(parity, "parity bit", bittime, dataline, clk);
        strobe_bit('1', "stop bit", bittime, dataline, clk);
        info("===== TEST CASE FINISHED =====");
      ELSIF run("reset_during_transmission") THEN
        info("--------------------------------------------------------------------------------");
        info("TEST CASE: reset_during_transmission");
        info("--------------------------------------------------------------------------------");
        WAIT UNTIL rst = '0';
        data <= "10010001";
        wait_N_cycles(1,clk);
        WAIT FOR 1 ps;
        data_rdy <= '1';
        wait_N_cycles(1,clk);
        WAIT FOR 1 ps;
        -- strobing transmission
        parity := xor data; 
        strobe_bit('0', "start bit", bittime, dataline, clk);
        FOR i IN 0 TO 2 LOOP
          strobe_bit(data(i), "data bit" & to_string(i), bittime, dataline, clk);
        END LOOP;
        rst <= '1';
        -- next bit would be one, but reset should put the line back to idling
        FOR i IN 1 TO 100 LOOP
          strobe_bit('1', "idle", bittime, dataline, clk);
        END LOOP;
        rst <= '0';
        -- data_rdy is still high, transmission begins again 
        -- strobing transmission
        parity := xor data; 
        strobe_bit('0', "start bit", bittime, dataline, clk);
        FOR i IN 0 TO 7 LOOP
          strobe_bit(data(i), "data bit" & to_string(i), bittime, dataline, clk);
        END LOOP;

        -- strobe parity and stop bit
        strobe_bit(parity, "parity bit", bittime, dataline, clk);
        strobe_bit('1', "stop bit", bittime, dataline, clk);
        
        info("===== TEST CASE FINISHED =====");
      ELSIF run("idle_between_transmissions") THEN
       info("--------------------------------------------------------------------------------");
       info("TEST CASE: idle-between_transmissions");
       info("--------------------------------------------------------------------------------");
       WAIT UNTIL rst = '0';
        check(dataline = '1', "Expected dataline to idle '1'");
        data <= x"FF";
        wait until rising_edge(clk);
        wait for 1 ps;
        data_rdy <= '1';
        wait_N_cycles(1,clk);
        WAIT FOR 1 ps; 
        data_rdy <= '0';
        -- transmission
        parity := xor data; 
        strobe_bit('0', "start bit", bittime, dataline, clk);
        FOR i IN 0 TO 7 LOOP
          strobe_bit(data(i), "data bit" & to_string(i), bittime, dataline, clk);
        END LOOP;
        
        -- strobe parity and stop bit
        strobe_bit(parity, "parity bit", bittime, dataline, clk);
        strobe_bit('1', "stop bit", bittime, dataline, clk);
        
      
        FOR i IN 0 TO 100 LOOP
          strobe_bit('1', "idle", bittime, dataline, clk);
        END LOOP;
      
        -- set new byte
        data <=x"00";
        data_rdy <= '1';
     
        parity := xor data; 
        strobe_bit('0', "start bit", bittime, dataline, clk);
        FOR i IN 0 TO 7 LOOP
          strobe_bit(data(i), "data bit" & to_string(i), bittime, dataline, clk);
        END LOOP;


       info("===== TEST CASE FINISHED ====="); 
      END IF; -- for test_suite
    END LOOP test_cases_loop;
    WAIT FOR 20 ns;
    test_runner_cleanup(runner); -- end of simulation
  END PROCESS test_runner;

END ARCHITECTURE tb;
