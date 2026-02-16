library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;
use work.TOP_SDRAM_package.all;

entity SDRAM_Traffic_Gen is
    port (
        -- Этот модуль должен работать на частоте Avalon (80 МГц)
        clk             : in  std_logic;
        reset_n         : in  std_logic;

        -- Avalon-MM Master интерфейс
        avs_waitrequest : in  std_logic;
        avs_readdata    : in  std_logic_vector(63 downto 0);
        avs_readdatavalid : in std_logic;

        avs_address     : out std_logic_vector(24 downto 0);
        avs_write       : out std_logic;
        avs_read        : out std_logic;
        avs_writedata   : out std_logic_vector(63 downto 0);
        avs_byteenable  : out std_logic_vector(7 downto 0);
        avs_burstcount  : out std_logic_vector(4 downto 0);

        -- Статусные выходы, подключить к LED
        test_pass       : out std_logic; -- Загорится, если тест прошел
        test_fail       : out std_logic  -- Загорится, если данные не совпали
    );
end entity SDRAM_Traffic_Gen;

architecture rtl of SDRAM_Traffic_Gen is

    -- Параметры теста
    constant TEST_LIMIT : integer := 256; -- Сколько слов записать/прочитать
    
    -- Счётчики
    signal write_counter : std_logic_vector(11 downto 0) := (others => '0');
    signal read_counter  : std_logic_vector(11 downto 0) := (others => '0');
    signal check_counter : std_logic_vector(11 downto 0) := (others => '0');

    -- Машина состояний
    type state_t is (IDLE, WRITING, READING, DONE, FAILED);
    signal state : state_t := IDLE;

begin
	 
    -- Фиксированные сигналы для упрощения
    avs_byteenable <= (others => '1');       -- Всегда используем все байты
	 avs_burstcount <= "00001"; -- Burst = 1 (одиночные)
	 
	 	 

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= IDLE;
            write_counter <= (others => '0');
            read_counter <= (others => '0');
            check_counter <= (others => '0');
            avs_write <= '0';
            avs_read <= '0';
            test_pass <= '0';
            test_fail <= '0';
            avs_address <= (others => '0');
            avs_writedata <= (others => '0');

        elsif rising_edge(clk) then
            
            -- Дефолтные значения
            avs_write <= '0';
            avs_read  <= '0';

            case state is
                when IDLE =>
                    -- Ждем пару тактов и начинаем
                    state <= WRITING;
                -- Меняем write_master в зависимости от write_counter
                when WRITING =>
                    if write_counter < TEST_LIMIT then
                        avs_write <= '1'; -- Активируем запись
                        
                        avs_address <= "0000000000" & write_counter & "000";
                        
                        -- 52 нуля + 12 бит счетчика
                        avs_writedata <= x"0000000000000" & write_counter;

                        -- Если Slave принял команду (waitrequest = 0), увеличиваем счетчик
                        if avs_waitrequest = '0' then
                            write_counter <= write_counter + 1;
                        end if;
                    else
                        -- Когда записали всё, переходим к чтению
								avs_write <= '0'; 
                        state <= READING;
                    end if;

                -- Меняем read_master в зависимости от read_counter
                when READING =>
                    if read_counter < TEST_LIMIT then
                        avs_read <= '1'; -- Активируем чтение
                        
                        -- Адрес вычисляется так же
                        avs_address <= "0000000000" & read_counter & "000";

                        -- Если Slave принял команду, увеличиваем счетчик запросов
                        if avs_waitrequest = '0' then
                            read_counter <= read_counter + 1;
                        end if;
                    else
                        -- Все запросы отправлены, ждем пока все данные вернутся (в check logic)
                        if check_counter = TEST_LIMIT then
                            state <= DONE;
                        end if;
                    end if;
                when DONE =>
                    test_pass <= '1'; -- Тест успешен

                when FAILED =>
                    test_fail <= '1'; -- Ошибка данных
					avs_read <= '0';
            end case;

            -- ПРОВЕРКА ДАННЫХ
            if avs_readdatavalid = '1' then
                -- Сравниваем то, что прочитали, с ожидаемым значением (check_counter)
                if CONV_INTEGER(avs_readdata) /= check_counter then
                    state <= FAILED;
                else
                    check_counter <= check_counter + 1;
                end if;
            end if;

        end if;
    end process;

end architecture rtl;