library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
USE TOP_SDRAM_package.ALL;

entity TOP_SDRAM is
  generic (
  --?
  );
  port (
    -- Внешний тактовый вход
    clk_12MHz        : in  std_logic;

    -- Асинхронный внешний сброс
    reset_n          : in  std_logic;

    -- Avalon-MM 
	 
    address_master : in std_logic_vector(24 downto 0);
    read_master : in std_logic;
    write_master : in std_logic;
    write_data_master : in std_logic_vector(63 downto 0);
    byte_enable_master: in std_logic_vector(7 downto 0);
    burstcount_master : in std_logic_vector(4 downto 0);
    burstenable_master : in std_logic;

	 read_data_avs : out std_logic_vector(63 downto 0);
    waitrequest_avs : out std_logic;
	 read_data_valid : out std_logic;
    -- SDRAM
    A           : out std_logic_vector(11 downto 0);
    BS          : out std_logic_vector(1 downto 0);
    nCS         : out std_logic;
    nRAS        : out std_logic;
    nCAS        : out std_logic;
    nWE         : out std_logic;
    CKE         : out std_logic;
    DQM         : out std_logic_vector(1 downto 0);
	 DQ    : out std_logic_vector(15 downto 0);

  
  );
end entity TOP_SDRAM;


architecture rtl of TOP_SDRAM is

  -- === PLL / clocks / reset synchronization
  signal pll_clk_80MHz    : std_logic := '0'; -- 80 MHz -> Avalon
  signal pll_clk_160MHz    : std_logic := '0'; -- 160 MHz -> SDRAM
  signal pll_locked  : std_logic := '0';

  -- clocks
  signal clk_avalon  : std_logic;
  signal clk_sdram   : std_logic;

  -- global reset зависит от reset_n и pll_locked
  signal global_reset_n : std_logic;

  -- reset synchronizers 
  signal reset_avalon_ff : std_logic_vector(1 downto 0) := (others => '1');
  signal reset_sdram_ff  : std_logic_vector(1 downto 0) := (others => '1');
  signal reset_avalon_n  : std_logic := '0';
  signal reset_sdram_n   : std_logic := '0';
  
   -- Сигналы от FSM контроллера к подсистеме
  signal StateSubsys   : StateSubsys_type;
  signal StateFSM      : StateFSM_type;
  signal A_FSM         : std_logic_vector(11 DOWNTO 0);	
  
  -- Сигналы от подсистемы к арбитру
  signal nCS_Subsys  :     std_logic;
  signal nRAS_Subsys :     std_logic;
  signal nCAS_Subsys :     std_logic;
  signal nWE_Subsys  :     std_logic;
  signal CKE_Subsys  :     std_logic;
  signal DQM_Subsys  :     std_logic_vector(1 DOWNTO 0);
  signal BS_Subsys   :     std_logic_vector (1 DOWNTO 0);
  signal A_Subsys    :     std_logic_vector (11 DOWNTO 0);
  
    -- Сигналы от FSM контроллера к арбитру (прямые)
	signal StateFSM    : StateFSM_type;
	signal nCS_FSM     : std_logic;
	signal nRAS_FSM    : std_logic;
	signal nCAS_FSM    : std_logic;
	signal nWE_FSM     : std_logic;
	signal CKE_FSM     : std_logic;
	signal DQM_FSM     : std_logic_vector (1 DOWNTO 0);
	signal BS_FSM      : std_logic_vector (1 DOWNTO 0);
--A_FSM  
  --FIFO
	signal data_i     : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal wr_clk     : std_logic;
	signal wr_empty   : std_logic;
	signal wr_full    : std_logic;
	signal wr_used    : std_logic_vector(Log2(FIFO_DEPTH)-1 downto 0);
	signal wr_reset   : std_logic;
	signal wr_en      : std_logic;
	signal data_o     : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal rd_clk     : std_logic;
	signal rd_empty   : std_logic;
	signal rd_full    : std_logic;
	signal rd_used    : std_logic_vector(Log2(FIFO_DEPTH)-1 downto 0);
	signal rd_reset   : std_logic;
	signal rd_en      : std_logic;

 -- Сигналы для управления состоянием

  -- компоненты

  component avalon_slave
    port (
    clk_80MHz : in std_logic;
    nRST : in std_logic;
   
    -- Avalon-MM интерфейс от мастера
    address_master : in std_logic_vector(24 downto 0);
    read_master : in std_logic;
    write_master : in std_logic;
    write_data_master : in std_logic_vector(63 downto 0);
    byte_enable_master: in std_logic_vector(7 downto 0);
    burstcount_master : in std_logic_vector(4 downto 0);
    burstenable_master : in std_logic;

    -- Avalon-MM интерфейс к мастеру
    read_data_avs : out std_logic_vector(63 downto 0);
    waitrequest_avs : out std_logic;
   
    -- Интерфейсы к FIFO (логика управления FIFO)
    -- Командная FIFO записи
    wr_cmd_full : in std_logic;
    wr_cmd : out std_logic_vector(65 downto 0);
    wr_cmd_write : out std_logic;
   
    -- Данные FIFO записи
    wr_data_full : in std_logic;
    wr_data : out std_logic_vector(63 downto 0);
    wr_data_write : out std_logic;
	 wr_data_used : in std_logic_vector(9 downto 0);
   
    -- Командная FIFO чтения
    rd_cmd_empty : in std_logic;
    rd_cmd : in std_logic_vector(33 downto 0);
    rd_cmd_read : out std_logic;
   
    -- Данные FIFO чтения
    rd_data_empty : in std_logic;
    rd_data : in std_logic_vector(63 downto 0);
    rd_data_read : out std_logic
	 );
  end component;

-- компонент FIFO
	component FIFO is
    generic (
        DATA_WIDTH : integer := DATA_WIDTH;
        FIFO_DEPTH : integer := FIFO_DEPTH
    );
    port(
        data_i: in std_logic_vector(DATA_WIDTH - 1 downto 0);
        wr_clk: in std_logic;
        wr_empty: out std_logic;
        wr_full: out std_logic;
        wr_used: out std_logic_vector(integer(ceil(log2(real(FIFO_DEPTH)))) downto 0);
        wr_reset: in std_logic;
        wr_en: in std_logic;
        data_o: out std_logic_vector(DATA_WIDTH - 1 downto 0);
        rd_clk: in std_logic;
        rd_empty: out std_logic;
        rd_full: out std_logic;
        rd_used: out std_logic_vector(integer(ceil(log2(real(FIFO_DEPTH)))) downto 0);
        rd_reset: in std_logic;
        rd_en: in std_logic
    );
end component;

-- Компонент подсистемы SDRAM
component SDRAM_Subsystem is
   GENERIC(
		Burst_length : integer := Burst_length;
      CAS_Latency  : integer := CAS_Latency;
      CLK_Freq_MHz : integer := CLK_Freq_MHz
   );
   PORT( 
      -- Общие
      nRst      : IN     std_logic;
      CLK       : IN     std_logic;
      -- Входы с FSM
      StateFSM  : IN     StateFSM_type;
      A_FSM     : IN     std_logic_vector (11 DOWNTO 0);
      -- Выходы на арбитр
      nCS       : OUT    std_logic;
      nRAS      : OUT    std_logic;
      nCAS      : OUT    std_logic;
      nWE       : OUT    std_logic;
      CKE       : OUT    std_logic;
      DQM       : OUT    std_logic_vector (1 DOWNTO 0);
      BS        : OUT    std_logic_vector (1 DOWNTO 0);
      A         : OUT    std_logic_vector (11 DOWNTO 0);
      State_out : OUT    StateSubsys_type
   );

end component;

-- Компонент арбитра SDRAM
component SDRAM_Arbiter is
   PORT( 
      -- Общие
      nRst        : IN     std_logic;
      CLK         : IN     std_logic;
      -- От FSM
      StateFSM    : IN     StateFSM_type;
      nCS_FSM     : IN     std_logic;
      nRAS_FSM    : IN     std_logic;
      nCAS_FSM    : IN     std_logic;
      nWE_FSM     : IN     std_logic;
      CKE_FSM     : IN     std_logic;
      DQM_FSM     : IN     std_logic_vector (1 DOWNTO 0);
      BS_FSM      : IN     std_logic_vector (1 DOWNTO 0);
      A_FSM       : IN     std_logic_vector (11 DOWNTO 0);
      --  От подсистемы
      nCS_Subsys  : IN     std_logic;
      nRAS_Subsys : IN     std_logic;
      nCAS_Subsys : IN     std_logic;
      nWE_Subsys  : IN     std_logic;
      CKE_Subsys  : IN     std_logic;
      DQM_Subsys  : IN     std_logic_vector(1 DOWNTO 0);
      BS_Subsys   : IN     std_logic_vector (1 DOWNTO 0);
      A_Subsys    : IN     std_logic_vector (11 DOWNTO 0);
      --  Выходы на SDRAM
      nCS         : OUT    std_logic;
      nRAS        : OUT    std_logic;
      nCAS        : OUT    std_logic;
      nWE         : OUT    std_logic;
      CKE         : OUT    std_logic;
      DQM         : OUT    std_logic_vector (1 DOWNTO 0);
      BS          : OUT    std_logic_vector (1 DOWNTO 0);
      A           : OUT    std_logic_vector (11 DOWNTO 0)
   );
end component;

-- Компонент FSM контроллера
component SDRAM_FSM is
   GENERIC(
      DataWidth   => DataWidth,
      BurstLength => Burst_length,
      CAS_Latency => CAS_Latency,
      tRCD_Cycles => tRCD_Cycles,
      tRP_Cycles  => tRP_Cycles,
      AddressWidth => AddressWidth
   );
   PORT(
      -- Общие
      Clk           : IN  std_logic;
      nRst          : IN  std_logic;

      -- Взаимодействие с Subsystem
      StateSubsys   : IN  StateSubsys_type;
      StateFSM      : OUT StateFSM_type;
      A_FSM         : OUT std_logic_vector(11 DOWNTO 0);

      -- Взаимодействие с Avalon
      -- Чтение
      read_cmd_fifo_in     : IN  std_logic_vector(57 DOWNTO 0); -- 1op + 25addr + 8be1 + 8be2 + 8id + 8size
      read_cmd_fifo_empty  : IN  std_logic;
      read_cmd_fifo_en     : OUT std_logic;

      read_data_fifo_in    : IN  std_logic_vector(63 DOWNTO 0);
      read_data_fifo_empty : IN  std_logic;
      read_data_fifo_en    : OUT std_logic;

      -- Запись
      write_cmd_fifo_out    : OUT std_logic_vector(15 DOWNTO 0); -- 8id + 8size
      write_cmd_fifo_full   : IN  std_logic;
      write_cmd_fifo_en     : OUT std_logic;

      write_data_fifo_out   : OUT std_logic_vector(63 DOWNTO 0);
      write_data_fifo_full  : IN  std_logic;
      write_data_fifo_en    : OUT std_logic;

      -- Выходы на арбитр SDRAM
      nCS           : OUT std_logic;
      nRAS          : OUT std_logic;
      nCAS          : OUT std_logic;
      nWE           : OUT std_logic;
      CKE           : OUT std_logic;
      DQ            : OUT std_logic_vector(15 downto 0);
      DQM           : OUT std_logic_vector(1 DOWNTO 0);
      BS            : OUT std_logic_vector(1 DOWNTO 0);
      A             : OUT std_logic_vector(11 DOWNTO 0)
   );
END component;
  
    component PLL_i12MHz_o80MHz_o160MHz IS
	PORT
	(
		areset		: IN STD_LOGIC;
		inclk0		: IN STD_LOGIC;
		c0				: OUT STD_LOGIC ; --80MHz
		c1				: OUT STD_LOGIC ; --160MHz
		locked		: OUT STD_LOGIC 
	);
  end component;

begin

  -- надо сгенерировать ALTPLL с inclk0 = 12.000 MHz
  -- и выходами c0 ~80 MHz, c1 ~166.667 MHz. Подставьте имя сгенерированного компонента.
  --??????
  pll_inst : PLL_i12MHz_o80MHz_o160MHz  -- Изменить имя
	port map (
		areset  => not reset_n,  -- активный высокий уровень
		inclk0  => clk_12MHz,
		c0      => pll_clk_80MHz,  -- 80 MHz (avalon)
		c1      => pll_clk_160MHz, -- 160 MHz (sdram)
		locked  => pll_locked
	);

  -- внутренние такты
  clk_avalon <= pll_clk_80MHz;
  clk_sdram  <= pll_clk_160MHz;

  -- Формируем глобальный reset_n, который учитывает pll_locked
  global_reset_n <= reset_n and pll_locked;

  -- Синхронизируем reset для Avalon domain
  process(clk_avalon, global_reset_n)
  begin
    if rising_edge(clk_avalon) then
        reset_avalon_ff(0) <= global_reset_n;
        reset_avalon_ff(1) <= reset_avalon_ff(0);
    end if;
  end process;
  reset_avalon_n <= reset_avalon_ff(1);

  -- Синхронизируем reset для SDRAM domain
  process(clk_sdram, global_reset_n)
  begin
    if rising_edge(clk_sdram) then
        reset_sdram_ff(0) <= global_reset_n;
        reset_sdram_ff(1) <= reset_sdram_ff(0);
	 end if; 
	end process;
  reset_sdram_n <= reset_sdram_ff(1);
  -- Avalon slave соеденяется с FIFO
  avalon_inst : avalon_slave
  port map (
    -- Основные сигналы
    clk_80MHz => clk_avalon,
    nRST => reset_avalon_n,
   
    -- Avalon-MM интерфейс от мастера
    address_master => address_master,
    read_master => read_master,
    write_master => write_master,
    write_data_master => write_data_master,
    byte_enable_master => byte_enable_master,
    burstcount_master => burstcount_master,
    burstenable_master => burstenable_master,

    -- Avalon-MM интерфейс к мастеру
    read_data_avs => read_data_avs,
    waitrequest_avs => waitrequest_avs,
   
    -- Интерфейсы к FIFO (логика управления FIFO)
    -- Командная FIFO записи
    wr_cmd_full => wr_cmd_full,
    wr_cmd => wr_cmd,
    wr_cmd_write => wr_cmd_write,
   
    -- Данные FIFO записи
    wr_data_full => wr_data_full,
    wr_data => wr_data_to_fsm,
    wr_data_write => wr_data_write,
   
    -- Командная FIFO чтения
    rd_cmd_empty => rd_cmd_empty,
    rd_cmd => rd_cmd,
    rd_cmd_read => rd_cmd_read,
   
    -- Данные FIFO чтения
    rd_data_empty => rd_data_empty,
    rd_data => rd_data,
    rd_data_read => rd_data_read
  );

-- Командная FIFO записи (ширина 66 бит, глубина 128)
	wr_cmd_fifo_inst : FIFO
    generic map (
        DATA_WIDTH => 66,
        FIFO_DEPTH => 128
    )
    port map (
        -- Интерфейс записи (Avalon domain)
        data_i    => wr_cmd,
        wr_clk    => clk_avalon,
        wr_empty  => wr_cmd_fifo_wr_empty,
        wr_full   => wr_cmd_full,
        wr_used   => wr_cmd_fifo_wr_used,
        wr_reset  => reset_avalon_n,
        wr_en     => wr_cmd_write,
        
        -- Интерфейс чтения (SDRAM domain)
        data_o    => wr_cmd_fifo_data_o,
        rd_clk    => clk_sdram,
        rd_empty  => wr_cmd_fifo_rd_empty,
        rd_full   => wr_cmd_fifo_rd_full,
        rd_used   => wr_cmd_fifo_rd_used,
        rd_reset  => reset_sdram_n,
        rd_en     => rd_cmd_fifo_rd_en
    );

-- Командная FIFO чтения (ширина 34 бита, глубина 128)
rd_cmd_fifo_inst : FIFO
    generic map (
        DATA_WIDTH => 34,  -- rd_cmd имеет ширину 34 бита
        FIFO_DEPTH => 128
    )
    port map (
        -- Интерфейс записи (SDRAM domain)
        data_i    => rd_cmd_fifo_data_i,  -- TODO: подключить от FSM контроллера
        wr_clk    => clk_sdram,
        wr_empty  => open,
        wr_full   => open,
        wr_used   => open,
        wr_reset  => reset_sdram_n,
        wr_en     => rd_cmd_fifo_wr_en,
        
        -- Интерфейс чтения (Avalon domain)
        data_o    => rd_cmd,
        rd_clk    => clk_avalon,
        rd_empty  => rd_cmd_empty,
        rd_full   => open,
        rd_used   => open,
        rd_reset  => reset_avalon_n,
        rd_en     => rd_cmd_read
    );
-- FIFO данных (ширина 64 бита, глубина 1024)
data_fifo_inst : FIFO
    generic map (
        DATA_WIDTH => 64,
        FIFO_DEPTH => 1024
    )
    port map (
        -- Интерфейс записи (Avalon domain)
        data_i    => wr_data_to_fsm,
        wr_clk    => clk_avalon,
        wr_empty  => data_fifo_wr_empty,
        wr_full   => wr_data_full,
        wr_used   => data_fifo_wr_used,
        wr_reset  => reset_avalon_n,
        wr_en     => wr_data_write,
        
        -- Интерфейс чтения (SDRAM domain)
        data_o    => data_fifo_data_o,
        rd_clk    => clk_sdram,
        rd_empty  => data_fifo_rd_empty,
        rd_full   => data_fifo_rd_full,
        rd_used   => data_fifo_rd_used,
        rd_reset  => reset_sdram_n,
        rd_en     => rd_data_read
    );
	 
fsm_inst : SDRAM_FSM
  generic map (
    EXT_DATA_WIDTH => EXT_DATA_WIDTH,
    CAS_LATENCY    => CAS_LATENCY,
    BURST_LENGTH   => BURST_LENGTH
  )
  port map (
    clk            => clk_sdram,
    reset_n        => reset_sdram_n,
    
    -- Интерфейс с FIFO команд
    rd_cmd         => rd_cmd,
    rd_cmd_empty   => rd_cmd_empty,
    rd_cmd_read    => rd_cmd_read,
    -- Интерфейс с FIFO данных
    rd_data        => data_fifo_data_o,
    rd_data_empty  => rd_data_empty,
    rd_data_read   => rd_data_read,
    
    wr_data        => wr_data,
    wr_data_full   => wr_data_full,
    wr_data_write  => wr_data_write,
    
	 wr_cmd         => wr_cmd_fifo_data_o(CMD_WIDTH-1 downto 0),
    wr_cmd_empty   => wr_cmd_fifo_rd_empty,
    wr_cmd_read    => wr_cmd_fifo_rd_en,
    -- Выходы управления для подсистемы
    StateFSM       => StateFSM_sig,
    BS_FSM         => BS_FSM_sig,
    A_FSM          => A_FSM_sig,
    
    -- Прямые выходы для арбитра
    nCS_FSM        => nCS_FSM_sig,
    nRAS_FSM       => nRAS_FSM_sig,
    nCAS_FSM       => nCAS_FSM_sig,
    nWE_FSM        => nWE_FSM_sig,
    CKE_FSM        => CKE_FSM_sig,
    DQM_FSM        => DQM_FSM_sig,
    
    -- Интерфейс данных SDRAM
    sdram_dq       => sdram_dq_sig
  );

  
  subsystem_inst : SDRAM_Subsystem
  port map (
    nRst      => reset_sdram_n,
    CLK       => clk_sdram,
    
    -- Входы от FSM контроллера
      StateFSM  => StateFSM_sig,
      BS_FSM    => BS_FSM_sig,
      A_FSM     => A_FSM_sig,
      
      -- Выходы управления
      nCS       => nCS_Subsys,
      nRAS      => nRAS_Subsys,
      nCAS      => nCAS_Subsys,
      nWE       => nWE_Subsys,
      CKE       => CKE_Subsys,
      DQM       => DQM_Subsys,
      BS        => BS_Subsys,
      A         => A_Subsys,
      
      -- Состояние подсистемы
      State_out => State_out_Subsys
  );
  
  arbiter_inst : SDRAM_Arbiter
  port map (
    nRst        => reset_sdram_n,
    CLK         => clk_sdram,
    
    StateFSM    => StateFSM_sig,
    
    -- Сигналы от подсистемы
    A_Subsys    => A_Subsys,
    BS_Subsys   => BS_Subsys,
    nCS_Subsys  => nCS_Subsys,
    nRAS_Subsys => nRAS_Subsys,
    nCAS_Subsys => nCAS_Subsys,
    nWE_Subsys  => nWE_Subsys,
    CKE_Subsys  => CKE_Subsys,
    DQM_Subsys  => DQM_Subsys,
    
    -- Сигналы от FSM контроллера
    A_FSM       => A_FSM_sig,
    BS_FSM      => BS_FSM_sig,
    nCS_FSM     => nCS_FSM_sig,
    nRAS_FSM    => nRAS_FSM_sig,
    nCAS_FSM    => nCAS_FSM_sig,
    nWE_FSM     => nWE_FSM_sig,
    CKE_FSM     => CKE_FSM_sig,
    DQM_FSM     => DQM_FSM_sig,
    
    -- Выходные сигналы к SDRAM
    A           => A,
    BS          => BS,
    nCS         => nCS,
    nRAS        => nRAS,
    nCAS        => nCAS,
    nWE         => nWE,
    CKE         => CKE,
    DQM         => DQM
  );

  sdram_clk <= pll_clk_160MHz;

end architecture rtl;
