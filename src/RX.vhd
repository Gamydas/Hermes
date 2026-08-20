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
--  1.0  2026-08-18  Gamy   Initial version.
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
    PORT(clk, rst, Rx : IN STD_LOGIC;
         data_out  : OUT std_logic_vector(7 DOWNTO 0);
         parity_err, frame_err : OUT std_logic
        );
  END ENTITY RX;

----------------------------------------------------------------------------
-- ARCHITECTURE DECLARATION.
----------------------------------------------------------------------------
ARCHITECTURE rtl OF RX IS

  --------------------------------------------------------------------------
  -- TYPES, RECORDS, INTERNAL SIGNALS, FSM, CONSTANTS DECLARATION.
  --------------------------------------------------------------------------
  SIGNAL bit_end : std_logic;
  -- FSM Signals
  TYPE fsm is(idle, start, data, parity, stop);
  SIGNAL state, next_state : fsm;
  SIGNAL start_val: std_logic;
  SIGNAL stop_val: std_logic;
  -- to quickly decide wether a bit is a 0 or 1 in case of inconsistencies
  SIGNAL eval_bit : std_logic_vector(2 DOWNTO 0);
  SIGNAL eval_rst : std_logic;
  SIGNAL val : std_logic;
  -- BRG signals
  CONSTANT baud_tick : integer := freq/(16*baud);
  -- due to rounding, 16*baud_tick would cause errors when baud_tick is getting rounded
  -- more than 0.5 
  CONSTANT tick_amt : integer := (freq/baud)/baud_tick;
  CONSTANT bit_mid : integer := tick_amt/2;
  SIGNAL baud_gen_en : std_logic;
  SIGNAL tick_cnt : integer RANGE 0 TO tick_amt := 0; 
  SIGNAL tick : integer  RANGE 0 to baud_tick;
  -- receiver register signals
  SIGNAL rx_shift_reg : std_logic_vector(7 DOWNTO 0);
  SIGNAL data_cnt : integer RANGE 0 to 8 := 0;
  SIGNAL shift_en : std_logic;
  SIGNAL data_in : std_logic;
  -- parity signals
  SIGNAL parity_val : std_logic;
  SIGNAL par_err : std_logic; 
BEGIN  -- start of architecture --

  --------------------------------------------------------------------------
  -- Combinational Logic 
  --------------------------------------------------------------------------
  -- Concurrent bit evaluation. This is gibberish when sampled before
  -- tick_cnt = 10, so keep that in mind when changing something
  val <= ((eval_bit(0) AND eval_bit(1)) OR 
          (eval_bit(1) AND eval_bit(2))  OR
          (eval_bit(0) AND eval_bit(2)));
  -- This Signal exists to make the transition logic in the FSM more readable
  bit_end <= '1' WHEN tick_cnt = tick_amt-1 AND tick = baud_tick - 1 ELSE
             '0';

  -- Baud enable generator with an OSR of 16
  -- After 16 ticks the bittime is over
  baud_gen: PROCESS(clk)
  BEGIN
  IF clk = '1' and clk'event THEN
    IF (baud_gen_en = '1') THEN
      tick <= tick + 1;
      -- entering tick counter
      IF (tick = baud_tick - 1) THEN 
        tick <= 0;
        tick_cnt <= tick_cnt + 1;
        -- resets tick_cnt after a full bittime
        IF (tick_cnt = tick_amt-1) THEN
          tick_cnt <= 0;
        END IF;
      END IF;
    ELSE 
      tick <= 0;
      tick_cnt <= 0;
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
      -- resets data_cnt between packages
      IF state /= data THEN data_cnt <= 0;
      END IF;
    END IF;
  END PROCESS;

  
  -- Bits get sampled in a 3 bit shift register. Evaluation happens concurrently.
  -- The result is written via a demux driven by the FSM to the appropriate signal
  -- when tick_cnt = 10.
  sample_bit: PROCESS(all)
  BEGIN
    IF clk = '1' AND clk'EVENT THEN
      IF (eval_rst = '0' AND rst = '0') THEN
       
        -- samples the bit a fixed 3 times instead of over the entire
        -- validity window as in old implementation
        IF (tick_cnt = bit_mid-1 OR tick_cnt = bit_mid OR tick_cnt = bit_mid+1) AND tick = baud_tick-1 THEN
          eval_bit <= Rx & eval_bit(2 DOWNTO 1);
        END IF;

        -- sampling phase is over
        IF (tick_cnt = bit_mid+2) THEN
          -- state driven demultiplexer to correctly assign evaluated bit
          -- to the correct state signals
          CASE state IS
            WHEN start   => start_val <= val;
            WHEN data    => data_in <= val;
            WHEN parity  => parity_val <= val;
            WHEN stop    => stop_val <= val;
            WHEN others  => null; -- nothing to evaluate during idle
          END CASE;
        END IF;
      ELSE
        -- start_val gets reset to 1 as 0 is the expected result
        start_val <= '1';
        data_in <= '0';
        parity_val <= '0';
        stop_val <= '0';
      END IF;
    END IF;
   END PROCESS;


  --------------------------------------------------------------------------
  -- FSM 
  --------------------------------------------------------------------------
  
  -- for now no synchronization during active transmission, i.e. 
  -- Tx needs to start in idle phase
  in_net: PROCESS(all)
  BEGIN
    -- defaults
    next_state <= state;
    eval_rst <= '0';
    shift_en <= '0';
    baud_gen_en <= '1';
    -- this case is used to get the receiver out of the idle state
    -- and to to drive shift_en at the end of a sampling period
    CASE state IS
      -- dataline is seen going low, start the BRG
      WHEN idle   => IF (Rx = '0') THEN
                       next_state <= start;
                     ELSE 
                       baud_gen_en <= '0';
                     END IF;
                     eval_rst <= '1';
      WHEN data   => IF (data_cnt < 8 AND tick_cnt = bit_mid+3 AND tick = baud_tick - 1) THEN
                       shift_en <= '1'; 
                     END IF;
      WHEN OTHERS => null;
    END CASE;
    -- state transition block for all transitions that require the end of a bittime
    IF bit_end = '1' THEN
      CASE state IS 
        WHEN start  => IF (start_val = '0') THEN next_state <= data;
                       ELSE next_state <= idle;
                       END IF;
        WHEN data   => IF (data_cnt >= 8) THEN next_state <= parity; 
                       END IF;
        WHEN parity => next_state <= stop;
        WHEN stop   => next_state <= start;
                       eval_rst <= '1';
        WHEN OTHERS => null;
      END CASE;
    END IF; 
  END PROCESS;
  
  
  mem: PROCESS(clk, rst)
  BEGIN
    IF(rst = '1') THEN
      state <= idle;
    ELSIF clk = '1' and clk'EVENT THEN
      state <= next_state;
    END IF;
  END PROCESS;
  

  out_net: PROCESS(all)
  BEGIN
    IF rst = '1' THEN
      data_out <= (others => '0');
      par_err <= '0';
      parity_err <= '0';
      frame_err <= '0';
    ELSIF clk = '1' AND clk'EVENT THEN
      IF (tick_cnt = bit_mid+3) THEN
        CASE state IS
          WHEN parity => IF (parity_val /= (rx_shift_reg(0) xor rx_shift_reg(1) xor
                                            rx_shift_reg(2) xor rx_shift_reg(3) xor 
                                            rx_shift_reg(4) xor rx_shift_reg(5) xor 
                                            rx_shift_reg(6) xor rx_shift_reg(7))) THEN
                         -- parity gets calculated and a possible error is stored
                         -- only in the stop phase do we output the error flag to 
                         -- keep flags and data in sync
                           par_err <= '1';
                         ELSE par_err <= '0';
                         END IF;
          WHEN stop   => -- stop_val = 0 -> error, stop_val = 1 -> no error
                         frame_err <= not stop_val; 
                         -- to keep parity and data synced we output parity here
                         -- and not in the parity state
                         parity_err <= par_err;
                         -- write data even if errors occur, Rx owner has to decide
                         -- what to do with faulty packages
                         data_out <= rx_shift_reg;
          WHEN OTHERS => null;
        END CASE;
      END IF;
    END IF;
  END PROCESS;
  

END ARCHITECTURE rtl;
