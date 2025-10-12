library ieee;
use ieee.std_logic_1164.all;

entity updown_counter_tb is
end entity updown_counter_tb;

architecture tb of updown_counter_tb is

    -- сигналы между тестером и DUT
    signal i_clk_tb    : std_logic;
    signal i_reset_tb  : std_logic;
    signal i_load_tb   : std_logic;
    signal i_enable_tb : std_logic;
    signal i_dir_tb    : std_logic;
    signal i_D_tb      : std_logic_vector(7 downto 0);
    signal o_Q_tb      : std_logic_vector(7 downto 0);

    component updown_counter
        port (
            i_clk    : in  std_logic;
            i_reset  : in  std_logic;
            i_load   : in  std_logic;
            i_enable : in  std_logic;
            i_dir    : in  std_logic;
            i_D      : in  std_logic_vector(7 downto 0);
            o_Q      : out std_logic_vector(7 downto 0)
        );
    end component;

    component updown_counter_tester
        port (
            i_clk    : out std_logic;
            i_reset  : out std_logic;
            i_load   : out std_logic;
            i_enable : out std_logic;
            i_dir    : out std_logic;
            i_D      : out std_logic_vector(7 downto 0);
            o_Q      : in  std_logic_vector(7 downto 0)
        );
    end component;

begin

    -- инстанцируем DUT
    dut: updown_counter
        port map (
            i_clk    => i_clk_tb,
            i_reset  => i_reset_tb,
            i_load   => i_load_tb,
            i_enable => i_enable_tb,
            i_dir    => i_dir_tb,
            i_D      => i_D_tb,
            o_Q      => o_Q_tb
        );

    stim: updown_counter_tester
        port map (
            i_clk    => i_clk_tb,
            i_reset  => i_reset_tb,
            i_load   => i_load_tb,
            i_enable => i_enable_tb,
            i_dir    => i_dir_tb,
            i_D      => i_D_tb,
            o_Q      => o_Q_tb
        );

end architecture tb;
