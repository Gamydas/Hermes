----------------------------------------------------------------------------
--  % NAME        : RX.vhd %
--  % PROJECT     : UART Implementation %
--  % VERSION     : 1.0 %
--  % CREATED_BY  : Samy Gad %
--  % DATE_CREATED: 2026-08-18 %
--                                                                        --
--  DESCRIPTION:                                                          --
--  UART Receiver  
--                                                                        --
----------------------------------------------------------------------------
--  REVISION HISTORY                                                      --
--                                                                        --
--  VERSION    DATE        SIGN      CHANGE DESCRIPTION                   --
--  ------- ----------  ----------   ------------------                   --
--  1.0     2026-08-18  Gamy   Initial version.
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
  ENTITY RX IS
    GENERIC(freq : integer := 50_000_000;
            baud : integer := 115200);
    PORT(clk, rst : IN STD_LOGIC;
         Rx : IN std_logic;
         data_out : OUT std_logic_vector(7 DOWNTO 0);
         parity_err: OUT std_logic; 
        );
  END ENTITY RX;

----------------------------------------------------------------------------
-- ARCHITECTURE DECLARATION.
----------------------------------------------------------------------------
ARCHITECTURE rtl OF RX IS

  --------------------------------------------------------------------------
  -- TYPES, RECORDS, INTERNAL SIGNALS, FSM, CONSTANTS DECLARATION.
  --------------------------------------------------------------------------
  TYPE fsm is(idle, start, data, parity, stop);
  SIGNAL state, next_state : fsm;
  SIGNAL start_valid: std_logic;
  -- 16 baud_ticks are one bittime, allows taking multiple samples
  CONSTANT baud_tick : integer := freq/(16*baud);
  -- to quickly decide wether a bit is a 0 or 1 in case of inconsistencies
  SIGNAL bit_sum : integer := 0;
  -- BRG signals
  SIGNAL baud_en  : std_logic;
  SIGNAL baud_gen_en : std_logic;
  SIGNAL tick_cnt : integer := RANGE 0 to 15 := 0; 
  SIGNAL tick : integer := RANGE 0 to baut_tick;
  -- receiver register signals
  SIGNAL rx_shift_reg : std_logic_vector(7 DOWNTO 0);
  SIGNAL data_cnt : integer := RANGE 0 to 8;
  SIGNAL shift_en : std_logic;
  SIGNAL data_in : std_logic;
  -- parity signals
  SIGNAL parity_rdy : std_logic;
  SIGNAL parity_match : std_logic; 
BEGIN  -- start of architecture --


  -- Baud enable generator with an OSR of 16
  -- A simple counter counting to bittime - 1 before resetting.
  -- When baud_cnt reaches bittime - 1 it acts as an enable
  -- for all of the state transitions except idle -> start
  -- It's also the enable of the shift registers serial output
  baud_gen: PROCESS(clk)
  BEGIN
  IF clk = '1' and clk'event THEN
    IF (baud_gen_en = '1') THEN
      tick <= tick + 1;
      -- entering tick counter
      IF (tick = baud_tick - 1) THEN 
        tick <= 0;
        tick_cnt <= tick_cnt + 1;
        -- this samples the incoming bit around the middle of the bittime
        IF (tick_cnt = 6 OR tick_cnt = 7 OR tick_cnt = 8) THEN
          baud_en <= '1';
        ELSE 
          baud_en <= '0';
        END IF;
        -- resets tick_cnt after a full bittime
        IF (tick_cnt = 14) THEN 
          tick_cnt <= 0;
        END IF;
      END IF;
    ELSE tick <= 0;
    END IF;
  END IF;
  END PROCESS;
  
  shift_reg: PROCESS(all)
  BEGIN
    IF (rst = '1') THEN
      rx_shift_reg <= (others => '0');
      data_cnt <= '0';
    ELSIF clk = '1' AND clk'EVENT THEN
      IF shift_en = '1' THEN
        -- receiving data LSB first
        rx_shift_reg <= data_in & rx_shift_reg(7 DOWNTO 1);
      END IF;
    END IF;
  END PROCESS;

  -- process to sample bit and evaluate wether incoming bit is a 1 or a 0
  sample_bit: PROCESS(all);
  BEGIN
    IF (RST = '1') THEN
      start_valid <= '0';
      shift_en <= '0';
      bit_sum <= 0;
    ELSIF clk = '1' AND clk'EVENT THEN
      -- hold shift register until bit is determined
      shift_en <= '0';
      IF (baud_en = '1') THEN
        IF (RX = '1') THEN
          bit_sum <= bit_sum + 1;
        END IF;
        -- sampling phase is over
        IF (tick_cnt = 9) THEN
          -- sampled data needs to be stored
          shift_en <= '1';
          IF (bit_sum >= 2) THEN
            data_in <= '1';
          ELSE 
            data_in <= '0';
            IF (state = start) THEN
              start_valid <= '1';
              -- not a bit that needs to be stored
              shift_en <= '0';
            END IF;
          END IF;
          IF (state = parity) THEN
            -- disable shift reg so parity doesnt shift out LSB
            shift_en <= '0';
            -- parity can be read from data_in on next clock cycle
            parity_rdy <= '1';
          END IF;
          
        END IF;
        bit_sum <= 0;
      END IF;
    END IF;
   END PROCESS;

  -- for now no synchronization during active transmission, i.e. 
  -- Tx needs to start in idle phase

  in_net: PROCESS(all)
  BEGIN
    -- defaults
    next_state <= state;
    CASE state IS
      -- dataline is seen going low, start the BRG
      WHEN idle => IF (Rx = '0') THEN
                     baud_gen_en <= '1';
                     next_state <= start;
                   END IF;
      WHEN start => IF (start_valid = '1' AND tick_cnt = 14) THEN
                      next_state <= data;
                    ELSIF (start_valid = '0' AND tick_cnt = 14 THEN
                      next_state <= idle;
                    END IF;
      WHEN data => IF (data_cnt < 7) THEN
                     next_state <= data;
                   ELSIF (data_cnt >= 7 AND tick_cnt = 14) THEN
                     next_state <= parity;
                   END IF;
      WHEN parity => IF (parity_rdy = '1' AND tick_cnt = 14) THEN
                       IF (data_in /= (rx_shift_reg(0) xor rx_shift_reg(1) xor rx_shift_reg(2) xor 
                           rx_shift_reg(3) xor rx_shift_reg(4) xor rx_shift_reg(5) xor 
                           rx_shift_reg(6) xor rx_shift_reg(7))) THEN
                           parity_err <= '1';
                           next_state <= stop;
                       END IF;
      WHEN stop => IF (
    END CASE;

  --------------------------------------------------------------------------
  -- OUTPUTS ASSIGNMENT
  --------------------------------------------------------------------------
  


END ARCHITECTURE rtl;
