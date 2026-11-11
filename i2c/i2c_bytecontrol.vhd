----------------------------------------------------------------------------
--  % NAME        : i2c_bytecontrol.vhd %
--  % PROJECT     : hermes %
--  % VERSION     : 1.0 %
--  % CREATED_BY  : Samy Gad %
--  % DATE_CREATED:2026-11-07 %
--                                                                        --
--  DESCRIPTION:                                                          --
--  Byte Controller for an I2C Master

--                                                                        --
----------------------------------------------------------------------------
--  REVISION HISTORY                                                      --
--                                                                        --
--  VERSION    DATE        SIGN      CHANGE DESCRIPTION                   --
--  ------- ----------  ----------   ------------------                   --
--  1.0     2026-11-07  Gamy   Initial version.
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
  ENTITY i2c_bytecontrol IS
    PORT(clk: IN  STD_LOGIC;
         rst: IN  STD_LOGIC;
         -- Signals for communication with top level
         master_cmd: IN STD_LOGIC_VECTOR(2 DOWNTO 0); -- master cmd
         master_wdata: IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Byte that master wants to send
         master_rdata: OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- read byte for master
         master_ack: IN STD_LOGIC; -- 0 master ACK, 1 master NACK
         slave_ack: OUT STD_LOGIC; -- 0 slave ACK, 1 slave NACK
         master_done: OUT STD_LOGIC; -- signals master cmd has been executed
         master_req: IN STD_LOGIC; -- master signals new cmd/data pair 
         -- Signals for communication with bit controller  
         request: OUT STD_LOGIC; -- ByC signals BiC a new cmd/bit pair
         bit_i: IN STD_LOGIC;    -- BiC's SDA probes
         bit_o: OUT STD_LOGIC;   -- Serial data that BiC puts onto SDA
         bit_cmd: OUT STD_LOGIC_VECTOR(1 DOWNTO 0); -- CMD for BiC
         bit_done: IN STD_LOGIC  -- BiC signals cmd has been executed
    );
  END ENTITY;

----------------------------------------------------------------------------
-- ARCHITECTURE DECLARATION.
----------------------------------------------------------------------------
ARCHITECTURE rtl OF i2c_bytecontrol IS

  --------------------------------------------------------------------------
  -- TYPES, RECORDS, INTERNAL SIGNALS, FSM, CONSTANTS DECLARATION.
  --------------------------------------------------------------------------
  TYPE FSM is (idle, SSR, write, read); -- SSR: Start/Stop/Reapeat 
  SIGNAL state, next_state: FSM;


  CONSTANT M_START: STD_LOGIC_VECTOR(2 DOWNTO 0) := "000";
  CONSTANT M_STOP: STD_LOGIC_VECTOR(2 DOWNTO 0)  := "001";
  CONSTANT M_WRITE: STD_LOGIC_VECTOR(2 DOWNTO 0) := "010";
  CONSTANT M_READ: STD_LOGIC_VECTOR(2 DOWNTO 0)  := "011";
  CONSTANT M_REAP: STD_LOGIC_VECTOR(2 DOWNTO 0)  := "100";

  CONSTANT B_START: STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
  CONSTANT B_REAP: STD_LOGIC_VECTOR(1 DOWNTO 0)  := "01";
  CONSTANT B_BIT: STD_LOGIC_VECTOR(1 DOWNTO 0)   := "10";
  CONSTANT B_STOP: STD_LOGIC_VECTOR(1 DOWNTO 0)  := "11";

  SIGNAL bit_cnt: INTEGER range 0 to 8; 
  SIGNAL w_reg, r_reg: STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL bit_osel: STD_LOGIC_VECTOR(1 DOWNTO 0);
  SIGNAL load: STD_LOGIC;
  SIGNAL done_intern: STD_LOGIC; -- to avoid accepting a command twice
  --------------------------------------------------------------------------
  -- COMPONENTS DECLARATION
  --------------------------------------------------------------------------



BEGIN  -- start of architecture --


  --------------------------------------------------------------------------
  -- COMPONENTS INSTANTIATION
  --------------------------------------------------------------------------
  

  -------------------------------------------------------------------------
  -- COMBINATIONAL LOGIC
  --------------------------------------------------------------------------

  WITH bit_osel SELECT
    bit_o <= w_reg(7)   WHEN "00",
             '1'        WHEN "01",
             master_ack WHEN "10",
             '1'        WHEN OTHERS; 

  -- this allows checking for done = '0' in idle to avoid accepting the same cmd twice
  master_done <= done_intern;
  --------------------------------------------------------------------------
  -- SEQUENTIAL LOGIC
  --------------------------------------------------------------------------
  
  --------------------------------------------------------------------------
  -- FSM
  --------------------------------------------------------------------------
  
  in_net: PROCESS(state, bit_done, bit_cnt, master_req, master_cmd, done_intern)
  BEGIN
    next_state <= state;
    load <= '0';
    CASE state IS
      WHEN idle => IF (master_req = '1' AND done_intern = '0') THEN
                     CASE master_cmd IS 
                       WHEN M_START => next_state <= SSR; 
                       WHEN M_STOP => next_state  <= SSR; 
                       WHEN M_REAP => next_state  <= SSR;
                       WHEN M_WRITE => next_state <= write; load <= '1';
                       WHEN M_READ => next_state  <= read; 
                       WHEN OTHERS => NULL;
                     END CASE;
                   END IF;
      WHEN SSR => IF (bit_done = '1') THEN 
                    next_state <= idle;
                  END IF;
      WHEN write => IF (bit_cnt = 8 AND bit_done = '1') THEN
                      next_state <= idle;
                    END IF;
      WHEN read => IF (bit_cnt = 8 AND bit_done = '1') THEN
                     next_state <= idle;
                   END IF;
    END CASE;
  END PROCESS;

  mem: PROCESS(clk, rst)
  BEGIN
    IF rst = '1' THEN
      state <= idle;
    ELSIF clk = '1' AND clk'Event THEN
      state <= next_state;
    END IF;
  END PROCESS;

  out_net: PROCESS(clk, rst)
  BEGIN
    IF rst = '1' THEN
      w_reg <= (others => '0');
      r_reg <= (others => '0');
      bit_osel <= "00";
      bit_cnt <= 0;
      done_intern <= '0';
      request <= '0';
      slave_ack <= '1'; -- '1' = NACK
      bit_cmd <= "00";
      master_rdata <= (others => '0');
    ELSIF clk = '1' AND clk'event THEN
      -- loading master data
      IF load = '1' THEN
        w_reg <= master_wdata;
      END IF;
      done_intern <= '0';
      request <= '0';
      CASE state IS
        WHEN idle => IF (master_req = '1' AND done_intern = '0') THEN
                       CASE master_cmd IS 
                         WHEN M_START => bit_cmd <= B_START; 
                         WHEN M_STOP =>  bit_cmd <= B_STOP;
                         WHEN M_REAP =>  bit_cmd <= B_REAP;
                         WHEN M_WRITE => bit_cmd <= B_BIT; 
                         WHEN M_READ =>  bit_cmd <= B_BIT;
                         WHEN OTHERS => done_intern <= '1';
                       END CASE;
                     END IF;
        WHEN SSR =>  request <= '1';
                     IF (bit_done = '1') THEN
                       done_intern <= '1'; 
                     END IF;
        WHEN write =>request <= '1';
                     bit_osel <= "00";
                     IF (bit_cnt < 8 AND bit_done = '1') THEN
                       w_reg <= w_reg(6 DOWNTO 0) & '0';
                       bit_cnt <= bit_cnt + 1;
                     ELSIF (bit_cnt = 8) THEN
                       bit_osel <= "01";
                       IF (bit_done = '1') THEN
                       slave_ack <= bit_i;    -- hand master slave ack
                       done_intern <= '1';    -- signal master finished action
                       bit_cnt <= 0;
                       END IF;
                     END IF;
        WHEN read => request <= '1';
                     bit_osel <= "01";
                     IF (bit_cnt < 8 AND bit_done = '1') THEN
                       r_reg <= r_reg(6 DOWNTO 0) & bit_i;
                       bit_cnt <= bit_cnt + 1;
                     ELSIF (bit_cnt = 8) THEN
                       bit_osel <= "10";
                       IF (bit_done = '1') THEN
                         master_rdata <= r_reg; -- hand master read data
                         done_intern <= '1';    -- signal master finished action
                         bit_cnt <= 0;
                       END IF;
                     END IF;
      END CASE;
    END IF;
  END PROCESS;

  --------------------------------------------------------------------------
  -- OUTPUTS ASSIGNMENT
  --------------------------------------------------------------------------
  


END ARCHITECTURE;
