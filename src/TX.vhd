----------------------------------------------------------------------------
--  % NAME        : TX_wbrg.vhd %
--  % PROJECT     : UART %
--  % VERSION     : 1.0 %
--  % CREATED_BY  : Samy Gad %
--  % DATE_CREATED: 2026-08-16 %
--                                                                        --
--  DESCRIPTION:                                                          --
--  FSM based UART Transmitter. BRG as a process within the module
--                                                                        --
----------------------------------------------------------------------------
--  REVISION HISTORY                                                      --
--                                                                        --
--  VERSION    DATE        SIGN      CHANGE DESCRIPTION                   --
--  ------- ----------  ----------   ------------------                   --
--  1.0     2026-08-16  Gamy   Initial version.
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


----------------------------------------------------------------------------
-- ENTITY DECLARATION.
----------------------------------------------------------------------------
  ENTITY TX_wbrg IS
    GENERIC(freq: positive := 50_000_000;
            baud: positive := 115200);
    PORT(clk,rst, data_rdy : IN  STD_LOGIC;
         data_in : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
         data_out, status : OUT std_logic
    );
  END ENTITY TX_wbrg;

----------------------------------------------------------------------------
-- ARCHITECTURE DECLARATION.
----------------------------------------------------------------------------
ARCHITECTURE rtl OF TX_wbrg IS

  --------------------------------------------------------------------------
  -- TYPES, RECORDS, INTERNAL SIGNALS, FSM, CONSTANTS DECLARATION.
  --------------------------------------------------------------------------
  type fsm is (idle, start, data, parity, stop);
  SIGNAL state, next_state : fsm;
  
  CONSTANT bittime : integer := freq/BAUD;
  SIGNAL baud_cnt : integer range 0 to bittime := 0;
  SIGNAL baud_cnt_en : std_logic;
  SIGNAL tx_shift_reg : std_logic_vector(7 downto 0);
  SIGNAL tx_hold_reg : std_logic_vector(7 downto 0);
  SIGNAL even_parity : std_logic;
  SIGNAL shift_load, shift_out: std_logic;
  SIGNAL data_cnt : integer range 0 to 10 := 0;


BEGIN  -- start of architecture --

  -- Baud enable generator.
  -- A simple counter counting to bittime - 1 before resetting.
  -- When baud_cnt reaches bittime - 1 it acts as an enable
  -- for all of the state transitions except idle -> start
  -- It's also the enable of the shift registers serial output
  baud_gen: PROCESS(clk)
  BEGIN
  IF clk = '1' and clk'event THEN
    IF (baud_cnt_en = '1') THEN
      baud_cnt <= baud_cnt + 1;
      -- signals are only asserted at the end of a process
      -- so this resets baud_cnt when the above line 
      -- technically transitiosn from bittime-1 -> bittime
      IF (baud_cnt = bittime - 1) THEN 
        baud_cnt <= 0;
      END IF;
    ELSE baud_cnt <= 0;
    END IF;
  END IF;
  END PROCESS;

  -- The holding register of the transmitter.
  -- Acts as a buffer for the transmitter to store data in while
  -- idling and once the data has been asserted by the shift register
  -- the source can push a new package, as packages are only asserted
  -- to the shift register during idle state
  hold_reg: PROCESS(all)
  BEGIN
    IF (rst = '1') THEN
      tx_hold_reg <= (others => '0');
    ELSIF clk = '1' and clk'EVENT THEN
      tx_hold_reg <= data_in;
    END IF;
  END PROCESS;

  -- The sending register of the Transmitter.
  -- Loads the holding registers contents on the first possible
  -- clock rising edge and then pushes one bit onto the dataline
  -- after exactly one bit time until the entire package is transmitted
  shift_reg: PROCESS(all)
  BEGIN
    IF (rst = '1') THEN
      tx_shift_reg <= (others => '0');
      data_cnt <= 0;
    ELSIF clk = '1' and clk'EVENT THEN
      -- load path
      IF data_rdy = '1' and (state = idle OR state = start) THEN
        tx_shift_reg <= tx_hold_reg;
        even_parity <= tx_hold_reg(0) xor tx_hold_reg(1) xor tx_hold_reg(2) xor tx_hold_reg(3)
		                 xor tx_hold_reg(4) xor tx_hold_reg(5) xor tx_hold_reg(6) xor tx_hold_reg(7);
      END IF;
      -- shift path
      IF baud_cnt = bittime -1 THEN
        -- bittime finished, push out lsb
        shift_out <= tx_shift_reg(0);
        tx_shift_reg <= '0' & tx_shift_reg(7 downto 1);
        data_cnt <= data_cnt + 1;
      END IF;
      -- resets data_cnt between packages
      IF state /= data THEN data_cnt <= 0;
      END IF;
    END IF;
  END PROCESS;

  --------------------------------------------------------------------------
  -- FSM
  --------------------------------------------------------------------------

  in_net: PROCESS(all)
  BEGIN
    -- defaults
    next_state <= state;
    baud_cnt_en <= '1';
    -- signalling that data can be received
    status <= '0';
    case state is 
      when idle => IF (data_rdy = '1') THEN
                     next_state <= start;             
                   END IF;        
                   -- hold counter while idling 
                   baud_cnt_en <= '0'; 
      when start=> IF (baud_cnt = bittime-1) THEN
                     -- hold state for one bittime
                     next_state <= data;
                   END IF;
                   -- signal source that packages has been accepted
                   status <= '1';
      when data => IF (data_cnt < 7) THEN
                   -- hold data state during transmission
                      next_state <= data;
                   ELSIF data_cnt >= 7 and baud_cnt = bittime-1 THEN 
                     -- final data bit is being transmitted in this cycle
                     -- so we prepare the fsm to transition to parity state
                     next_state <= parity;
                   END IF;
      when parity => IF (baud_cnt = bittime-1) THEN
                     -- hold state for one bittime
                     next_state <= stop;
                     END IF;            
      when stop => IF (baud_cnt = bittime-1) THEN
                     -- hold state for one bittime
                     
                     -- if there is a new package ready restart transmission
                     IF (data_rdy = '1') THEN
                       next_state <= start;
                     ELSE
                       -- no new package, go back to idling
                       next_state <= idle;
                     END IF;
                   END IF;
    END CASE;
  END PROCESS;

  -- state memory
  mem: PROCESS(clk, rst)
  BEGIN 
    IF(rst = '1') THEN
      state <= idle;
    ELSIF clk = '1' and clk'event THEN 
      state <= next_state; 
    END IF;
  END PROCESS;

  -- dataline multiplexer, in_net ensures changes only occur on bittime edges
  out_net: PROCESS(all)
  BEGIN
    case state is
      when idle => data_out <= '1';
      when start => data_out <= '0';
      when data => data_out <= shift_out;
      when parity => data_out <= even_parity;
      when stop => data_out <= '1';
    END CASE;
  END PROCESS;
  
END ARCHITECTURE rtl;
