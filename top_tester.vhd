library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.TOP_SDRAM_package.all;  -- Подключаем пакет с процедурами

entity top_tester is
end entity top_tester;

architecture behavior of top_tester is

  -- Сигналы для тестирования
  signal clk_12MHz        : std_logic := '0';
  signal reset_n          : std_logic := '0';
  signal address_master   : std_logic_vector(24 downto 0) := (others => '0');
  signal read_master      : std_logic := '0';
  signal write_master     : std_logic := '0';
  signal write_data_master : std_logic_vector(63 downto 0) := (others => '0');
  signal byte_enable_master : std_logic_vector(7 downto 0) := (others => '0');
  signal burstcount_master  : std_logic_vector(4 downto 0) := (others => '0');
  signal burstenable_master : std_logic := '0';
  signal read_data_avs    : std_logic_vector(63 downto 0);
  signal waitrequest_avs  : std_logic := '0';
  signal read_data_valid  : std_logic := '0';
  signal A                : std_logic_vector(11 downto 0);
  signal BS               : std_logic_vector(1 downto 0);
  signal nCS              : std_logic;
  signal nRAS             : std_logic;
  signal nCAS             : std_logic;
  signal nWE              : std_logic;
  signal CKE              : std_logic;
  signal DQM              : std_logic_vector(1 downto 0);
  signal DQ               : std_logic_vector(15 downto 0);

  -- Тестируемые процедуры
  procedure emulate_waitrequest_read_write(
    signal avs : inout avlmm_a24b_d64_t;
    constant clk_ticks : integer
  ) is
  begin
    -- Имитация задержки с использованием waitrequest
    if avs.waitrequest_avs = '1' then
      wait until avs.waitrequest_avs = '0';
    end if;
  end procedure;

  -- Генератор тактового сигнала
  constant CLK_PERIOD : time := 83.333 ns; -- для 12 MHz

begin
  -- Процесс генерации тактов
  clk_process : process
  begin
    clk_12MHz <= '0';
    wait for CLK_PERIOD / 2;
    clk_12MHz <= '1';
    wait for CLK_PERIOD / 2;
  end process;

  -- Процесс тестирования
  test_process : process
  begin
    -- Тест 1: Одиночная передача данных (write_master = '1' и burstcount_master = 0)
    write_master <= '1';
    write_data_master <= x"123456789ABCDEF0";  -- Пример данных
    burstcount_master <= "00000";  -- Одиночная передача
    process_single_data_transfer(avs);  -- Вызов процедуры для одиночной передачи
    wait_clock(2);  -- Ожидаем 2 такта (с использованием процедуры из пакета)

    -- Тест 2: Бурстовая передача данных (write_master = '1' и burstcount_master > 0)
    write_master <= '1';
    write_data_master <= x"123456789ABCDEF0";
    burstcount_master <= "00001";  -- Бурст из 2 элементов
    process_burst_data_transfer(avs, 5);  -- Вызов процедуры для бурстовой передачи
    wait_clock(10);  -- Ожидаем 10 тактов

    -- Тест 3: Эмуляция задержки через `waitrequest` для записи и чтения
    write_master <= '1';
    read_master <= '1';
    write_data_master <= x"0000000000000000";  -- Пример записи
    address_master <= "000000000000001";  -- Пример адреса
    waitrequest_avs <= '1';  -- Активируем `waitrequest` для имитации задержки
    emulate_waitrequest_read_write(avs, 10);  -- Вызов процедуры для эмуляции `waitrequest`
    wait_clock(15);  -- Ожидаем 15 тактов

    -- Тест 4: Декуплированный `waitrequest` для чтения/записи
    waitrequest_avs <= '0';  -- Деактивируем `waitrequest`
    emulate_decoupled_waitrequest(avs, 10);  -- Вызов процедуры для декуплированного `waitrequest`
    wait_clock(15);  -- Ожидаем 15 тактов
    -- Завершаем тест
    wait;
  end process;

end behavior;
