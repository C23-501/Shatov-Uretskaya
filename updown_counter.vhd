library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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
  signal cnt_Addr_r : unsigned(7 downto 0) := (others => '0');
begin

  process(i_clk, i_reset)
  begin
    if i_reset = '1' then
      cnt_Addr_r <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_load = '1' then
        cnt_Addr_r <= unsigned(i_D);
      elsif i_enable = '1' then
        if i_dir = '1' then
          cnt_Addr_r <= cnt_Addr_r + 1;
        else
          cnt_Addr_r <= cnt_Addr_r - 1;
        end if;
      end if;
    end if;
  end process;

  o_Q <= std_logic_vector(cnt_Addr_r);

end architecture behavioral;