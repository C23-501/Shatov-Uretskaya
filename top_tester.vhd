library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.TOP_SDRAM_package.all;

entity top_tester is
  port (
	 clk_12MHz : in    std_logic;
	 avalon_clk_out : in    std_logic;
    reset_n   : out    std_logic; --in 
	 pll_locked : in std_logic;
	 
    avs       : inout avlmm_a24b_d64_t;
    sim_done  : out   boolean
  );
end entity top_tester;

architecture behavioral of top_tester is
  -- массивы для burst операций
  signal write_data_array : my_ram64(0 to 31) := (others => (others => '0'));
  signal read_data_array  : my_ram64(0 to 31) := (others => (others => '0'));
  
begin
    
  -- основной тестовый процесс
  test_process : process
    variable test_address : std_logic_vector(24 downto 0);
    variable test_data    : std_logic_vector(63 downto 0);
  begin
    
    -- инициализация
    sim_done <= false;
    
    -- ждем окончания сброса и стабилизации PLL
	 reset_n <= '0';
	 avs.address_master     <= (others => '0');
    avs.read_master        <= '0';
    avs.write_master       <= '0';
    avs.write_data_master  <= (others => '0');
	 avs.byte_enable_master <= (others => '0');
    avs.burstcount_master  <= (others => '0');
    avs.burstenable_master <= '0';
--	 avs.read_data_avs   <= (others => 'Z');
  --  avs.waitrequest_avs <= 'Z';
 --   avs.read_data_valid <= 'Z';
	 
	 wait_clock(1,clk_12MHz);
	 reset_n <= '1';
	 wait_clock(1,clk_12MHz);
	 wait until pll_locked = '1';
	 wait for 210 us;
	 wait_clock(1,clk_12MHz);
	 
    report "START: TOP_SDRAM Testing" severity note;
    
    
    -- TEST 1: одиночная запись
    report "TEST 1: Single Write" severity note;
    
    test_address := "0000000000000000000000000"; -- адрес 0x0000000
    test_data    := X"1122334455667788";
    
    master_single_write(
      avs       => avs,
      clk       => avalon_clk_out,
      address   => test_address,
      writedata => test_data,
      bytecount => 8  -- 8 байт (полное слово)
    );
    
    wait for 1 us;
    report "TEST 1: DONE - Single write at address 0x0000000" severity note;
    
    
    -- TEST 2: одиночная запись с частичным byte_enable
    report "TEST 2: Single Write with partial byte_enable" severity note;
    
    test_address := "0000000000000000000001000"; -- адрес 0x0000008
    test_data    := X"AABBCCDDEE112233";
    
    master_single_write(
      avs       => avs,
      clk       => avalon_clk_out,
      address   => test_address,
      writedata => test_data,
      bytecount => 4
    );
    
    wait for 1 us;
    report "TEST 2: DONE - Partial write at address 0x0000008" severity note;
    
    
	     -- TEST 4: burst запись
    report "TEST 4: Burst Write" severity note;
    
    -- подготовка тестовых данных для burst записи
    for i in 0 to 7 loop
      write_data_array(i) <= CONV_STD_LOGIC_VECTOR(16#A0000000# + i*16#11111111#, 64);
    end loop;
    
    test_address := "0000000000000000000010000"; -- адрес 0x0000010
    
    master_burst_write(avs, write_data_array, avalon_clk_out, test_address, 64);
    
    wait for 2 us;
    report "TEST 4: DONE - Burst write of 8 words at address 0x0000010" severity note;
	 
	 
	 
	 
	  report "TEST 7: Burst Write with Unaligned Address" severity note;
    
    -- подготовка данных
    for i in 0 to 7 loop
      write_data_array(i) <= CONV_STD_LOGIC_VECTOR(16#B0000000# + i*16#01010101#, 64);
    end loop;
    
    test_address := "0000000000000000000110011"; -- адрес 0x0000033 (невыровненный)
    
    master_burst_write(avs, write_data_array, avalon_clk_out, test_address, 60);
    
    wait for 2 us;
    report "TEST 7: DONE - Burst write with unaligned address" severity note;
	 
	 
	 
	 
	 
    -- TEST 3: одиночное чтение
    report "TEST 3: Single Read" severity note;
    
    test_address := "0000000000000000000000000"; -- адрес 0x0000000
    
    master_single_read(
      avs       => avs,
      clk       => avalon_clk_out,
      address   => test_address,
      bytecount => 8
    );
    
    -- ждем данные
    wait until avs.read_data_valid = '1';
    wait for 100 ns;
    
    -- проверка прочитанных данных
    report "TEST 3: DONE - Read data: 0x" & 
           integer'image(CONV_INTEGER(avs.read_data_avs(31 downto 0))) 
           severity note;
    
    

    
    
--    TEST 5: burst чтение
--    report "TEST 5: Burst Read" severity note;
--    
--    test_address := "0000000000000000000010000"; -- адрес 0x0000010
--    
--    master_burst_read(avs, read_data_array, avalon_clk_out, test_address, 64);
--    
--    wait for 2 us;
--    report "TEST 5: DONE - Burst read of 8 words at address 0x0000010" severity note;
--    
--    -- вывод прочитанных данных
--    for i in 0 to 7 loop
--      report "Read word " & integer'image(i) & ": 0x" & 
--             integer'image(CONV_INTEGER(read_data_array(i)(31 downto 0))) 
--             severity note;
--    end loop;
    
    
    -- TEST 6: несколько последовательных операций
    report "TEST 6: Multiple Sequential Operations" severity note;
    
    -- запись 1
    master_single_write(
      avs       => avs,
      clk       => avalon_clk_out,
      address   => "0000000000000000000100000", -- 0x0000020
      writedata => X"1111111111111111",
      bytecount => 8
    );
    
    wait for 500 ns;
    
    -- запись 2
    master_single_write(
      avs       => avs,
      clk       => avalon_clk_out,
      address   => "0000000000000000000100100", -- 0x0000028
      writedata => X"2222222222222222",
      bytecount => 8
    );
    
    wait for 500 ns;
    
    -- чтение 1
    master_single_read(
      avs       => avs,
      clk       => avalon_clk_out,
      address   => "0000000000000000000100000",
      bytecount => 8
    );
    
    wait until avs.read_data_valid = '1';
    wait for 500 ns;
    
    report "TEST 6: DONE - Sequential operations" severity note;
    
    
    -- TEST 7: burst запись с невыровненным адресом
    report "TEST 7: Burst Write with Unaligned Address" severity note;
    
    -- подготовка данных
    for i in 0 to 7 loop
      write_data_array(i) <= CONV_STD_LOGIC_VECTOR(16#B0000000# + i*16#01010101#, 64);
    end loop;
    
    test_address := "0000000000000000000110011"; -- адрес 0x0000033 (невыровненный)
    
    master_burst_write(avs, write_data_array, clk_12MHz, test_address, 60);
    
    wait for 2 us;
    report "TEST 7: DONE - Burst write with unaligned address" severity note;
    
    
    -- TEST 8: максимальный burst
    report "TEST 8: Maximum Burst (16 words)" severity note;
    
    -- подготовка данных
    for i in 0 to 15 loop
      write_data_array(i) <= CONV_STD_LOGIC_VECTOR(16#C0000000# + i*16#00100000#, 64);
    end loop;
    
    test_address := "0000000000000000001000000"; -- адрес 0x0000040
    
    master_burst_write(avs, write_data_array, avalon_clk_out, test_address, 128);
    
    wait for 3 us;
    report "TEST 8: DONE - Maximum burst write" severity note;
    
    
    -- завершение тестирования
    wait for 5 us;
    
    report "All tests completed successfully!" severity note;
    
    sim_done <= true;
    wait;
    
  end process test_process;

end architecture behavioral;