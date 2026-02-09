 TOP_SDRAM_tb.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
library work;
use work.SDRAM_TOP_package.all;

architecture tb of tb_TOP_SDRAM is

  -- Тестовые сигналы
  signal clk_12MHz        : std_logic := '0';
  signal reset_n          : std_logic := '0';

  -- Avalon-MM интерфейс
  signal address_master   : std_logic_vector(24 downto 0);
  signal read_master      : std_logic := '0';
  signal write_master     : std_logic := '0';
  signal write_data_master: std_logic_vector(63 downto 0);
  signal byte_enable_master : std_logic_vector(7 downto 0);
  signal burstcount_master : std_logic_vector(4 downto 0);
  signal burstenable_master : std_logic := '0';

  -- Ответы от Avalon-MM интерфейса
  signal read_data_avs    : std_logic_vector(63 downto 0);
  signal waitrequest_avs  : std_logic := '0';
  signal read_data_valid  : std_logic := '0';

  -- SDRAM сигналы
  signal A                : std_logic_vector(11 downto 0);
  signal BS               : std_logic_vector(1 downto 0);
  signal nCS              : std_logic;
  signal nRAS             : std_logic;
  signal nCAS             : std_logic;
  signal nWE              : std_logic;
  signal CKE              : std_logic;
  signal DQM              : std_logic_vector(1 downto 0);
  signal DQ               : std_logic_vector(15 downto 0);

  -- Сигналы для PLL
  signal pll_clk_80MHz    : std_logic;
  signal pll_clk_160MHz   : std_logic;
  signal pll_locked       : std_logic;

  -- Вспомогательные сигналы
  signal global_reset_n   : std_logic;
  signal reset_avalon_n   : std_logic;
  signal reset_sdram_n    : std_logic;

  -- Сигналы от FSM и другие
  signal StateSubsys      : StateSubsys_type;
  signal StateFSM         : StateFSM_type;
  signal A_FSM            : std_logic_vector(11 downto 0);
  signal nCS_FSM          : std_logic;
  signal nRAS_FSM         : std_logic;
  signal nCAS_FSM         : std_logic;
  signal nWE_FSM          : std_logic;
  signal CKE_FSM          : std_logic;
  signal DQM_FSM          : std_logic_vector(1 downto 0);
  signal BS_FSM           : std_logic_vector(1 downto 0);

begin

  -- Тестовый генератор тактового сигнала
  clk_12MHz <= not clk_12MHz after 50 ns;  -- Тактирование с периодом 100ns (12 МГц)

  -- Инстанцирование компонента TOP_SDRAM
  uut: entity work.TOP_SDRAM
    port map (
      clk_12MHz        => clk_12MHz,
      reset_n          => reset_n,
      address_master   => address_master,
      read_master      => read_master,
      write_master     => write_master,
      write_data_master=> write_data_master,
      byte_enable_master => byte_enable_master,
      burstcount_master => burstcount_master,
      burstenable_master => burstenable_master,
      read_data_avs    => read_data_avs,
      waitrequest_avs  => waitrequest_avs,
      read_data_valid  => read_data_valid,
      A                => A,
      BS               => BS,
      nCS              => nCS,
      nRAS             => nRAS,
      nCAS             => nCAS,
      nWE              => nWE,
      CKE              => CKE,
      DQM              => DQM,
      DQ               => DQ
    );

end behavior;


