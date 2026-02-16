library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.TOP_SDRAM_package.all;

entity tb_Top_Top is
    -- Testbench не имеет портов
end entity tb_Top_Top;

architecture behavior of tb_Top_Top is

    -- 1. Объявление компонента тестируемого устройства (DUT)
    component Top_Top is
        port (
            CLK_12MHZ   : in std_logic;
            RESET_N_KEY : in std_logic;

            DRAM_ADDR   : out   std_logic_vector(11 downto 0);
            DRAM_BA     : out   std_logic_vector(1 downto 0);
            DRAM_CAS_N  : out   std_logic;
            DRAM_CKE    : out   std_logic;
            DRAM_CLK    : out   std_logic;
            DRAM_CS_N   : out   std_logic;
            -- ВАЖНО: Исправлено на inout, так как это двунаправленная шина данных
            DRAM_DQ     : inout std_logic_vector(15 downto 0); 
            DRAM_DQM    : out   std_logic_vector(1 downto 0);
            DRAM_RAS_N  : out   std_logic;
            DRAM_WE_N   : out   std_logic;

            LED_PASS    : out std_logic;
            LED_FAIL    : out std_logic;
            DEBUG_PINS  : out std_logic_vector(5 downto 0)
        );
    end component;

    -- 2. Сигналы для подключения к DUT
    signal clk_12mhz   : std_logic := '0';
    signal reset_n_key : std_logic := '0';

    -- SDRAM сигналы
    signal dram_addr   : std_logic_vector(11 downto 0);
    signal dram_ba     : std_logic_vector(1 downto 0);
    signal dram_cas_n  : std_logic;
    signal dram_cke    : std_logic;
    signal dram_clk    : std_logic;
    signal dram_cs_n   : std_logic;
    signal dram_dq     : std_logic_vector(15 downto 0);
    signal dram_dqm    : std_logic_vector(1 downto 0);
    signal dram_ras_n  : std_logic;
    signal dram_we_n   : std_logic;

    -- Статусные сигналы
    signal led_pass    : std_logic;
    signal led_fail    : std_logic;
    signal debug_pins  : std_logic_vector(5 downto 0);

    -- Параметры симуляции
    constant CLK_PERIOD : time := 83.333 ns; -- 12 MHz (1/12us)

begin

    -- 3. Инстанцирование (подключение) Top_Top
    uut: Top_Top
    port map (
        CLK_12MHZ   => clk_12mhz,
        RESET_N_KEY => reset_n_key,
        
        DRAM_ADDR   => dram_addr,
        DRAM_BA     => dram_ba,
        DRAM_CAS_N  => dram_cas_n,
        DRAM_CKE    => dram_cke,
        DRAM_CLK    => dram_clk,
        DRAM_CS_N   => dram_cs_n,
        DRAM_DQ     => dram_dq,
        DRAM_DQM    => dram_dqm,
        DRAM_RAS_N  => dram_ras_n,
        DRAM_WE_N   => dram_we_n,
        
        LED_PASS    => led_pass,
        LED_FAIL    => led_fail,
        DEBUG_PINS  => debug_pins
    );

    -- 4. Генератор тактового сигнала (12 MHz)
    clk_process : process
    begin
        clk_12mhz <= '0';
        wait for CLK_PERIOD / 2;
        clk_12mhz <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- 5. Процесс сброса (Reset)
    stim_proc: process
    begin
        -- Удерживаем Reset в активном состоянии (0) в начале
        reset_n_key <= '0';
        wait for 200 ns;
        
        -- Отпускаем Reset
        reset_n_key <= '1';
        
        -- Здесь симуляция будет идти, пока PLL не залочится и трафик-генератор не отработает.
        -- Это может занять много времени (зависит от настроек PLL и контроллера).
        
        wait; -- Ждем бесконечно
    end process;

    -- 6. Мониторинг результатов (опционально)
    monitor_proc: process
    begin
	 
        wait until rising_edge(led_pass) or rising_edge(led_fail);
        
        if led_pass = '1' then
            report "=== TEST PASSED: Traffic Generator finished successfully ===" severity note;
        elsif led_fail = '1' then
            report "=== TEST FAILED: Data mismatch detected ===" severity error;
        end if;
        
        wait; -- Останавливаем монитор после первого результата
    end process;

end architecture behavior;