library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.TOP_SDRAM_package.all;
use work.sdram_subsys_package.all;

entity WrapperTop is
    port (
        -- Входные сигналы платы
        CLK_12MHz   : in std_logic;
        nRst : in std_logic;

        -- Физические сигналы SDRAM
        nCS   : out std_logic;
        nRAS  : out std_logic;
        nCAS  : out std_logic;
        nWE   : out std_logic;
        CKE   : out std_logic;
        DQM   : out std_logic_vector(1 downto 0);
        BS    : out std_logic_vector(1 downto 0);
        A     : out std_logic_vector(11 downto 0);
        Dq    : inout std_logic_vector(15 downto 0);

        -- Отладка
        DBG_nCS  : out std_logic;
        DBG_nRAS : out std_logic;
        DBG_nCAS : out std_logic;
        DBG_nWE  : out std_logic;

        DBG_read_master  : out std_logic;
        DBG_write_master : out std_logic;
        DBG_RD_LOAD : out std_logic;
        DBG_WR_SHIFT : out std_logic;
        DBG_waitrequest_avs : out std_logic;
       
        CLK_160MHz : out std_logic
    );
end entity WrapperTop;

architecture struct of WrapperTop is

    -- Внутренние сигналы Avalon
    signal byte_enable_master_s  : std_logic_vector(7 downto 0);
    signal address_master_s : std_logic_vector(24 downto 0);
    
    signal read_master_s : std_logic;
    signal write_master_s : std_logic;

    signal write_data_master_s : std_logic_vector(63 downto 0);
    
    signal burstcount_master_s  : std_logic_vector(4 downto 0);
    signal burstenable_master_s : std_logic;

	signal read_data_avs_s    : std_logic_vector(63 downto 0); -- in
    signal waitrequest_avs_s  : std_logic; -- in
    signal read_data_valid_s    : std_logic; -- in
    
    signal nCS_s, nRAS_s, nCAS_s, nWE_s : std_logic;
    signal CKE_s : std_logic;
    signal DQM_s : std_logic_vector(1 downto 0);
    signal BS_s  : std_logic_vector(1 downto 0);
    signal A_s   : std_logic_vector(11 downto 0);

    signal CLK_160MHz_o : std_logic;
    signal CLK_80MHz_o  : std_logic;
	 
	 signal rd_load_dbg_s  : std_logic;
    signal wr_shift_dbg_s : std_logic;

    type t_state is (IDLE, WAIT_INIT, SET_WRITE, WRITING, PREP1, 
                           WAIT_GAP1, SET_READ, READING, PREP2,
                           WAIT_GAP2, -- SET_PACKET_WRITE, PACKET_WRITING,
                           -- WAIT_GAP3, SET_PACKET_READ, PACKET_READING,
                           DONE);
    signal st : t_state;

    signal wait_cnt : std_logic_vector(19 downto 0);

    constant INIT_WAIT : std_logic_vector(19 downto 0) := conv_std_logic_vector(17600, wait_cnt'length);
    constant C_WAIT  : std_logic_vector(19 downto 0) := conv_std_logic_vector(800, wait_cnt'length);
    
    constant TEST_LIMIT : integer := 256; -- Сколько слов записать/прочитать
    -- Счётчики данных
    signal write_counter : std_logic_vector(11 downto 0) := (others => '0');
    signal read_counter  : std_logic_vector(11 downto 0) := (others => '0');

begin

    nCS  <= nCS_s;
    nRAS <= nRAS_s;
    nCAS <= nCAS_s;
    nWE  <= nWE_s;
    CKE  <= CKE_s;
    DQM  <= DQM_s;
    BS   <= BS_s;
    A    <= A_s;

    DBG_nCS  <= nCS_s;
    DBG_nRAS <= nRAS_s;
    DBG_nCAS <= nCAS_s;
    DBG_nWE  <= nWE_s;
	
    DBG_read_master  <= read_master_s;
    DBG_write_master <= write_master_s;
    DBG_RD_LOAD <= rd_load_dbg_s;
    DBG_WR_SHIFT <= wr_shift_dbg_s;
	 DBG_waitrequest_avs <= waitrequest_avs_s;
    CLK_160MHz <= CLK_160MHz_o;

    u_sdram_controller : entity work.TOP_SDRAM
    port map (
        -- 1. СИСТЕМНЫЕ ВХОДЫ
        clk_12MHz => CLK_12MHz,   
        reset_n   => nRst, 

        -- 2. ВНУТРЕННИЕ КЛОКИ
        avalon_clk_out => CLK_80MHz_o,     
        sdram_clk_out  => CLK_160MHz_o,
        pll_locked_out => open, 

        -- 3. ИНТЕРФЕЙС AVALON-MM
        byte_enable_master => byte_enable_master_s,
        address_master     => address_master_s,

        read_master        => read_master_s,
        write_master       => write_master_s,
        
        write_data_master  => write_data_master_s,

        burstcount_master  => burstcount_master_s,
        burstenable_master => burstenable_master_s, 

        read_data_avs      => read_data_avs_s,
        waitrequest_avs    => waitrequest_avs_s,
        read_data_valid    => read_data_valid_s,

        -- 4. ФИЗИЧЕСКИЕ ВЫХОДЫ (Подключаем к ПРОМЕЖУТОЧНЫМ сигналам)
        A    => A_s, 
        BS   => BS_s,
        nCS  => nCS_s,  -- <--- Записываем во внутренний сигнал
        nRAS => nRAS_s, 
        nCAS => nCAS_s, 
        nWE  => nWE_s,  
        CKE  => CKE_s,   
        DQM  => DQM_s,
        DQ   => Dq,
		  
		  rd_load_out => rd_load_dbg_s,
        wr_shift_out => wr_shift_dbg_s
    );

    process(nRst, CLK_80MHz_o)
    begin
        if nRst = '0' then
            st <= IDLE;

        elsif rising_edge(CLK_80MHz_o) then
            case st is

                when IDLE =>
                    st <= WAIT_INIT;

                when WAIT_INIT =>
                    if wait_cnt = conv_std_logic_vector(0, wait_cnt'length) then
                        st <= SET_WRITE;
                    end if;

                when SET_WRITE =>
                    st <= WRITING;

                when WRITING =>
                    if waitrequest_avs_s = '0' then
                        st <= PREP1;
                    end if;

                when PREP1 =>
                    st <= WAIT_GAP1;

                when WAIT_GAP1 =>
                    if wait_cnt = conv_std_logic_vector(0, wait_cnt'length) then
                        st <= SET_READ;
                    end if;

                when SET_READ =>
                    st <= READING;

                when READING =>
                    if waitrequest_avs_s = '0' then
                        st <= PREP2;
                    end if;

                when PREP2 =>
                    st <= WAIT_GAP2;

                when WAIT_GAP2 =>
                    st <= DONE;

                when DONE =>
                    st <= DONE;
            end case;
        end if;
    end process;

    process(nRst, CLK_80MHz_o)
    begin
        if nRst = '0' then
            wait_cnt <= (others => '0');

            write_counter <= (others => '0');
            read_counter  <= (others => '0');

            byte_enable_master_s  <= (others => '1');
            address_master_s      <= (others => '0');

            read_master_s         <= '0';
            write_master_s        <= '0';

            write_data_master_s   <= (others => '0');

            burstcount_master_s   <= (others => '0');
            burstenable_master_s  <= '0';

        elsif rising_edge(CLK_80MHz_o) then

            if st = IDLE then 
                wait_cnt <= INIT_WAIT; 
            elsif st = PREP1 or st = PREP2 then
                wait_cnt <= C_WAIT;
            else
                wait_cnt <= wait_cnt - 1;
            end if;

            if st = SET_READ or st = SET_WRITE then
                address_master_s <= conv_std_logic_vector(0, address_master_s'length);
            end if;
            
            if st = SET_READ then
                read_master_s <= '1';
            elsif waitrequest_avs_s = '0' then
                read_master_s <= '0';
            end if;

            if st = SET_WRITE then
                write_master_s <= '1';
            elsif waitrequest_avs_s = '0' then
                write_master_s <= '0';
            end if;

            if st = SET_WRITE then
                write_data_master_s <= x"1122334455667788";
            end if;

        end if;
    end process;

end architecture struct;
