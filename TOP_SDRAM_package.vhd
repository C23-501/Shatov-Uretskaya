library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package TOP_SDRAM_package is

  constant DATA_WIDTH      : integer := 64;
  constant FIFO_DEPTH      : integer := 512;
  constant Burst_length    : integer := 8;
  constant CAS_Latency     : integer := 3;
  constant CLK_Freq_MHz    : integer := 160;
  constant DataWidth       : integer := 16;
  constant tRCD_Cycles     : integer := 2;
  constant tRP_Cycles      : integer := 2;
  constant AddressWidth    : integer := 25;
  constant FIFO_LOG2_DEPTH : integer := 10;

  type StateFSM_type is (Idle, Waiting, Reading, Writing, Activation);
  type StateSubsys_type is (Idle, Ctr_request, Precharge, SetMR, Refresh, ValidOp, Waiting_precharge, Waiting_SetMR, Waiting_refresh);
  -- FSM состояния

  type avlmm_a24b_d64_t is record
  
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
  end record avlmm_a24b_d64_t;
  
  procedure wait_clock(constant clk_ticks:integer) is
    variable i : integer := 0;
   begin
     for i in 0 to clk_ticks loop
       wait until rising_edge(int_clk);
       wait for 200 ps;
     end loop;
   end wait_clock;
  
  

end package SDRAM_TOP_package;

package body SDRAM_TOP_package is

  procedure wait_clock(constant clk_ticks:integer) is
    variable i : integer := 0;
   begin
     for i in 0 to clk_ticks loop
       wait until rising_edge(int_clk);
       wait for 200 ps;
     end loop;
   end wait_clock;
	
	
	procedure process_single_data_transfer(--добавить определение того, что пакетная запись
  signal avs : inout avlmm_a24b_d64_t  -- Сигналы Avalon-MM интерфейса
) is
begin
  -- Если burstcount равен 0, выполняем одиночную передачу данных
  if avs.write_master = '1' and (to_integer(unsigned(avs.burstcount_master)) = 0) then
    -- Передаем данные сразу, так как это одиночная передача
    avs.read_data_avs <= avs.write_data_master;  -- Пример передачи данных
    avs.read_data_valid <= '1';  -- Подтверждаем передачу данных
  end if;
end procedure;


procedure process_burst_data_transfer(--добавить определение того, что пакетная запись
  signal avs : inout avlmm_a24b_d64_t;   -- Сигналы Avalon-MM интерфейса
  --добавить куда писать
  --добавить сколько писать
  constant clk_ticks : integer             -- Количество тактов для бурстовой передачи
) is
  variable burst_data_count : integer := 0;  -- Счётчик данных для бурст-передачи
  variable waitreq : boolean := false;  -- Индикатор состояния waitrequest
begin
  -- Проверяем, если это бурстовая передача (burstcount > 0)
  if avs.write_master = '1' and (to_integer(unsigned(avs.burstcount_master)) > 0) then
    avs.waitrequest_avs <= 'Z';  -- Устанавливаем waitrequest в Z состояние
	 avs.
    burst_data_count := to_integer(unsigned(avs.burstcount_master)) + 1;  -- Плюс 1 для первого пакета данных

    -- Начинаем бурстовую передачу данных
    for i in 0 to burst_data_count - 1 loop
      -- Ожидаем следующего такта
      wait until rising_edge(int_clk);
      wait for 200 ps;  -- Задержка между тактами

      -- Передаем данные, если операция записи активна
      if avs.write_master = '1' then
        avs.read_data_avs <= avs.write_data_master;  -- Передача данных
        avs.read_data_valid <= '1';  -- Подтверждаем передачу данных
      end if;

      -- Проверяем, если waitrequest активен
      if avs.waitrequest_avs = '1' then
        waitreq := true;  -- Если waitrequest активен, ожидаем его деактивации
      else
        waitreq := false;
      end if;
    end loop;

    -- После завершения бурст-передачи деактивируем waitrequest
    avs.waitrequest_avs <= '0';  -- Завершаем бурст-запись
  end if;
end procedure;

procedure emulate_waitrequest_read_write(
  signal avs : inout avlmm_a24b_d64_t;
  constant clk_ticks : integer
) is
  variable waitreq : boolean := false;  -- Индикатор состояния waitrequest
begin
  -- Если waitrequest активен, то мастер должен подождать
  if avs.waitrequest_avs = '1' then
    waitreq := true;
  else
    waitreq := false;
  end if;

  -- Ожидание, если waitrequest активен
  while waitreq loop
    -- Используем wait_clock для ожидания нескольких тактов
    wait_clock(clk_ticks);

    -- Проверка состояния waitrequest
    if avs.waitrequest_avs = '0' then
      waitreq := false;  -- Заканчиваем ожидание
    end if;
  end loop;

  -- После завершения ожидания, выполняем операцию (чтение или запись)
  if avs.read_master = '1' then
    avs.read_data_avs <= avs.write_data_master;  -- Пример чтения данных
    avs.read_data_valid <= '1';
  end if;
end procedure;



procedure emulate_decoupled_waitrequest(
  signal avs : inout avlmm_a24b_d64_t;
  constant clk_ticks : integer
) is
  variable waitreq : boolean := false;  -- Индикатор состояния waitrequest
begin
  -- Проверка состояния waitrequest
  if avs.waitrequest_avs = '1' then
    waitreq := true;
  else
    waitreq := false;
  end if;

  -- Ожидаем, если waitrequest активен
  while waitreq loop
    -- Используем процедуру wait_clock для задержки
    wait_clock(clk_ticks);  -- Ожидаем несколько тактов

    -- После задержки проверяем состояние waitrequest
    if avs.waitrequest_avs = '0' then
      waitreq := false;  -- Заканчиваем ожидание
    end if;
  end loop;

  -- Если данные были прочитаны, передаем их в read_data_avs
  if avs.read_master = '1' then
    avs.read_data_avs <= avs.write_data_master;  -- Пример передачи данных
    avs.read_data_valid <= '1';
  end if;

  -- Если была запись, выполняем её
  if avs.write_master = '1' then
    -- Пример записи данных
    -- Здесь можно добавить код для записи данных в память или другую логику
  end if;
end procedure;



end package body TOP_SDRAM_package;
