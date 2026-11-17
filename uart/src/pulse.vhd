library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity pulse is
  port (x, clk, rst: IN std_logic;
        y : OUT std_logic
        );
end entity;


architecture fsm of pulse is
  type states is (a,b);
  signal state, next_state: states;
begin
  in_net: process(x, state)
  begin
    case state is
      when a => if (x = '1') then next_state <= b;
                else next_state <= a; 
                end if;
      when b => if (x = '0') then next_state <= a;
                else next_state <= b;
                end if; 
      when others => next_state <= a;
    end case;
  end process;
  
  mem: process(clk, rst)
    begin
      if rst = '1' then
        state <= a;
      elsif clk = '1' and clk'event then
        state <= next_state;
      end if;
    end process;
  
  out_net: process(x, state)
  begin
    case state is
      when a => if (x = '1') then y <= '1'; 
                else y <= '0'; 
                end if;
      when b => y <= '0';
      when others => y <= '0';
    end case;
  end process;
end architecture;