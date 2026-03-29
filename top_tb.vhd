library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.TOP_SDRAM_package.all;

entity top_tb is
end entity top_tb; --TOP_SDRAM_tb

architecture testbench of top_tb is

  constant CLK_12MHz_PERIOD : time := 83.333 ns;
  
  signal clk_12MHz : std_logic;
  signal reset_n   : std_logic;
  
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
  
  signal A    : std_logic_vector(11 downto 0);
  signal BS   : std_logic_vector(1 downto 0);
  signal nCS  : std_logic;
  signal nRAS : std_logic;
  signal nCAS : std_logic;
  signal nWE  : std_logic;
  signal CKE  : std_logic;
  signal DQM  : std_logic_vector(1 downto 0);
  signal DQ   : std_logic_vector(15 downto 0);
  
  -- Сигнал тактовой частоты SDRAM (160 МГц)
  signal sdram_clk : std_logic; 
  signal pll_locked_wire : std_logic;
  signal avalon_clk : std_logic;
  -- Сигналы SDRAM (для модели памяти)
  signal A_SDRAM    : std_logic_vector(11 downto 0);
  signal BS_SDRAM   : std_logic_vector(1 downto 0);
  signal nCS_SDRAM  : std_logic;
  signal nRAS_SDRAM : std_logic;
  signal nCAS_SDRAM : std_logic;
  signal nWE_SDRAM  : std_logic;
  signal CKE_SDRAM  : std_logic;
  signal DQM_SDRAM  : std_logic_vector(1 downto 0);
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
      read_data_valid    : out std_logic;
		
		
		A                  : out std_logic_vector(11 downto 0);
      BS                 : out std_logic_vector(1 downto 0);
      nCS                : out std_logic;
      nRAS               : out std_logic;
      nCAS               : out std_logic;
      nWE                : out std_logic;
      CKE                : out std_logic;
      DQM                : out std_logic_vector(1 downto 0);
      DQ                 : out std_logic_vector(15 downto 0);
		sdram_clk_out      : out std_logic;
		pll_locked_out : out std_logic;
		avalon_clk_out : out std_logic
 
	 );
  end component;
  
  COMPONENT mt48lc4m16a2
    GENERIC (
       addr_bits : integer := 12;
       data_bits : integer := 16;
       col_bits  : integer := 8;
       mem_sizes : integer := 1048575
    );
    PORT (
       Dq    : INOUT  std_logic_vector (data_bits - 1 DOWNTO 0);
       Addr  : IN     std_logic_vector (addr_bits - 1 DOWNTO 0);
       Ba    : IN     std_logic_vector (1 DOWNTO 0);
       Clk   : IN     std_logic ;
       Cke   : IN     std_logic ;
       Cs_n  : IN     std_logic ;
       Ras_n : IN     std_logic ;
       Cas_n : IN     std_logic ;
       We_n  : IN     std_logic ;
       Dqm   : IN     std_logic_vector (1 DOWNTO 0)
    );
   END COMPONENT;

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
  --задержки
   nCS_SDRAM <= nCS after 1.2 ns;
   nRAS_SDRAM <= nRAS after 1.2 ns;
   nCAS_SDRAM <= nCAS after 1.2 ns;
   nWE_SDRAM <= nWE after 1.2 ns;
   CKE_SDRAM <= CKE after 1.2 ns;
   DQM_SDRAM <= DQM after 1.2 ns;
   BS_SDRAM <= BS after 1.2 ns;
   A_SDRAM <= A after 1.2 ns;
  
  
  
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
      read_data_valid    => read_data_valid,
		
		
		A   => A,
      BS  => BS,
      nCS => nCS,
      nRAS  => nRAS,
      nCAS=> nCAS,
      nWE => nWE,
      CKE => CKE,
      DQM => DQM,
      DQ  => DQ,
		sdram_clk_out => sdram_clk,
		pll_locked_out => pll_locked_wire,
		avalon_clk_out   => avalon_clk
		);
		
		U_SDRAM : mt48lc4m16a2
--    GENERIC MAP (
--       addr_bits => 12,
--       data_bits => 16,
--       col_bits  => 8,
--       mem_sizes => 1048575 -- 4 Meg x 16 (1 МБ * 16 бит))
    PORT MAP (
       Dq    => DQ,
       Addr  => A_SDRAM, 
       Ba    => BS_SDRAM,
       Clk   => sdram_clk,  -- 160 МГц
       Cke   => CKE_SDRAM,
       Cs_n  => nCS_SDRAM,
       Ras_n => nRAS_SDRAM,
       Cas_n => nCAS_SDRAM,
       We_n  => nWE_SDRAM,
       Dqm   => DQM_SDRAM
    );
  -- Процесс сброса
--  reset_process : process
--  begin
--    reset_n <= '0';
--    wait for 500 ns;
--    reset_n <= '1';
--    wait;
--  end process;

  -- Тестер
  tester_inst : entity work.top_tester
    port map (
      clk_12MHz => clk_12MHz,
		avalon_clk_out => avalon_clk,
      reset_n   => reset_n,
      avs       => avs,
      sim_done  => sim_done,
		pll_locked => pll_locked_wire
    );

end architecture testbench;
