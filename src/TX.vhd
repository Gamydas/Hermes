----------------------------------------------------------------------------
--  % NAME        : TX.vhd %
--  % PROJECT     : UART Protocol Implementation %
--  % VERSION     : 1.0 %
--  % CREATED_BY  : Samy Gad %
--  % DATE_CREATED: 2026-08-15 %
--                                                                        --
--  DESCRIPTION:                                                          --
--  UART Transmitter side FSM driven module
--                                                                        --
----------------------------------------------------------------------------
--  REVISION HISTORY                                                      --
--                                                                        --
--  VERSION    DATE        SIGN      CHANGE DESCRIPTION                   --
--  ------- ----------  ----------   ------------------                   --
--  1.0     2026-08-15  Gamy   Initial version.
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
  ENTITY TX IS
    GENERIC(freq: integer := 50_000_000;
            baud: integer := 115200);
    -- OSR is not passed to TX as oversampling is irrelevant to the transmitter
    PORT(data_in  : IN std_logic_vector(7 DOWNTO 0);
         data_rdy, clk,rst : IN  STD_LOGIC;
         data_out : OUT std_logic
    );
  END ENTITY TX;

----------------------------------------------------------------------------
-- ARCHITECTURE DECLARATION.
----------------------------------------------------------------------------
ARCHITECTURE rtl OF TX IS

  --------------------------------------------------------------------------
  -- TYPES, RECORDS, INTERNAL SIGNALS, FSM, CONSTANTS DECLARATION.
  --------------------------------------------------------------------------
  type fsm is (idle, data, parity, stop);
  SIGNAL state, next_state : fsm;
  
  SIGNAL tx_enable : std_logic;
  SIGNAL tx_send_reg : std_logic_vector(7 downto 0);
  SIGNAL tx_hold_reg : std_logic_vector(7 downto 0);
  SIGNAL sync, even_parity : std_logic;
  SIGNAL shift_load, shift_out: std_logic;
  SIGNAL data_cnt : integer range 0 to 8 := 0;
  --------------------------------------------------------------------------
  -- COMPONENTS DECLARATION.
  --------------------------------------------------------------------------

  COMPONENT BRG IS
    GENERIC(freq: integer := 50_000_000;
            baud: integer := 115200;
            OSR : integer := 16);
    PORT(clk, sync, rst : IN  STD_LOGIC;
         tx_enable : OUT STD_LOGIC; 
         rx_enable : OUT STD_LOGIC 
       );
  END COMPONENT; 

BEGIN  -- start of architecture --
  
  baud_gen : BRG
  GENERIC MAP(freq => freq, baud => baud , OSR => 1)
  PORT MAP(clk => clk, 
           sync => sync, 
           rst => rst, 
           tx_enable => tx_enable,
           rx_enable => open);
           
  --------------------------------------------------------------------------
  -- FSM 
  --------------------------------------------------------------------------
  
  hold_reg: PROCESS(all)
  BEGIN
    IF (rst = '1') THEN
      tx_hold_reg <= (others => '0');
    ELSIF clk = '1' and clk'EVENT THEN
      tx_hold_reg <= data_in;
    END IF;
  END PROCESS;
  
  send_reg: PROCESS(all)
  BEGIN
    IF (rst = '1') THEN
      tx_send_reg <= (others => '0');
      data_cnt <= 0;
    ELSIF (shift_load = '1') THEN
      tx_send_reg <= tx_hold_reg;
      even_parity <= tx_hold_reg(7) XOR tx_hold_reg(6) XOR 
                     tx_hold_reg(5) XOR tx_hold_reg(4) XOR
                     tx_hold_reg(3) XOR tx_hold_reg(2) XOR
                     tx_hold_reg(1) XOR tx_hold_reg(0);  
    ELSIF tx_enable = '1' and tx_enable'EVENT THEN
      -- shift out LSB
      shift_out <= tx_send_reg(0);
      data_cnt <= data_cnt + 1;
      tx_send_reg <= '0' & tx_send_reg(7 DOWNTO 1);
      
    END IF;
  END PROCESS;

  in_net: PROCESS(all)
  BEGIN
    -- defaults
    shift_load <= '0'; 
    sync <= '0'; 
    case state is 
      when idle => IF (data_rdy = '1') THEN
                     next_state <= data;
                     shift_load <= '1';
                   ELSE 
                     next_state <= idle;
                     -- hold counter
                     sync <= '1';
                   END IF;
      when data => IF (data_cnt < 8) THEN
                     next_state <= data;
                   ELSE
                     next_state <= parity;
                   END IF;
      when parity => next_state <= stop;
      when stop => IF (data_rdy = '1') THEN
                     next_state <= data;
                     shift_load <= '1';
                   ELSE
                     next_state <= idle;
                     -- reset/hold counter
                     sync <= '1';
                   END IF;
      when others => next_state <= idle;
    END CASE;
  END PROCESS;

  mem: PROCESS(clk, rst)
  BEGIN 
    IF(rst = '1') THEN
      state <= idle;
    ELSIF clk = '1' and clk'event THEN
      state <= next_state;
    END IF;
  END PROCESS;

  out_net: PROCESS(all)
  BEGIN
    case state is
      when idle => IF (data_rdy = '1') THEN 
                        data_out <='0';
                   ELSE data_out <= '1';
                   END IF;
      when data => data_out <= shift_out;
      when parity => data_out <= even_parity;
      when stop => data_out <= '1';
    END CASE;
  END PROCESS;

END ARCHITECTURE rtl;
