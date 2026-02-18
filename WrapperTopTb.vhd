library ieee;
use ieee.std_logic_1164.all;

entity WrapperTopTb is
end entity;

architecture tb of WrapperTopTb is

    -- входы
    signal nRst      : std_logic := '0';
    signal CLK_12MHz : std_logic := '0';

    -- SDRAM pins (from DUT)
    signal nCS   : std_logic;
    signal nRAS  : std_logic;
    signal nCAS  : std_logic;
    signal nWE   : std_logic;
    signal CKE   : std_logic;
    signal DQM   : std_logic_vector(1 downto 0);
    signal BS    : std_logic_vector(1 downto 0);
    signal A     : std_logic_vector(11 downto 0);
    signal Dq    : std_logic_vector(15 downto 0);

    -- debug
    signal DBG_nCS   : std_logic;
    signal DBG_nRAS  : std_logic;
    signal DBG_nCAS  : std_logic;
    signal DBG_nWE   : std_logic;

    signal DBG_read_master  : std_logic;
    signal DBG_write_master : std_logic;
    signal DBG_waitrequest_avs : std_logic;
	 
    signal DBG_RD_LOAD : std_logic;
    signal DBG_WR_SHIFT : std_logic;

    signal CLK_160MHz : std_logic;

    -- delayed signals to SDRAM model (board delays)
    signal nCS_sdram  : std_logic;
    signal nRAS_sdram : std_logic;
    signal nCAS_sdram : std_logic;
    signal nWE_sdram  : std_logic;
    signal CKE_sdram  : std_logic;
    signal DQM_sdram  : std_logic_vector(1 downto 0);
    signal BS_sdram   : std_logic_vector(1 downto 0);
    signal A_sdram    : std_logic_vector(11 downto 0);

    constant TCLK : time := 83.333 ns; -- 12 MHz

    component mt48lc4m16a2
        generic (
            addr_bits : integer := 12;
            data_bits : integer := 16;
            col_bits  : integer := 8;
            mem_sizes : integer := 1048575
        );
        port (
            Dq    : inout std_logic_vector (data_bits - 1 downto 0);
            Addr  : in    std_logic_vector (addr_bits - 1 downto 0);
            Ba    : in    std_logic_vector (1 downto 0);
            Clk   : in    std_logic;
            Cke   : in    std_logic;
            Cs_n  : in    std_logic;
            Ras_n : in    std_logic;
            Cas_n : in    std_logic;
            We_n  : in    std_logic;
            Dqm   : in    std_logic_vector (1 downto 0)
        );
    end component;

begin

    --------------------------------------------------------------------
    -- Clock generator (12 MHz)
    --------------------------------------------------------------------
    p_clk : process
    begin
        while true loop
            CLK_12MHz <= '0';
            wait for TCLK/2;
            CLK_12MHz <= '1';
            wait for TCLK/2;
        end loop;
    end process;

    --------------------------------------------------------------------
    -- Reset generator
    --------------------------------------------------------------------
    p_rst : process
    begin
        nRst <= '0';
        wait for 2 us;
        nRst <= '1';
        wait;
    end process;

    --------------------------------------------------------------------
    -- Add small delays on SDRAM pins (as in your SdramTopTb)
    --------------------------------------------------------------------
    nCS_sdram  <= nCS  after 1.2 ns;
    nRAS_sdram <= nRAS after 1.2 ns;
    nCAS_sdram <= nCAS after 1.2 ns;
    nWE_sdram  <= nWE  after 1.2 ns;
    CKE_sdram  <= CKE  after 1.2 ns;
    DQM_sdram  <= DQM  after 1.2 ns;
    BS_sdram   <= BS   after 1.2 ns;
    A_sdram    <= A    after 1.2 ns;

    --------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------
    U_DUT : entity work.WrapperTop
        port map (
            nRst      => nRst,
            CLK_12MHz => CLK_12MHz,

            nCS  => nCS,
            nRAS => nRAS,
            nCAS => nCAS,
            nWE  => nWE,
            CKE  => CKE,
            DQM  => DQM,
            BS   => BS,
            A    => A,
            Dq   => Dq,

            DBG_nCS  => DBG_nCS,
            DBG_nRAS => DBG_nRAS,
            DBG_nCAS => DBG_nCAS,
            DBG_nWE  => DBG_nWE,

            DBG_read_master  => DBG_read_master,
            DBG_write_master => DBG_write_master,
				DBG_waitrequest_avs => DBG_waitrequest_avs,
            CLK_160MHz => CLK_160MHz,
            DBG_RD_LOAD    => DBG_RD_LOAD,
            DBG_WR_SHIFT   => DBG_WR_SHIFT
        );

    --------------------------------------------------------------------
    -- SDRAM model
    --------------------------------------------------------------------
    U_SDRAM : mt48lc4m16a2
        port map (
            Dq    => Dq,
            Addr  => A_sdram,
            Ba    => BS_sdram,
            Clk   => CLK_160MHz,
            Cke   => CKE_sdram,
            Cs_n  => nCS_sdram,
            Ras_n => nRAS_sdram,
            Cas_n => nCAS_sdram,
            We_n  => nWE_sdram,
            Dqm   => DQM_sdram
        );

end architecture;
