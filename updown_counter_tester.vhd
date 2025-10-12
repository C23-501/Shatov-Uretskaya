library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity updown_counter_tester is
    port (
        i_clk    : out std_logic;                       
        i_reset  : out std_logic;                      
        i_load   : out std_logic;
        i_enable : out std_logic;
        i_dir    : out std_logic;                      
        i_D      : out std_logic_vector(7 downto 0);
        o_Q      : in  std_logic_vector(7 downto 0)
    );
end entity updown_counter_tester;

architecture tester of updown_counter_tester is
    signal clk : std_logic := '0';
    constant CLK_PERIOD : time := 10 ns;
begin

    clk_gen : process
    begin
        loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
    end process clk_gen;

    i_clk <= clk;

    stimulus : process
    begin
        i_reset  <= '1';
        i_load   <= '0';
        i_enable <= '0';
        i_dir    <= '1';
        i_D      <= (others => '0');
        wait for 5 ns;

        -- 1) Асинхронный сброс
        i_reset <= '0';
        wait for 25 ns;
        i_reset <= '1';
        for idx in 1 to 3 loop
            wait until rising_edge(clk);
        end loop;

        -- 2) Load x"10"
        i_D <= x"10";
        i_load <= '1';
        wait until rising_edge(clk);
        i_load <= '0';
        wait for CLK_PERIOD;

        -- 3) Включаем счёт вверх
        i_enable <= '1';
        i_dir <= '1';
        for idx in 1 to 6 loop
            wait until rising_edge(clk);
        end loop;

        -- 4) Проверка приоритетности LOAD над ENABLE
        i_D <= x"FF";
        i_load <= '1';
        wait until rising_edge(clk);
        i_load <= '0';
        for idx in 1 to 2 loop
            wait until rising_edge(clk);
        end loop;

        -- 5) Переполнение вверх, загружаем 0xFE и считаем вверх
        i_D <= x"FE";
        i_load <= '1';
        wait until rising_edge(clk);
        i_load <= '0';
        for idx in 1 to 4 loop
            wait until rising_edge(clk);
        end loop;

        -- 6) Счёт вниз и underflow: загрузим 0x00 и считаем вниз
        i_dir <= '0';
        i_D <= x"00";
        i_load <= '1';
        wait until rising_edge(clk);
        i_load <= '0';
        for idx in 1 to 3 loop
            wait until rising_edge(clk);
        end loop;

        -- 7) Отключаем enable: Q должен удерживаться
        i_enable <= '0';
        i_dir <= '1';
        for idx in 1 to 4 loop
            wait until rising_edge(clk);
        end loop;

        -- 8) LOAD при enable='0' — загрузка всё ещё должна работать
        i_D <= x"55";
        i_load <= '1';
        wait until rising_edge(clk);
        i_load <= '0';
        wait for CLK_PERIOD;

        -- 9) Асинхронный reset во время работы счётчика
        i_enable <= '1';
        i_dir <= '1';
        for idx in 1 to 3 loop
            wait until rising_edge(clk);
        end loop;
        i_reset <= '0';
        wait for 12 ns;
        i_reset <= '1';
        for idx in 1 to 2 loop
            wait until rising_edge(clk);
        end loop;

        -- Завершение: финальный reset и стоп
        i_reset <= '0';
        wait for 20 ns;
        i_reset <= '1';
        wait for 5 * CLK_PERIOD;

        -- idle state
        i_enable <= '0';
        i_load <= '0';
        i_dir <= '1';
        i_D <= (others => '0');

        wait;
    end process stimulus;

end architecture tester;
