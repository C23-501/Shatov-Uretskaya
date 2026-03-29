library ieee;
use ieee.std_logic_1164.all;

entity Top_Top is
    port (
        -- Входные сигналы платы
        CLK_12MHZ   : in std_logic;
        RESET_N_KEY : in std_logic;

        -- Физические сигналы SDRAM 
        DRAM_ADDR   : out   std_logic_vector(11 downto 0);
        DRAM_BA     : out   std_logic_vector(1 downto 0);
        DRAM_CAS_N  : out   std_logic;
        DRAM_CKE    : out   std_logic;
        DRAM_CLK    : out   std_logic;
        DRAM_CS_N   : out   std_logic;
        DRAM_DQ     : out std_logic_vector(15 downto 0); --? inout
        DRAM_DQM    : out   std_logic_vector(1 downto 0);
        DRAM_RAS_N  : out   std_logic;
        DRAM_WE_N   : out   std_logic;

        -- Светодиоды для статуса
        LED_PASS    : out std_logic;
        LED_FAIL    : out std_logic;

        DEBUG_PINS  : out std_logic_vector(5 downto 0) --?
    );
end entity Top_Top;

architecture struct of Top_Top is

    -- Внутренние сигналы для соединения модулей
    signal w_addr       : std_logic_vector(24 downto 0);
    signal w_read       : std_logic;
    signal w_write      : std_logic;
    signal w_writedata  : std_logic_vector(63 downto 0);
    signal w_byteenable : std_logic_vector(7 downto 0);
    signal w_burstcount : std_logic_vector(4 downto 0);
    signal w_readdata   : std_logic_vector(63 downto 0);
    signal w_waitrequest: std_logic;
    signal w_valid      : std_logic;
    
    signal w_clk_80     : std_logic;
    signal w_clk_160    : std_logic;
    signal w_pll_locked : std_logic;
	signal timer_counter : integer range 0 to 3000 := 0; -- Счетчик до 2520
    signal timer_done    : std_logic := '0';             -- Сигнал что 210 мкс прошло
    signal w_global_reset_n : std_logic;	 

begin


    -- 2. Подключение модуля со счётчиками (Генератор)
    u_traffic_gen : entity work.SDRAM_Traffic_Gen
    port map (
        -- ВАЖНО: Генератор работает на частоте Avalon (80 МГц), а не 12 МГц
        clk             => w_clk_80, 
        reset_n         => w_pll_locked, -- Работаем только когда PLL стабильна

        -- Подключаем к сигналам Avalon
        avs_waitrequest => w_waitrequest,
        avs_readdata    => w_readdata,
        avs_readdatavalid => w_valid,

        avs_address     => w_addr,
        avs_write       => w_write,
        avs_read        => w_read,
        avs_writedata   => w_writedata,
        avs_byteenable  => w_byteenable,
        avs_burstcount  => w_burstcount,

        -- Статусные LED
        test_pass       => LED_PASS,
        test_fail       => LED_FAIL
    );

    DRAM_CLK <= w_clk_160;
	 
    DEBUG_PINS(0) <= w_write;       -- Активность мастера (Запись)
    DEBUG_PINS(1) <= w_read;        -- Активность мастера (Чтение)
    DEBUG_PINS(2) <= w_valid;       -- Валидные данные (чтение прошло)
    DEBUG_PINS(3) <= w_waitrequest; -- Waitrequest от слейва
    DEBUG_PINS(4) <= w_clk_80;      -- Тактовый сигнал 80 МГц
    DEBUG_PINS(5) <= w_clk_160;     -- Тактовый сигнал 160 МГц

end architecture struct;