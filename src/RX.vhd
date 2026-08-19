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
         parity_err: OUT std_logic
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
  SIGNAL stop_valid: std_logic;
  -- 16 baud_ticks are one bittime, allows taking multiple samples
  CONSTANT baud_tick : integer := freq/(16*baud);
  -- to quickly decide wether a bit is a 0 or 1 in case of inconsistencies
  SIGNAL bit_sum  : integer RANGE 0 TO 81 := 0;
  SIGNAL eval_rst : std_logic;
  -- BRG signals
  SIGNAL baud_en  : std_logic;
  SIGNAL baud_gen_en : std_logic;
  SIGNAL tick_cnt : integer RANGE 0 TO 16 := 0; 
  SIGNAL tick : integer  RANGE 0 to baud_tick;
  -- receiver register signals
  SIGNAL rx_shift_reg : std_logic_vector(7 DOWNTO 0);
  SIGNAL data_cnt : integer RANGE 0 to 8 := 0;
  SIGNAL shift_en : std_logic;
  SIGNAL data_in : std_logic;
  -- parity signals
  SIGNAL parity_rdy : std_logic;
  SIGNAL par_err : std_logic; 
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
        IF (tick_cnt = 15) THEN
          tick_cnt <= 0;
        END IF;
      END IF;
    ELSE 
      tick <= 0;
      tick_cnt <= 0;
      baud_en <= '0';
    END IF;
  END IF;
  END PROCESS;
  
  shift_reg: PROCESS(all)
  BEGIN
    IF (rst = '1') THEN
      rx_shift_reg <= (others => '0');
      data_cnt <= 0;
    ELSIF clk = '1' AND clk'EVENT THEN
      IF shift_en = '1' THEN
        -- receiving data LSB first
        rx_shift_reg <= data_in & rx_shift_reg(7 DOWNTO 1);
        data_cnt <= data_cnt + 1;
      END IF;
    END IF;
  END PROCESS;

  
  -- process to sample bit and evaluate wether incoming bit is a 1 or a 0
  eval_bit: PROCESS(all)
  BEGIN
    IF clk = '1' AND clk'EVENT THEN
      IF (eval_rst = '0' AND rst = '0') THEN
       
        -- add up samples for comparison
        IF (baud_en = '1' AND RX = '1') THEN
          bit_sum <= bit_sum + 1;
        END IF;

        -- sampling phase is over
        IF (tick_cnt = 9) THEN
          -- sampled a 1 
          IF (bit_sum >= 41) THEN
            data_in <= '1';
            -- check for valid stop bit
            IF (state = stop) THEN
            stop_valid <= '1';
            END IF;
          ELSE 
        
            -- sampled a 0
            data_in <= '0';
            -- check for valid start bit
            IF (state = start) THEN
              start_valid <= '1';
            END IF;
          END IF;
        
          -- check parity
          IF (state = parity) THEN
            -- parity can be read from data_in on next clock cycle
            parity_rdy <= '1';
          END IF; 

        END IF;
        IF (tick_cnt = 15) THEN
          -- reset bit_sum
          bit_sum <= 0;
        END IF;
      ELSE
        start_valid <= '0';
        stop_valid <= '0';
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
    eval_rst <= '0';
    shift_en <= '0';
    CASE state IS
      -- dataline is seen going low, start the BRG
      WHEN idle   => IF (Rx = '0') THEN
                       baud_gen_en <= '1';
                       next_state <= start;
                     END IF;
                     eval_rst <= '1';
      WHEN start  => IF (start_valid = '1' AND tick_cnt = 15 AND tick = baud_tick - 1) THEN
                       next_state <= data;
                     ELSIF start_valid = '0' AND tick_cnt = 15 THEN
                       next_state <= idle;
                     END IF;
      WHEN data   => IF (data_cnt < 8 AND tick_cnt = 10 AND tick = baud_tick - 1) THEN
                       shift_en <= '1';
                     ELSIF (data_cnt >= 8 AND tick_cnt = 15 AND tick = baud_tick - 1) THEN
                       next_state <= parity;
                     END IF;
      WHEN parity => IF (parity_rdy = '1' AND tick_cnt = 15 AND tick = baud_tick - 1) THEN
                       next_state <= stop;
                     END IF;
      WHEN stop   => IF (tick_cnt = 15 AND tick = baud_tick - 1) THEN
                       next_state <= start;
                       eval_rst <= '1'; --?
                     END IF;
    END CASE;
  END PROCESS;
  
  
  mem: PROCESS(clk, rst)
  BEGIN
    IF(rst = '1') THEN
      state <= idle;
    ELSIF clk = '1' and clk'EVENT THEN
      state <= next_state;
    END IF;
  END PROCESS;
  

  -- only parity and stop states determine Rx output, output is to be 0 at all other states
  out_net: PROCESS(all)
  BEGIN
    IF rst = '1' THEN
      data_out <= (others => '0');
      par_err <= '0';
    ELSIF clk = '1' AND clk'EVENT THEN
      CASE state IS
        WHEN parity => IF (tick_cnt >= 10) THEN
                         IF (data_in /= (rx_shift_reg(0) xor rx_shift_reg(1) xor rx_shift_reg(2) xor 
                           rx_shift_reg(3) xor rx_shift_reg(4) xor rx_shift_reg(5) xor 
                           rx_shift_reg(6) xor rx_shift_reg(7))) THEN
                           -- parity doesnt match
                           par_err <= '1';
                         ELSE par_err <= '0';
                         END IF;
                       END IF; 
        WHEN stop   => IF (tick_cnt >= 9) THEN
                         IF (par_err = '1' OR stop_valid = '0') THEN
                           data_out <= (others => '0');
                         ELSE data_out <= rx_shift_reg;
                         END IF;
                       ELSE data_out <= (others => '0');
                       END IF;
        WHEN OTHERS => null;
      END CASE;
    END IF;
  END PROCESS;
  

  eval_parity: PROCESS(clk, rst)
  BEGIN
    IF rst = '1' THEN
      par_err <= '0';
    ELSIF clk = '1' AND clk'EVENT THEN
      IF (state = parity AND tick_cnt >= 10) THEN

      END IF;
    END IF;
  END PROCESS;
  --------------------------------------------------------------------------
  -- OUTPUTS ASSIGNMENT
  --------------------------------------------------------------------------
  parity_err <= par_err;


END ARCHITECTURE rtl;
