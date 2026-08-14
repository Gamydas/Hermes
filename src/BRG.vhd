----------------------------------------------------------------------------
--  % NAME        : BRG.vhd %
--  % PROJECT     : UART Implementation %
--  % VERSION     : 1.0 %
--  % CREATED_BY  : Samy Gad %
--  % DATE_CREATED: 2026-08-14 %
--                                                                        --
--  DESCRIPTION:                                                          --
--  Baud Rate Generator for a UART implementation
--                                                                        --
----------------------------------------------------------------------------
--  REVISION HISTORY                                                      --
--                                                                        --
--  VERSION    DATE        SIGN      CHANGE DESCRIPTION                   --
--  ------- ----------  ----------   ------------------                   --
--  1.0     2026-08-14  Gamy   Initial version.
--                                                                        --


----------------------------------------------------------------------------
-- LIBRARY DECLARATION.
----------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


----------------------------------------------------------------------------
-- ENTITY DECLARATION.
----------------------------------------------------------------------------
  ENTITY BRG IS
    GENERIC(freq: integer := 50_000_000;
            baud: integer := 115200;
            OSR : integer := 16);
    PORT(clk, enable, rst : IN  STD_LOGIC;
         tx_enable : OUT STD_LOGIC; 
         rx_enable : OUT STD_LOGIC 
       );
  END ENTITY BRG;

----------------------------------------------------------------------------
-- ARCHITECTURE DECLARATION.
----------------------------------------------------------------------------
ARCHITECTURE rtl OF BRG IS

  --------------------------------------------------------------------------
  -- TYPES, RECORDS, INTERNAL SIGNALS, FSM, CONSTANTS DECLARATION.
  --------------------------------------------------------------------------
  
  -- OSR amount of ticks equal one full bittime  
  -- the amount of clock cycles 
  constant tick : integer := freq/(OSR*baud);
  -- 1/2 bittime 
  constant mid_bit_point : integer := OSR/2;
  signal cnt : integer range 0 to tick - 1 := 0; 
  signal tick_cnt : integer range 0 to OSR - 1   := 0;
  
BEGIN  -- start of architecture --

  --------------------------------------------------------------------------
  -- SEQUENTIAL LOGIC
  --------------------------------------------------------------------------
  Baud_gen: PROCESS (all)
  BEGIN
    IF (rst = '1') THEN
      cnt <= 0;
      tick_cnt  <= 0; 
      rx_enable <= '0'; 
      tx_enable <= '0'; 
    ELSIF clk = '1' and clk'EVENT THEN
      rx_enable <= '0'; -- default value
      tx_enable <= '0'; -- default value
      IF (enable = '1') THEN
        IF (cnt = tick - 1) THEN
          -- counter reset
          cnt <= 0; 
          -- midbit_point -1 reached in this tick, send rx_enable pulses to signal receiver to sample now
          IF (tick_cnt = mid_bit_point - 2 OR tick_cnt = mid_bit_point - 1 OR tick_cnt = mid_bit_point) THEN
            -- default value ensures pulsewidth is one
            rx_enable <= '1';
          END IF;
          -- full cycle done, set tx_enable high to signal that another bit can be send
          IF (tick_cnt = OSR-1) THEN
            -- default value ensures pulsewidth is one
            tx_enable <= '1';
            -- counter reset
            tick_cnt <= 0; 
          ELSE 
            tick_cnt <= tick_cnt + 1;
          END IF;
        ELSE
          cnt <= cnt + 1;
        END IF;
      END IF;
    END IF;
  END PROCESS Baud_gen;

END ARCHITECTURE rtl;
