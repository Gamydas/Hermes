LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY debounce IS
GENERIC (freq : INTEGER := 50_000_000; -- Frequenz in Hz
			stable : INTEGER := 10);      -- Stabile Zeitspanne in ms
PORT (clk, reset : IN std_logic;
		x : IN std_logic;
		y : OUT std_logic);
END ENTITY;

ARCHITECTURE rtl OF debounce IS
SIGNAL cnt : integer RANGE 0 to freq*stable/1000;
SIGNAL shreg : std_logic_vector (3 DOWNTO 0);
SIGNAL status : std_logic;

BEGIN
PROCESS (clk, reset)
BEGIN
	IF (reset = '1') THEN
		y <= '0';
		shreg(3 DOWNTO 0) <= "0000";
	ELSIF (clk'event and clk = '1') then
		
		shreg <= shreg (2 downto 0) & x;
		IF (status = '1') THEN
			cnt <= 0;
		ELSIF (cnt < freq*stable/1000 - 4) THEN
			cnt <= cnt + 1;
		ELSE 
			y <= shreg(3);
		END IF;

	END IF;
END PROCESS;
status <= not ((shreg(0) XNOR shreg(1)) AND (shreg(1) XNOR shreg(2)) AND (shreg(2) XNOR shreg(3)));
END rtl;
			
