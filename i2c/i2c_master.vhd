----------------------------------------------------------------------------
--  % NAME        : i2c_master.vhd %
--  % PROJECT     : Hermes %
--  % VERSION     : 1.0 %
--  % CREATED_BY  : Samy Gad %
--  % DATE_CREATED: 2026-11-11 %
--                                                                        --
--  DESCRIPTION:                                                          --
--  Top Level Entity of an I2C Master
--                                                                        --
----------------------------------------------------------------------------
--  REVISION HISTORY                                                      --
--                                                                        --
--  VERSION    DATE        SIGN      CHANGE DESCRIPTION                   --
--  ------- ----------  ----------   ------------------                   --
--  1.0     2026-11-11  Gamy   Initial version.
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
  ENTITY i2c_master IS
    GENERIC (SYSfreq: integer := 125_000_000;
             SCLfreq: integer := 100_000); 
    PORT(clk: IN  STD_LOGIC;
         rst: IN  STD_LOGIC;
         busy: OUT STD_LOGIC;                           -- Signals that a transaction is happening
         sl_nack: OUT STD_LOGIC;                        -- Signals slave not acknowleding transaction
         addr: IN STD_LOGIC_VECTOR(6 DOWNTO 0);         -- addr gets loaded here, addr & rw makes address byte         
         PnSr, S: IN STD_LOGIC;                         -- Stop/(not reapeat) and start signals for transitions
         w_amt, r_amt: IN STD_LOGIC_VECTOR(6 DOWNTO 0); -- Amount of bytes that are written/read in this transaction
         data_i: IN STD_LOGIC_VECTOR(7 DOWNTO 0);       -- data that is to be written
         data_o: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);      -- data that has been read 
         r_valid: OUT STD_LOGIC;                        -- Signals read data is valid now
         data_load, addr_cnt_load: OUT STD_LOGIC;       -- Signals when and which information has been loaded
         SDA: INOUT STD_LOGIC;                          -- open drain data line 
         SCL: OUT STD_LOGIC                             -- not open drain, no clock stretching supported yet
    );
  END ENTITY;

----------------------------------------------------------------------------
-- ARCHITECTURE DECLARATION.
----------------------------------------------------------------------------
ARCHITECTURE rtl OF i2c_master IS

  --------------------------------------------------------------------------
  -- TYPES, RECORDS, INTERNAL SIGNALS, FSM, CONSTANTS DECLARATION.
  --------------------------------------------------------------------------
  -- FSM and all its required signals
  TYPE FSM is (idle,
               start, stop, reap,
               address,
               read_ack, read_nack, write);
  SIGNAL state, next_state: FSM;
  SIGNAL r_cnt: INTEGER RANGE 0 to 127; -- counter to set how many bytes are to be read
  SIGNAL w_cnt: INTEGER RANGE 0 to 127; -- counter to set how many bytes are to be written
  SIGNAL RnW: STD_LOGIC;             -- addr & rw make the address byte
  SIGNAL load: STD_LOGIC;
  
  CONSTANT ACK:  STD_LOGIC := '0';
  CONSTANT NACK: STD_LOGIC := '1';

  CONSTANT M_START: STD_LOGIC_VECTOR(2 DOWNTO 0) := "000";
  CONSTANT M_STOP:  STD_LOGIC_VECTOR(2 DOWNTO 0)  := "001";
  CONSTANT M_WRITE: STD_LOGIC_VECTOR(2 DOWNTO 0) := "010";
  CONSTANT M_READ:  STD_LOGIC_VECTOR(2 DOWNTO 0)  := "011";
  CONSTANT M_REAP:  STD_LOGIC_VECTOR(2 DOWNTO 0)  := "100";

  SIGNAL clk_en: STD_LOGIC;
  CONSTANT PRESCALER: INTEGER := (SYSfreq + 5*SCLfreq - 1) / (5*SCLfreq); -- rounding up
  SIGNAL clk_cnt: INTEGER RANGE 0 to PRESCALER;
  SIGNAL sda_i: STD_LOGIC;
  SIGNAL sda_o: STD_LOGIC;

  -- Master <-> ByC Signals
  SIGNAL slave_ack, master_ack: STD_LOGIC;         
  SIGNAL cmd: STD_LOGIC_VECTOR(2 DOWNTO 0); -- ByC instruction
  SIGNAL wdata, rdata: STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL req: STD_LOGIC;

  -- ByC <-> BiC Signals
  SIGNAL BiC2ByC, ByC2BiC: STD_LOGIC;     -- BiC/ByC Communcation signals
  SIGNAL ByC_req: STD_LOGIC;
  SIGNAL ByC_cmd: STD_LOGIC_VECTOR(1 DOWNTO 0);
  SIGNAL BiC_done: STD_LOGIC;
  SIGNAL ByC_done: STD_LOGIC;
  --------------------------------------------------------------------------
  -- COMPONENTS DECLARATION
  --------------------------------------------------------------------------
  
  COMPONENT i2c_bitcontrol IS
    PORT(clk : IN  STD_LOGIC;
         rst : IN  STD_LOGIC;
         clk_en: IN STD_LOGIC;
         -- Signals for communication with byte controller
         request: IN STD_LOGIC;  -- ByC signals it has an instruction 
         byte_i: IN STD_LOGIC;   -- ByC shifts data during write and holds '1' during read
         byte_o: OUT STD_LOGIC;  -- BiC sends probed Bit during every data cycle
         byte_cmd: IN STD_LOGIC_VECTOR(1 DOWNTO 0); -- ByC Instruction for BiC
         bit_done: OUT STD_LOGIC; -- BiC signals it has finished the instruction
         -- I2C Bus
         sda_i : IN STD_LOGIC;
         sda_o : OUT STD_LOGIC; 
         scl : OUT STD_LOGIC);
  END COMPONENT;

  COMPONENT i2c_bytecontrol IS
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
  END COMPONENT; 
 


BEGIN  -- start of architecture --


  --------------------------------------------------------------------------
  -- COMPONENTS INSTANTIATION
  --------------------------------------------------------------------------
  BiC: i2c_bitcontrol
  PORT MAP(clk => clk, rst => rst, clk_en => clk_en, 
           request => ByC_req, byte_i => ByC2BiC, byte_o => BiC2ByC,
           byte_cmd => ByC_cmd, bit_done => BiC_done, 
           sda_i => sda_i, sda_o => sda_o, scl => SCL);

  ByC: i2c_bytecontrol
  PORT MAP(clk => clk, rst => rst, master_cmd => cmd, master_wdata => wdata,
           master_rdata => rdata, master_ack => master_ack, slave_ack => slave_ack,
           master_done => ByC_done, master_req => req, request => ByC_req,
           bit_i => BiC2ByC, bit_o => ByC2BiC, bit_cmd => ByC_cmd, 
           bit_done => BiC_done);
  --------------------------------------------------------------------------
  -- OUTPUTS ASSIGNMENT/COMBINATIONAL LOGIC
  --------------------------------------------------------------------------
  
  SDA <= '0' WHEN sda_o = '0' ELSE 'Z';
  sda_i <= to_X01(SDA); -- to_X01 for simulation
  
  RnW <= '0' WHEN r_cnt = 0 ELSE '1';
  data_o <= rdata;                                     -- rdata comes from a register, r_valid signals its good to read  


  --------------------------------------------------------------------------
  -- SEQUENTIAL LOGIC
  --------------------------------------------------------------------------
  
  -- clock divider to create the SCL clk_en
  clk_div: PROCESS(clk, rst)
  BEGIN
    IF rst = '1' THEN
      clk_cnt <= 0;
      clk_en <= '0';
    ELSIF clk = '1' AND clk'event THEN
      clk_en <= '0';
      clk_cnt <= clk_cnt + 1;
      IF (clk_cnt = PRESCALER - 1) THEN
        clk_en <= '1';
        clk_cnt <= 0;
      END IF;
    END IF;
  END PROCESS;

  -- decrementing counter to count how many bytes have been written
  write_cnt: PROCESS(clk, rst)
  BEGIN
    IF rst = '1' THEN
      w_cnt <= 0;
    ELSIF clk = '1' AND clk'event THEN
      IF (load = '1' AND state /=write) THEN
        w_cnt <= to_integer(unsigned(w_amt));
      ELSIF (state = write AND ByC_done = '1') THEN
        w_cnt <= w_cnt - 1; -- this cant underflow during a write 
      END IF;
    END IF;
  END PROCESS;

  -- decrementing counter to count how many byte have been read
  read_cnt: PROCESS(clk, rst)
  BEGIN
    IF rst = '1' THEN
      r_cnt <= 0;
    ELSIF clk = '1' AND clk'event THEN
      IF (load = '1' AND state /= read_ack AND state /= read_nack) THEN
        r_cnt <= to_integer(unsigned(r_amt));
      ELSIF ((state = read_ack OR state = read_nack) AND ByC_done = '1') THEN
        r_cnt <= r_cnt - 1;
      END IF;
    END IF;
  END PROCESS;

  -- register for write data
  write_reg: PROCESS(clk, rst)
  BEGIN
    IF rst = '1' THEN
      wdata <= (others => '0');
      data_load <= '0';
      addr_cnt_load <= '0';
      sl_nack <= '0';
    ELSIF clk = '1' AND clk'event THEN
      data_load <= '0';                        -- default assignments
      addr_cnt_load <= '0';         
      sl_nack <= '0';
      IF (ByC_done = '1') THEN
        CASE state IS
          WHEN start =>  wdata <= addr & RnW;
                         addr_cnt_load <= '1'; -- signals both address and counter have been loaded
          WHEN address =>IF (RnW = '0' AND slave_ack = ACK AND w_cnt > 0) THEN
                           wdata <= data_i;
                           data_load <= '1';
                         END IF;
                         IF (slave_ack = NACK) THEN sl_nack <= '1'; END IF;
          WHEN write =>  IF (w_cnt > 1 AND slave_ack = ACK) THEN
                           wdata <= data_i;
                           data_load <= '1';
                         END IF;
                         IF (slave_ack = NACK) THEN sl_nack <= '1'; END IF;
          WHEN reap =>   wdata <= addr & RnW;
                         addr_cnt_load <= '1';
          WHEN OTHERS => NULL;
        END CASE;
      END IF;
    END IF;
  END PROCESS;



  in_net: PROCESS(state, S, ByC_done, slave_ack, r_cnt, w_cnt, PnSr)
  BEGIN
    next_state <= state; -- default assignment
    load <= '0';
    busy <= '1';         -- busy in every state except idle
    CASE state IS
      WHEN idle =>   busy <= '0';
                     IF (S = '1') THEN 
                       next_state <= start; 
                     END IF;
      WHEN start =>  IF (ByC_done = '1') THEN 
                        next_state <= address; 
                     END IF;
                     load <= '1';                      -- loads counters over the entire duration of start, sends load confirmation on transition to address
      WHEN address=> IF (ByC_done = '1') THEN
                       IF (slave_ack = NACK) THEN
                         IF (PnSr = '1') THEN
                           next_state <= stop;
                         ELSE
                           next_state <= reap;
                         END IF;
                       ELSE 
                         IF (r_cnt = 0 AND w_cnt> 0) THEN next_state <= write;
                         ELSIF (r_cnt = 1) THEN next_state <= read_nack;
                         ELSIF (r_cnt > 1) THEN next_state <= read_ack;
                         ELSIF (r_cnt = 0 AND w_cnt = 0 AND PnSr = '1') THEN next_state <= stop;
                         ELSE next_state <= reap;
                         END IF;
                       END IF;
                     END IF;
      WHEN write => IF (ByC_done = '1') THEN
                      IF (slave_ack = NACK) THEN
                        IF (PnSr = '1') THEN
                          next_state <= stop;
                        ELSE
                          next_state <= reap;
                        END IF;
                     ELSE
                       IF (w_cnt = 1) THEN
                         IF (PnSr = '1') THEN
                           next_state <= stop;
                         ELSE
                           next_state <= reap;
                         END IF;
                       ELSE next_state <= write;
                       END IF;
                     END IF;
                   END IF;
      WHEN read_nack => IF (ByC_done = '1') THEN
                          IF (PnSr = '1') THEN 
                            next_state <= stop;
                          ELSE next_state <= reap;
                          END IF;
                        END IF;
      WHEN read_ack => IF (ByC_done = '1') THEN
                         IF (r_cnt > 2) THEN 
                           next_state <= read_ack;
                         ELSE next_state <= read_nack;
                         END IF;
                       END IF;
      WHEN stop => IF (ByC_done = '1') THEN next_state <= idle; END IF;
      WHEN reap => IF (ByC_done = '1') THEN 
                     next_state <= address;
                   END IF;
                   load <= '1'; -- loads counters over the entire duration of reap, sends load confirmation on transition to address
    END CASE;
  END PROCESS;

  mem: PROCESS(clk, rst)
  BEGIN
    IF rst = '1' THEN
      state <= idle;
    ELSIF clk = '1' AND clk'event THEN
      state <= next_state;
    END IF;
  END PROCESS;

  out_net: PROCESS(state, ByC_done)
  BEGIN
    r_valid <= '0';
    master_ack <= ACK;
    cmd <= "111";       -- unused state to prevent latch
    req <= '0';
    CASE state IS
      WHEN idle =>   NULL; 
      WHEN start =>  cmd <= M_START; req <= '1';
      WHEN address=> cmd <= M_WRITE; req <= '1';
      WHEN write =>  cmd <= M_WRITE; req <= '1';
      WHEN read_nack => cmd <= M_READ; req <= '1';
                        master_ack <= NACK;
                        IF (ByC_done = '1') THEN
                          r_valid <= '1';
                        END IF;
      WHEN read_ack =>  cmd <= M_READ; req <= '1';
                        master_ack <= ACK;
                        IF (ByC_done = '1') THEN
                          r_valid <= '1';
                        END IF;
      WHEN stop =>   cmd <= M_STOP; req <= '1';
      WHEN reap =>   cmd <= M_REAP; req <= '1';

    END CASE;
  END PROCESS;


END ARCHITECTURE;
