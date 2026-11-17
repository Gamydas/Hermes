LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


PACKAGE generic_procedures is

  PROCEDURE wait_N_cycles(CONSTANT N: IN natural; SIGNAL CLK : IN std_logic);
  PROCEDURE reset_dut(signal rst: OUT std_logic; SIGNAL CLK : IN std_logic);

END PACKAGE generic_procedures;

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


PACKAGE BODY generic_procedures is

  PROCEDURE wait_N_cycles(CONSTANT N: IN natural; SIGNAL CLK : IN std_logic) is 
    BEGIN
      FOR i IN 0 TO N-1 LOOP
        WAIT UNTIL RISING_EDGE(CLK);
      END LOOP;
    END PROCEDURE wait_N_cycles; 
  
  PROCEDURE reset_dut(signal rst: OUT std_logic; SIGNAL CLK : IN std_logic) is
  BEGIN 
    rst <= '1';
    wait_N_cycles(2, clk);
    wait for 1 ps; -- to drop the reset to cleanly start the design outside of a rising edge
    rst <= '0';
  
  END PROCEDURE reset_dut;

END PACKAGE BODY generic_procedures;
