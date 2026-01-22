library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package SDRAM_TOP_package is

  -- Avalon параметры
  constant AV_ADDR_WIDTH  : integer := 25;
  constant AV_DATA_WIDTH  : integer := 64;

  -- SDRAM
  constant SDRAM_ADDR_WIDTH : integer := 12;
  constant SDRAM_DATA_WIDTH : integer := 16;

  -- FSM состояния
  type StateFSM_type is (
    FSM_IDLE,
    FSM_INIT,
    FSM_REFRESH,
    FSM_ACTIVE,
    FSM_READ,
    FSM_WRITE,
    FSM_PRECHARGE
  );
  
  type avlmm_a24b_d64_t is record
    addr       : std_logic_vector(24 downto 0);
    rd_req     : std_logic;
    wr_req     : std_logic;
    wr_data    : std_logic_vector(63 downto 0);
    byte_en    : std_logic_vector(7 downto 0);
    burst_cnt  : std_logic_vector(3 downto 0);
    burst_en   : std_logic;
    -- Сигналы от slave к master
    rd_data    : std_logic_vector(63 downto 0);
    wait_req   : std_logic
  end record avlmm_a24b_d64_t;

end package SDRAM_TOP_package;

package body SDRAM_TOP_package is
end package body SDRAM_TOP_package;
