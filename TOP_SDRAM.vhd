library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.TOP_SDRAM_package.all;
use work.sdram_subsys_package.all;

entity TOP_SDRAM is
  generic (
 -- DATA_WIDTH      : integer := 64;
  FIFO_DEPTH      : integer := 512;
  Burst_length    : integer := 8;
  CAS_Latency     : integer := 3;
  CLK_Freq_MHz    : integer := 160;
  DataWidth       : integer := 16;
  tRCD_Cycles     : integer := 2;
  tRP_Cycles      : integer := 2;
  AddressWidth    : integer := 25;
  FIFO_LOG2_DEPTH : integer := 10
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
	 DQ    		 : out std_logic_vector(15 downto 0)
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
  
	signal s_StateFSM    : StateFSM_type;
    signal s_StateSubsys : StateSubsys_type;

    -- Сигналы от Avalon к FIFO (Commands)
    signal av_wr_cmd       : std_logic_vector(61 downto 0);
    signal av_wr_cmd_write : std_logic;
    signal av_wr_cmd_full  : std_logic;

    -- Сигналы от FIFO к FSM (Commands)
    signal fsm_rd_cmd_in   : std_logic_vector(61 downto 0); -- Выход FIFO шире входа FSM
    signal fsm_rd_cmd_en   : std_logic;
    signal fsm_rd_cmd_empty: std_logic;

    -- Сигналы от Avalon к FIFO (Write Data)
    signal av_wr_data       : std_logic_vector(63 downto 0);
    signal av_wr_data_write : std_logic;
    signal av_wr_data_full  : std_logic;
    signal av_wr_data_used  : std_logic_vector(integer(ceil(log2(real(FIFO_DEPTH)))) downto 0); -- 10 bit

    -- Сигналы от FIFO к FSM (Write Data to SDRAM)
    signal fsm_rd_data_in   : std_logic_vector(63 downto 0);
    signal fsm_rd_data_en   : std_logic;
    signal fsm_rd_data_empty: std_logic;

    -- Сигналы от FSM к FIFO (Read Data from SDRAM)
    signal fsm_wr_data_out  : std_logic_vector(63 downto 0);
    signal fsm_wr_data_en   : std_logic;
    signal fsm_wr_data_full : std_logic;
    signal fsm_wr_data_used : std_logic_vector(9 downto 0);
  
    -- Сигналы от FIFO к Avalon (Read Data)
    signal av_rd_data       : std_logic_vector(63 downto 0);
    signal av_rd_data_read  : std_logic;
    signal av_rd_data_empty : std_logic;

    -- Сигналы от FSM к FIFO (Read Command Response/Tag)
    signal fsm_wr_cmd_out  : std_logic_vector(19 downto 0);
    signal fsm_wr_cmd_en   : std_logic;
    signal fsm_wr_cmd_full : std_logic;

    -- Сигналы от FIFO к Avalon (Read Command Response)
--    signal av_rd_cmd_in     : std_logic_vector(19 downto 0); -- Вход Avalon шире выхода FSM
    signal av_rd_cmd_data   : std_logic_vector(19 downto 0); -- 15?
    signal av_rd_cmd_read   : std_logic;
    signal av_rd_cmd_empty  : std_logic;

    -- Сигналы управления SDRAM (внутренние, до арбитра)
    -- От FSM
    signal fsm_nCS, fsm_nRAS, fsm_nCAS, fsm_nWE, fsm_CKE : std_logic;
    signal fsm_DQM, fsm_BS : std_logic_vector(1 downto 0);
    signal fsm_A           : std_logic_vector(11 downto 0);
    
    -- От SubSys
    signal sub_nCS, sub_nRAS, sub_nCAS, sub_nWE, sub_CKE : std_logic;
    signal sub_DQM, sub_BS : std_logic_vector(1 downto 0);
    signal sub_A           : std_logic_vector(11 downto 0);
  -- компоненты
  
    signal pll_areset : std_logic;
	 -- Инвертированные сигналы сброса для FIFO
	signal reset_avalon_active : std_logic;
	signal reset_sdram_active  : std_logic;
	  
	 
  component AvalonMM_Slave
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
	 read_data_valid : out std_logic;

    -- Avalon-MM интерфейс к мастеру
    read_data_avs : out std_logic_vector(63 downto 0);
    waitrequest_avs : out std_logic;
   
    -- Интерфейсы к FIFO (логика управления FIFO)
    -- Командная FIFO записи
    wr_cmd_full : in std_logic;
    wr_cmd : out std_logic_vector(61 downto 0);
    wr_cmd_write : out std_logic;
   
    -- Данные FIFO записи
    wr_data_full : in std_logic;
    wr_data : out std_logic_vector(63 downto 0);
    wr_data_write : out std_logic;
	 wr_data_used : in std_logic_vector(9 downto 0);
   
    -- Командная FIFO чтения
    rd_cmd_empty : in std_logic;
    rd_cmd : in std_logic_vector(19 downto 0);
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
        wr_used: out std_logic_vector(9 downto 0);
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
component SdramSubsys is
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
component SdramArbiter is
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
component SdramFsm is
        generic (
            DataWidth    : integer;
            BurstLength  : integer;
            CAS_Latency  : integer;
            tRCD_Cycles  : integer;
            tRP_Cycles   : integer;
            AddressWidth : integer;
				tWR_Cycles     : integer := 2;
			  tRAS_Cycles    : integer := 7;
			  UsedWidth      : integer := 10
        );
    port (
        -- Общие
        nRst          : in  std_logic;
        clk           : in  std_logic;

        -- Взаимодействие с Subsystem
        state_subsys   : in  StateSubsys_type;
        state_fsm      : out StateFSM_type;

        -- Взаимодействие с Avalon
        -- Чтение
        request_command_fifo_read_en   : out std_logic;
        request_command_fifo_data      : in  std_logic_vector(61 downto 0);
        request_command_fifo_empty     : in  std_logic;

        request_data_fifo_read_en      : out std_logic;
        request_data_fifo_data         : in  std_logic_vector(63 downto 0);
        request_data_fifo_empty        : in  std_logic;

        -- Запись
        response_command_fifo_write_en : out std_logic;
        response_command_fifo_data     : out std_logic_vector(19 downto 0);
        response_command_fifo_full     : in  std_logic;

        response_data_fifo_write_en    : out std_logic;
        response_data_fifo_data        : out std_logic_vector(63 downto 0);
        response_data_fifo_full        : in std_logic;
        response_data_fifo_used        : in std_logic_vector(UsedWidth-1 downto 0);

        -- Выходы на арбитр SDRAM
        nCS  : out std_logic;
        nRAS : out std_logic;
        nCAS : out std_logic;
        nWE  : out std_logic;
        CKE  : out std_logic;
        DQ   : out std_logic_vector(15 downto 0);
        DQM  : out std_logic_vector(1 downto 0);
        BS   : out std_logic_vector(1 downto 0);
        A    : out std_logic_vector(11 downto 0)
    );
    end component;
	 
	 
  
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
	pll_areset <= not reset_n;
	reset_avalon_active <= not reset_avalon_n;
	reset_sdram_active  <= not reset_sdram_n;
  -- надо сгенерировать ALTPLL с inclk0 = 12.000 MHz
  -- и выходами c0 ~80 MHz, c1 ~166.667 MHz. Подставьте имя сгенерированного компонента.
  --??????
  pll_inst : PLL_i12MHz_o80MHz_o160MHz  -- Изменить имя
	port map (
		areset  => pll_areset,  -- активный высокий уровень
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
  avalon_inst : AvalonMM_Slave
  port map (
    -- Основные сигналы
    clk_80MHz => pll_clk_80MHz,
    nRST => reset_avalon_n,
   
 address_master     => address_master,
        read_master        => read_master,
        write_master       => write_master,
        write_data_master  => write_data_master,
        byte_enable_master => byte_enable_master,
        burstcount_master  => burstcount_master,
        burstenable_master => burstenable_master,
        read_data_avs      => read_data_avs,
        waitrequest_avs    => waitrequest_avs,
        read_data_valid    => read_data_valid,
        
        -- Интерфейс к CMD FIFO (Запись команд)
        wr_cmd_full        => av_wr_cmd_full,
        wr_cmd             => av_wr_cmd,
        wr_cmd_write       => av_wr_cmd_write,
        
        -- Интерфейс к Write Data FIFO (Запись данных для записи)
        wr_data_full       => av_wr_data_full,
        wr_data_used       => av_wr_data_used, -- Приведение типа если нужно
        wr_data            => av_wr_data,
        wr_data_write      => av_wr_data_write,
        
        -- Интерфейс к Read Response FIFO (Получение подтверждений чтения)
        rd_cmd_empty       => av_rd_cmd_empty,
        rd_cmd             => av_rd_cmd_data,
        rd_cmd_read        => av_rd_cmd_read,
        
        -- Интерфейс к Read Data FIFO (Получение прочитанных данных)
        rd_data_empty      => av_rd_data_empty,
        rd_data            => av_rd_data,
        rd_data_read       => av_rd_data_read
    );

-- 1. COMMAND FIFO (Avalon -> FSM)
    FIFO_CMD : FIFO
    generic map (
        DATA_WIDTH => 62, -- Ширина Avalon CMD
        FIFO_DEPTH => FIFO_DEPTH
    )
    port map (
        data_i   => av_wr_cmd,
        wr_clk   => pll_clk_80MHz,
        wr_empty => open,
        wr_full  => av_wr_cmd_full,
        wr_used  => open,
        wr_reset => reset_avalon_active,
        wr_en    => av_wr_cmd_write,
        
        data_o   => fsm_rd_cmd_in,
        rd_clk   => pll_clk_160MHz,
        rd_empty => fsm_rd_cmd_empty,
        rd_full  => open,
        rd_used  => open,
        rd_reset => reset_sdram_active,
        rd_en    => fsm_rd_cmd_en
    );

    -- 2. WRITE DATA FIFO (Avalon -> FSM)
    FIFO_WR_DATA : FIFO
    generic map (
        DATA_WIDTH => 64,
        FIFO_DEPTH => FIFO_DEPTH
    )
    port map (
        data_i   => av_wr_data,
        wr_clk   => pll_clk_80MHz,
        wr_empty => open,
        wr_full  => av_wr_data_full,
        wr_used  => av_wr_data_used,
        wr_reset => reset_avalon_active,
        wr_en    => av_wr_data_write,
        
        data_o   => fsm_rd_data_in,
        rd_clk   => pll_clk_160MHz,
        rd_empty => fsm_rd_data_empty,
        rd_full  => open,
        rd_used  => open,
        rd_reset => reset_sdram_active,
        rd_en    => fsm_rd_data_en
    );

    -- 3. READ DATA FIFO (FSM -> Avalon)
    FIFO_RD_DATA : FIFO
    generic map (
        DATA_WIDTH => 64,
        FIFO_DEPTH => FIFO_DEPTH
    )
    port map (
        data_i   => fsm_wr_data_out,
        wr_clk   => pll_clk_160MHz,
        wr_empty => open,
        wr_full  => fsm_wr_data_full,
        wr_used  => open,
        wr_reset => reset_sdram_active,
        wr_en    => fsm_wr_data_en,
        
        data_o   => av_rd_data,
        rd_clk   => pll_clk_80MHz,
        rd_empty => av_rd_data_empty,
        rd_full  => open,
        rd_used  => open,
        rd_reset => reset_avalon_active,
        rd_en    => av_rd_data_read
    );


    FIFO_RD_RESP : FIFO
    generic map (
        DATA_WIDTH => 20,
        FIFO_DEPTH => FIFO_DEPTH
    )
    port map (
        data_i   => fsm_wr_cmd_out,
        wr_clk   => pll_clk_80MHz,
        wr_empty => open,
        wr_full  => fsm_wr_cmd_full,
        wr_used  => open,
        wr_reset => reset_avalon_active,
        wr_en    => fsm_wr_cmd_en,
        
        data_o   => av_rd_cmd_data,
        rd_clk   => pll_clk_160MHz,
        rd_empty => av_rd_cmd_empty,
        rd_full  => open,
        rd_used  => open,
        rd_reset => reset_sdram_active,
        rd_en    => av_rd_cmd_read
    );
	 
	 
	 
	 
--?? Маппинг выхода FIFO на вход Avalon (расширение нулями)
--   av_rd_cmd_in(15 downto 0)  <= av_rd_cmd_data;
--    av_rd_cmd_in(19 downto 16) <= (others => '0');	 
	 
SDRAM_FSM_inst : SdramFsm
    generic map (
        DataWidth    => DataWidth,
        BurstLength  => Burst_length,
        CAS_Latency  => CAS_Latency,
        tRCD_Cycles  => tRCD_Cycles,
        tRP_Cycles   => tRP_Cycles,
        AddressWidth => AddressWidth,
		  UsedWidth    => 10,
		  tWR_Cycles   => 2,
        tRAS_Cycles  => 7
    )
    port map (
        Clk                  => pll_clk_160MHz,
        nRst                 => reset_sdram_n,

		state_subsys                   => s_StateSubsys,
        state_fsm                      => s_StateFSM,
        
        -- Взаимодействие с Avalon (Request Command)
        request_command_fifo_read_en   => fsm_rd_cmd_en,
        request_command_fifo_data      => fsm_rd_cmd_in,
        request_command_fifo_empty     => fsm_rd_cmd_empty,
        
        -- Взаимодействие с Avalon (Request Data)
        request_data_fifo_read_en      => fsm_rd_data_en,
        request_data_fifo_data         => fsm_rd_data_in,
        request_data_fifo_empty        => fsm_rd_data_empty,
        
        -- Взаимодействие с Avalon (Response Command)
        response_command_fifo_write_en => fsm_wr_cmd_en,
        response_command_fifo_data     => fsm_wr_cmd_out,
        response_command_fifo_full     => fsm_wr_cmd_full,
        
        -- Взаимодействие с Avalon (Response Data)
        response_data_fifo_write_en    => fsm_wr_data_en,
        response_data_fifo_data        => fsm_wr_data_out,
        response_data_fifo_full        => fsm_wr_data_full,
        response_data_fifo_used        => fsm_wr_data_used, -- Новый сигнал
        -- SDRAM Controls (Pre-Arbiter)
        nCS                  => fsm_nCS,
        nRAS                 => fsm_nRAS,
        nCAS                 => fsm_nCAS,
        nWE                  => fsm_nWE,
        CKE                  => fsm_CKE,
        DQ                   => DQ, -- Двунаправленная шина данных SDRAM (напрямую)
        DQM                  => fsm_DQM,
        BS                   => fsm_BS,
        A                    => fsm_A
    );
  
  arbiter_inst : SdramArbiter
    
port map (
    nRst        => reset_sdram_n,
    CLK         => pll_clk_160MHz,
        
        -- Inputs from FSM
        StateFSM    => s_StateFSM,
        nCS_FSM     => fsm_nCS,
        nRAS_FSM    => fsm_nRAS,
        nCAS_FSM    => fsm_nCAS,
        nWE_FSM     => fsm_nWE,
        CKE_FSM     => fsm_CKE,
        DQM_FSM     => fsm_DQM,
        BS_FSM      => fsm_BS,
        A_FSM       => fsm_A,
        
        -- Inputs from SubSys
        nCS_Subsys  => sub_nCS,
        nRAS_Subsys => sub_nRAS,
        nCAS_Subsys => sub_nCAS,
        nWE_Subsys  => sub_nWE,
        CKE_Subsys  => sub_CKE,
        DQM_Subsys  => sub_DQM,
        BS_Subsys   => sub_BS,
        A_Subsys    => sub_A,
        
        -- Outputs to Physical SDRAM (Top Level Ports)
        nCS         => nCS,
        nRAS        => nRAS,
        nCAS        => nCAS,
        nWE         => nWE,
        CKE         => CKE,
        DQM         => DQM,
        BS          => BS,
        A           => A
    );

SDRAM_Subsystem_inst : SdramSubsys
    generic map (
        Burst_length => Burst_length,
        CAS_Latency  => CAS_Latency,
        CLK_Freq_MHz => CLK_Freq_MHz
    )
    port map (
        nRst      => reset_sdram_n ,
        CLK       => pll_clk_160MHz ,
        StateFSM  => s_StateFSM,
        A_FSM     => fsm_A,
        nCS       => sub_nCS,
        nRAS      => sub_nRAS,
        nCAS      => sub_nCAS,
        nWE       => sub_nWE,
        CKE       => sub_CKE,
        DQM       => sub_DQM,
        BS        => sub_BS,
        A         => sub_A,
        State_out => s_StateSubsys
    );	 

--  sdram_clk <= pll_clk_160MHz;

end architecture rtl;
