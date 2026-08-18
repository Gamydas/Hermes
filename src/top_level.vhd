----------------------------------------------------------------------------
--  % NAME        : top_level.vhd %
--  % PROJECT     : project %
--  % VERSION     : 1.0 %
--  % CREATED_BY  : Samy Gad %
--  % DATE_CREATED: 2026-08-16 %
--                                                                        --
--  DESCRIPTION:                                                          --
--  - description
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
  ENTITY top_level IS
    PORT(clk,rst, data_rdy : IN  STD_LOGIC;
         data_in  : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
         data_out : OUT std_logic
    );
  END ENTITY top_level;

----------------------------------------------------------------------------
-- ARCHITECTURE DECLARATION.
----------------------------------------------------------------------------
ARCHITECTURE rtl OF top_level IS

  --------------------------------------------------------------------------
  -- TYPES, RECORDS, INTERNAL SIGNALS, FSM, CONSTANTS DECLARATION.
  --------------------------------------------------------------------------
  
  COMPONENT TX IS
    GENERIC(freq: positive := 50_000_000;
            baud: positive := 115200);
    PORT(clk,rst, data_rdy : IN  STD_LOGIC;
         data_in : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
         data_out, status : OUT std_logic
    );
  END COMPONENT; 

  COMPONENT pulse is
  port (x, clk, rst: IN std_logic;
        y : OUT std_logic
        );
  end COMPONENT; 

  COMPONENT debounce IS
  GENERIC (freq : INTEGER := 50_000_000; -- Frequency in Hz
		  	stable : INTEGER := 10);         -- Stable time in ms
  PORT (clk, reset : IN std_logic;
		  x : IN std_logic;
		  y : OUT std_logic);
  END COMPONENT;

  SIGNAL rdy_deb : std_logic;
  SIGNAL rdy_key : std_logic;
BEGIN  -- start of architecture --


  debrdy: debounce
  GENERIC MAP(freq => 50_000_000, stable => 10)
  PORT MAP(clk => clk, reset => not rst, x => not data_rdy, y => rdy_deb);
  
  pul: pulse
  PORT MAP(clk => clk, rst => not rst, x => rdy_deb, y => rdy_key);

  DUT: TX 
  GENERIC MAP(freq => 50_000_000, baud => 115200)
  PORT MAP(clk => clk, rst => not rst, data_rdy => rdy_key, data_in => data_in, data_out => data_out);



END ARCHITECTURE rtl;
