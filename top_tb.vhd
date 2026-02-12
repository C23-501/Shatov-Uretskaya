library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.TOP_SDRAM_package.all;

entity TOP_SDRAM_tb is
end entity TOP_SDRAM_tb;

architecture testbench of TOP_SDRAM_tb is

  constant CLK_12MHz_PERIOD : time := 83.333 ns;
  
  signal clk_12MHz : std_logic := '0';
  signal reset_n   : std_logic := '0';
  
  -- Avalon-MM сигналы (разделены на входы и выходы)
  signal address_master     : std_logic_vector(24 downto 0) := (others => '0');
  signal read_master        : std_logic := '0';
  signal write_master       : std_logic := '0';
  signal write_data_master  : std_logic_vector(63 downto 0) := (others => '0');
  signal byte_enable_master : std_logic_vector(7 downto 0) := (others => '0');
  signal burstcount_master  : std_logic_vector(4 downto 0) := (others => '0');
  signal burstenable_master : std_logic := '0';
  signal read_data_avs      : std_logic_vector(63 downto 0);
  signal waitrequest_avs    : std_logic;
  signal read_data_valid    : std_logic;
  
  -- Record для тестера
  signal avs : avlmm_a24b_d64_t;
  
  signal sim_done : boolean := false;
  
  component TOP_SDRAM is
    generic (
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
      clk_12MHz          : in  std_logic;
      reset_n            : in  std_logic;
      address_master     : in  std_logic_vector(24 downto 0);
      read_master        : in  std_logic;
      write_master       : in  std_logic;
      write_data_master  : in  std_logic_vector(63 downto 0);
      byte_enable_master : in  std_logic_vector(7 downto 0);
      burstcount_master  : in  std_logic_vector(4 downto 0);
      burstenable_master : in  std_logic;
      read_data_avs      : out std_logic_vector(63 downto 0);
      waitrequest_avs    : out std_logic;
      read_data_valid    : out std_logic
    );
  end component;

begin

  -- Генератор тактового сигнала
  clk_process : process
  begin
    if not sim_done then
      clk_12MHz <= '0';
      wait for CLK_12MHz_PERIOD / 2;
      clk_12MHz <= '1';
      wait for CLK_12MHz_PERIOD / 2;
    else
      wait;
    end if;
  end process;

  -- Связываем отдельные сигналы с record
  --avs.address_master     <= address_master;
  --avs.read_master        <= read_master;
  --avs.write_master       <= write_master;
  --avs.write_data_master  <= write_data_master;
  --avs.byte_enable_master <= byte_enable_master;
  --avs.burstcount_master  <= burstcount_master;
  --avs.burstenable_master <= burstenable_master;
  avs.read_data_avs      <= read_data_avs;
  avs.waitrequest_avs    <= waitrequest_avs;
  avs.read_data_valid    <= read_data_valid;
  
  -- Обратная связь (от record к сигналам)
  address_master     <= avs.address_master;
  read_master        <= avs.read_master;
  write_master       <= avs.write_master;
  write_data_master  <= avs.write_data_master;
  byte_enable_master <= avs.byte_enable_master;
  burstcount_master  <= avs.burstcount_master;
  burstenable_master <= avs.burstenable_master;

  -- DUT
  DUT : TOP_SDRAM
    generic map (
      FIFO_DEPTH      => 512,
      Burst_length    => 8,
      CAS_Latency     => 3,
      CLK_Freq_MHz    => 160,
      DataWidth       => 16,
      tRCD_Cycles     => 2,
      tRP_Cycles      => 2,
      AddressWidth    => 25,
      FIFO_LOG2_DEPTH => 10
    )
    port map (
      clk_12MHz          => clk_12MHz,
      reset_n            => reset_n,
      address_master     => address_master,
      read_master        => read_master,
      write_master       => write_master,
      write_data_master  => write_data_master,
      byte_enable_master => byte_enable_master,
      burstcount_master  => burstcount_master,
      burstenable_master => burstenable_master,
      read_data_avs      => read_data_avs,
      waitrequest_avs    => waitrequest_avs,
      read_data_valid    => read_data_valid);

  -- Процесс сброса
  reset_process : process
  begin
    reset_n <= '0';
    wait for 500 ns;
    reset_n <= '1';
    wait;
  end process;

  -- Тестер
  tester_inst : entity work.TOP_SDRAM_tester
    port map (
      clk_12MHz => clk_12MHz,
      reset_n   => reset_n,
      avs       => avs,
      sim_done  => sim_done
    );

end architecture testbench;
