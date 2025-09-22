library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity updown_counter is
  port (
    i_clk    : in  std_logic;
    i_reset  : in  std_logic;
    i_load   : in  std_logic;
    i_enable : in  std_logic;
    i_dir    : in  std_logic;
    i_D      : in  std_logic_vector(7 downto 0);
    o_Q      : out std_logic_vector(7 downto 0)
  );
end entity updown_counter;

architecture behavioral of updown_counter is
  signal data_counter_count : std_logic_vector(7 downto 0) := (others => '0');
begin

  process(i_clk, i_reset)
  begin
    if i_reset = '0' then
      data_counter_count <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_load = '1' then
        data_counter_count <= i_D;
      elsif i_enable = '1' then
        if i_dir = '1' then
          data_counter_count <= data_counter_count + 1;
        else
          data_counter_count <= data_counter_count - 1;
        end if;
      end if;
    end if;
  end process;

  o_Q <= data_counter_count;

end architecture behavioral;
