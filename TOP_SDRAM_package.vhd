library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;

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
  type StateSubsys_type is (Idle, Ctr_request, Precharge, SetMR, Refresh, ValidOp, Waiting_precharge, Waiting_SetMR, Waiting_refresh);-- FSM состояния

  type my_ram64 is array (natural range <>) of std_logic_vector(63 downto 0);--???
  
  type avlmm_a24b_d64_t is record
    address_master : std_logic_vector(24 downto 0);
    read_master : std_logic;
    write_master : std_logic;
    write_data_master : std_logic_vector(63 downto 0);
    byte_enable_master : std_logic_vector(7 downto 0);
    burstcount_master : std_logic_vector(4 downto 0);
    burstenable_master : std_logic;

	 read_data_avs : std_logic_vector(63 downto 0);
    waitrequest_avs : std_logic;
	 read_data_valid : std_logic;
  end record avlmm_a24b_d64_t;
  

  procedure wait_clock(constant clk_ticks:integer; signal clk : in std_logic);
  

	 --одиночная запись
procedure master_single_write(--добавить определение того, что пакетная запись
  signal avs : inout avlmm_a24b_d64_t;  -- Сигналы Avalon-MM интерфейса
  signal clk : in std_logic;
  address      : in std_logic_vector(24 downto 0);
  writedata    : in std_logic_vector(63 downto 0);
  bytecount : integer); 
	 
	 --одиночное чтение
procedure master_single_read(--добавить определение того, что пакетная запись
  signal avs : inout avlmm_a24b_d64_t;  -- Сигналы Avalon-MM интерфейса
  signal clk : in std_logic;
  address      : in std_logic_vector(24 downto 0);
  bytecount : integer);
  

  -- burst запись
  procedure master_burst_write(
    signal avs    : inout avlmm_a24b_d64_t;
    signal data   : in my_ram64;
    signal clk    : in std_logic;
    address       : in std_logic_vector(24 downto 0);
    bytecount     : in integer
  );
  
  -- burst чтение
  procedure master_burst_read(
    signal avs    : inout avlmm_a24b_d64_t;
    signal data   : out my_ram64;
    signal clk    : in std_logic;
    address       : in std_logic_vector(24 downto 0);
    bytecount     : in integer
  );
  
end package TOP_SDRAM_package;

package body TOP_SDRAM_package is
  --функция проверки на одиночную передачу
  --возращает 1 если одиночная, 0 если бурст
--проверка одиночная ли передача
	 function is_single(
        byte_count      : integer; 
        address         : std_logic_vector
    ) return boolean is
        variable start_offset : integer;
    begin
        -- 1. Вычисляем смещение начального байта внутри слова шины.
        -- берем остаток от деления адреса на ширину шины.
        start_offset := CONV_INTEGER(address) mod 8;
        if (start_offset + byte_count) <= 8 then
            return true;
        else
            return false;
        end if;
    end function;
--вычисление byteenable
function calc_byte_enable(address : std_logic_vector; byte_count : integer) return std_logic_vector is
        variable be : std_logic_vector(7 downto 0) := (others => '0');
        variable start_idx : integer;
    begin
        start_idx := CONV_INTEGER(address(2 downto 0));
        
        for i in start_idx to 7 loop
            if (i < start_idx + byte_count) then
                be(i) := '1';
            end if;
        end loop;
        
        return be;
    end function;
	 
	 
--расчёт длины бурст
    function calc_burst_count(
        address    : std_logic_vector; 
        byte_count : integer
    ) return std_logic_vector is
        variable start_offset : integer;
        variable total_bytes  : integer;
        variable words_num    : integer;
    begin

        start_offset := CONV_INTEGER(address(2 downto 0));
        
        total_bytes := start_offset + byte_count;
        
        words_num := (total_bytes + 7) / 8;
        
        return CONV_STD_LOGIC_VECTOR(words_num, 5);
    end function;

--вычисление byteenable для бурст
    function calc_burst_byte_enable(
        beat_idx   : integer;
        address    : std_logic_vector;
        byte_count : integer
    ) return std_logic_vector is
        variable be           : std_logic_vector(7 downto 0) := (others => '0');
        variable start_offset : integer;
        variable global_idx   : integer;
    begin
        -- Смещение начального адреса
        start_offset := CONV_INTEGER(address(2 downto 0));
        
        -- Проходим по всем 8 байтам текущего слова
        for i in 0 to 7 loop
            global_idx := (beat_idx * 8) + i;

            if (global_idx >= start_offset) and (global_idx < (start_offset + byte_count)) then
                be(i) := '1';
            else
                be(i) := '0';
            end if;
        end loop;
        
        return be;
    end function;
	 
	 
	 
   procedure wait_clock(constant clk_ticks:integer; signal clk : in std_logic) is
    variable i : integer := 0;
   begin
     for i in 0 to clk_ticks loop
       wait until rising_edge(clk);
       wait for 200 ps;
     end loop;
   end wait_clock;
	
	
	
	--одиночная запись
	--assert
procedure master_single_write(--добавить определение того, что пакетная запись
  signal avs : inout avlmm_a24b_d64_t;  -- Сигналы Avalon-MM интерфейса
  signal clk : in std_logic;
  address      : in std_logic_vector(24 downto 0);
  writedata    : in std_logic_vector(63 downto 0);
  bytecount : integer
  
) is
begin
  -- проверка точно ли это одиночная запись adress+bytecount
	if is_single(bytecount, address) = false then
	assert false 
         report "Not single operation" 
         severity failure;
    else
    avs.waitrequest_avs <= 'Z';
	 wait_clock(0,clk);
	 avs.write_master <= '1';
    avs.read_master <= '0';
	 avs.address_master <= address;
    avs.write_data_master <= writedata;
    avs.byte_enable_master <= calc_byte_enable(address, bytecount);
	 wait until avs.waitrequest_avs = '0';
	 wait_clock(0,clk);
    avs.write_master <= '0';
    avs.address_master <= (others => '0');
    avs.write_data_master <= (others => '0');
    avs.byte_enable_master <= (others => '0');
	 end if;
end procedure;

--одиночное чтение
procedure master_single_read(--добавить определение того, что пакетная запись
  signal avs : inout avlmm_a24b_d64_t;  -- Сигналы Avalon-MM интерфейса
  signal clk : in std_logic;
  address      : in std_logic_vector(24 downto 0);
  bytecount : integer  
) is
  begin
  -- проверка точно ли одиночное чтение
	 if is_single(bytecount, address) = false then
	  assert false 
         report "Not single operation" 
         severity failure;
    else
	 avs.waitrequest_avs <= 'Z';
	 wait_clock(0,clk);
	 avs.read_master <= '1';
    avs.write_master <= '0';
    avs.address_master <= address;	 
    avs.byte_enable_master <= calc_byte_enable(address,bytecount);
	 wait until avs.waitrequest_avs = '0';
	 wait_clock(0,clk);
    avs.read_master <= '0';
    avs.address_master <= (others => '0');
    avs.byte_enable_master <= (others => '0');
	 end if;
end procedure;


   -- три младшие адреса должны быть нулями , а три старшие 
   --должны быть единцы. прим. 82 => первые два байта 
   --нули (все что меньше переданного адреса - 0 , 
   --все что больше или равно- 1)

  --бурст запись
procedure master_burst_write(
    signal avs : inout avlmm_a24b_d64_t;  -- Сигналы Avalon-MM интерфейса
    signal data : in my_ram64;
    signal clk : in std_logic;
    address    : in std_logic_vector(24 downto 0);
    bytecount : in integer

  ) is
  -- переменные для расчета burstcount
  variable v_burst_count_vec : std_logic_vector(4 downto 0);
  variable v_burst_len_int   : integer;
 
 begin --проверка на бурст операцию
  if is_single(bytecount, address) = true then
    assert false 
         report "Not burst operation" 
         severity failure;
    else --расчет переменных количества слов (burstcount)
	 
	 v_burst_count_vec := calc_burst_count(address, bytecount);
    v_burst_len_int   := CONV_INTEGER(v_burst_count_vec);
	 
	avs.waitrequest_avs <= 'Z';  -- Устанавливаем waitrequest в Z состояние (ожидаем сигнал от Avalon)
 	wait_clock(0,clk);
    avs.write_master       <= '1';
    avs.read_master <= '0';    
    avs.burstenable_master   <= '1';
	 avs.address_master      <= address;
	 avs.burstcount_master  <= v_burst_count_vec;
	 wait_clock(0,clk);
    avs.burstenable_master  <= '0';
	 
	  for i in 0 to v_burst_len_int - 1 loop -- посылаем слова в Avalon
			avs.write_data_master  <= data(i);
			avs.byte_enable_master <= calc_burst_byte_enable(i, address, bytecount);
			loop
				 -- Проверяем waitrequest. Если '0', значит данные приняты, выходим из цикла
				 if avs.waitrequest_avs = '0' then
					  exit; 
				 end if;
				 wait_clock(0, clk);
			end loop;
			wait_clock(0, clk);
			
	  end loop;
	 
   --завершаем запись
		avs.write_master       <= '0';
      avs.burstenable_master <= '0';
      avs.address_master     <= (others => '0');
      avs.write_data_master  <= (others => '0');
      avs.byte_enable_master <= (others => '0');
      avs.burstcount_master  <= (others => '0');
  end if;
end procedure;



--бурст чтение
procedure master_burst_read(
    signal avs    : inout avlmm_a24b_d64_t;  -- Сигналы Avalon-MM интерфейса
    signal data   : out my_ram64;            -- выходной массив для считанных данных
    signal clk    : in std_logic;
    address       : in std_logic_vector(24 downto 0);
    bytecount     : in integer
) is
	 -- переменные burstcount
    variable v_burst_count_vec : std_logic_vector(4 downto 0);
    variable v_burst_len_int   : integer;
begin
	-- проверка на одиночное чтение
  if is_single(bytecount, address) = true then
        report "Not burst operation" severity failure;
    else
	 
	v_burst_count_vec := calc_burst_count(address, bytecount);
   v_burst_len_int   := CONV_INTEGER(v_burst_count_vec);
	avs.waitrequest_avs    <= 'Z'; 
	-- согласно спецификации подаем сигнал чтения (начало чтения)
	wait_clock(0,clk);
   avs.read_master       <= '1';
   avs.write_master       <= '0';
   avs.burstenable_master <='1';
   avs.address_master     <= address;
   avs.burstcount_master  <= v_burst_count_vec;
	-- согласно спецификации подаем сигнал окончания чтения
	wait_clock(0,clk);
   avs.read_master       <= '0'; 
   avs.burstenable_master <='0';
	avs.address_master     <= (others => '0');
   avs.byte_enable_master <= (others => '0');
   avs.burstcount_master  <= (others => '0');
	-- записываем считанные Avalon данные в массив
   for i in 0 to v_burst_len_int - 1 loop
	
		-- Ждем появления сигнала read_data_valid
		loop
			 if avs.read_data_valid = '1' then
				  -- Захватываем данные в массив
				  data(i) <= avs.read_data_avs;
				  exit; -- Данные пойманы, переходим к следующей итерации i
			 end if;
			 wait_clock(0, clk);
		end loop;
		
  end loop;


  end if;
end procedure;


end package body TOP_SDRAM_package;
