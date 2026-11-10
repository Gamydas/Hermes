----------------------------------------------------------------------------
--  % NAME        : i2c_bitcontrol.vhd %
--  % PROJECT     : hermes %
--  % VERSION     : 1.0 %
--  % CREATED_BY  : Samy Gad %
--  % DATE_CREATED: 2026-10-29 %
--                                                                        --
--  DESCRIPTION:                                                          --
--  Bit Controller for an I2C Master
--                                                                        --
----------------------------------------------------------------------------
--  REVISION HISTORY                                                      --
--                                                                        --
--  VERSION    DATE        SIGN      CHANGE DESCRIPTION                   --
--  ------- ----------  ----------   ------------------                   --
--  1.0     2026-10-29  Gamy   Initial version.
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
  ENTITY i2c_bitcontrol IS
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
  END ENTITY;

----------------------------------------------------------------------------
-- ARCHITECTURE DECLARATION.
----------------------------------------------------------------------------
ARCHITECTURE rtl OF i2c_bitcontrol IS

  --------------------------------------------------------------------------
  -- TYPES, RECORDS, INTERNAL SIGNALS, FSM, CONSTANTS DECLARATION.
  --------------------------------------------------------------------------
    TYPE FSM IS (
        idle, 
        wait_cmd,
        start1, start2, 
        data1, data2, data3, data4, 
        reap1, reap2, 
        stop1, stop2);

  SIGNAL state, next_state: FSM;

  CONSTANT CMD_START: STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
  CONSTANT CMD_REAP: STD_LOGIC_VECTOR(1 DOWNTO 0) := "01";
  CONSTANT CMD_BIT: STD_LOGIC_VECTOR(1 DOWNTO 0) := "10";
  CONSTANT CMD_STOP: STD_LOGIC_VECTOR(1 DOWNTO 0) := "11";

  -- Signals that need registering
  SIGNAL sda_reg: STD_LOGIC; -- for reading sda

  -- This is needed to maintain timing requirements for start/stop/idle/reap
  CONSTANT HOLD_PHASES: NATURAL := 3;
  SIGNAL hold_cnt: NATURAL RANGE 0 TO HOLD_PHASES - 1; 
  
  SIGNAL discard: STD_LOGIC; -- signal to discard an invalid command

  --------------------------------------------------------------------------
  -- COMPONENTS DECLARATION
  --------------------------------------------------------------------------



BEGIN  -- start of architecture --

  --------------------------------------------------------------------------
  -- COMPONENTS INSTANTIATION
  --------------------------------------------------------------------------
  

  --------------------------------------------------------------------------
  -- COMBINATIONAL LOGIC
  --------------------------------------------------------------------------
  
  
  --------------------------------------------------------------------------
  -- SEQUENTIAL LOGIC
  --------------------------------------------------------------------------
  
  -- register to synchronize signals where glitches are critical
  sync_reg: PROCESS(clk, rst)
  BEGIN
    IF rst = '1' THEN
      sda_reg <= '1';
    ELSIF clk = '1' AND clk'event THEN
      sda_reg <= sda_i;
    END IF;
  END PROCESS;

  
  --------------------------------------------------------------------------
  -- FSM   
  --------------------------------------------------------------------------

  
    in_net : PROCESS (state, request, byte_cmd, clk_en, hold_cnt)
    BEGIN
      next_state <= state;
      discard <= '0';
      CASE state IS
        WHEN idle   => IF (request = '1' AND clk_en = '1' AND hold_cnt = 0) THEN
                          IF (byte_cmd = CMD_START) THEN
                            next_state <= start1;
                          ELSE discard <= '1';
                          END IF;
                       END IF;
        WHEN start1 => IF (hold_cnt = 0) THEN next_state <= start2; END IF;
        WHEN start2 => next_state <= wait_cmd;
        WHEN data1  => next_state <= data2;
        WHEN data2  => next_state <= data3;
        WHEN data3  => next_state <= data4;
        WHEN data4  => next_state <= wait_cmd; 
        WHEN reap1  => next_state <= reap2;
        WHEN reap2  => IF (hold_cnt = 0) THEN next_state <= start1; END IF;
        WHEN stop1  => next_state <= stop2;
        WHEN stop2  => IF (hold_cnt = 0) THEN next_state <= idle; END IF;
        WHEN wait_cmd => IF (request = '1' AND clk_en = '1') THEN
                           CASE byte_cmd IS
                             WHEN CMD_BIT => next_state <= data1;
                             WHEN CMD_STOP => next_state <= stop1;
                             WHEN CMD_REAP => next_state <= reap1;
                             WHEN OTHERS => discard <= '1';
                            END CASE;
                         END IF;
      END CASE;
    END PROCESS in_net;
 

    mem : PROCESS (clk, rst)
    BEGIN
      IF rst = '1' THEN
        state <= idle;
        hold_cnt <= HOLD_PHASES - 1;
      ELSIF clk = '1' and clk'event THEN
        IF clk_en = '1' THEN
          state <= next_state;
          -- reload on entry so the count applies to the state being entered
          IF next_state /= state THEN
            hold_cnt <= HOLD_PHASES - 1;
          ELSIF hold_cnt /= 0 THEN
            hold_cnt <= hold_cnt - 1;
          END IF;
        END IF;
      END IF;
    END PROCESS mem;
 

    -- synchronized to avoid sda/scl glitches
    out_net : PROCESS (clk, rst)
    BEGIN
      IF rst = '1' THEN
          scl <= '1';
          sda_o <= '1';
          bit_done <= '0';
          byte_o <= '0';
      ELSIF clk = '1' and clk'event THEN
          bit_done <= '0';
          CASE state IS
            WHEN idle   => sda_o <= '1'; scl <= '1'; IF (discard = '1') THEN bit_done <= '1'; END IF;
            WHEN start1 => sda_o <= '0';
            WHEN start2 => scl <= '0'; IF (clk_en = '1') THEN bit_done <= '1'; END IF;
            WHEN data1  => sda_o <= byte_i; -- writing to sd:a
            WHEN data2  => scl <= '1';
            WHEN data3  => byte_o <= sda_reg; -- probing sda
            WHEN data4  => scl <= '0'; IF (clk_en = '1') THEN bit_done <= '1'; END IF;
            WHEN reap1  => sda_o <= '1';
            WHEN reap2  => scl <= '1';
            WHEN stop1  => sda_o <= '0';
            WHEN stop2  => scl <= '1'; IF (clk_en = '1' AND hold_cnt = 0) THEN bit_done <= '1'; END IF;
            WHEN wait_cmd => scl <= '0'; sda_o <= '0'; IF (discard = '1') THEN bit_done <= '1'; END IF;
          END CASE;
      END IF;
    END PROCESS out_net;

    
  --------------------------------------------------------------------------
  -- OUTPUTS ASSIGNMENT
  --------------------------------------------------------------------------
  


END ARCHITECTURE;
