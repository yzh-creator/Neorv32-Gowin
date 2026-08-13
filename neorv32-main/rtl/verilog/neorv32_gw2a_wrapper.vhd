-- ================================================================================ --
-- NEORV32 GW2A Verilog Wrapper (BOOT_MODE=2, GPIO LED)                              --
-- -------------------------------------------------------------------------------- --
-- GHDL 转换用 wrapper：BOOT_MODE=2 从 IMEM 直启, 50MHz, GPIO[7:0] 输出 LED           --
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_gw2a_wrapper is
  port (
    -- Global control --
    clk_i       : in  std_ulogic;                -- 50 MHz
    rstn_i      : in  std_ulogic;                -- reset, low-active, async
    -- GPIO LED --
    gpio_o      : out std_ulogic_vector(7 downto 0); -- LED[7:0]
    -- UART0 --
    uart0_txd_o : out std_ulogic;
    uart0_rxd_i : in  std_ulogic
  );
end entity;

architecture neorv32_gw2a_wrapper_rtl of neorv32_gw2a_wrapper is

  signal gpio_out : std_ulogic_vector(31 downto 0);
  signal gpio_in  : std_ulogic_vector(31 downto 0) := (others => '0');

begin

  neorv32_top_inst: neorv32_top
  generic map (
    CLOCK_FREQUENCY     => 50_000_000,   -- 50 MHz
    BOOT_MODE_SELECT    => 2,            -- boot from pre-initialized IMEM
    RISCV_ISA_C         => false,        -- no compressed extension
    RISCV_ISA_M         => true,         -- mul/div
    RISCV_ISA_Zicntr    => true,         -- cycle/instret counters
    IMEM_EN             => true,
    IMEM_SIZE           => 32*1024,
    DMEM_EN             => true,
    DMEM_SIZE           => 8*1024,
    IO_GPIO_NUM         => 8,            -- 8-bit GPIO for LED
    IO_UART0_EN         => true,
    IO_UART0_RX_FIFO    => 4,
    IO_UART0_TX_FIFO    => 4,
    IO_CLINT_EN         => true          -- timer
  )
  port map (
    clk_i        => clk_i,
    rstn_i       => rstn_i,
    gpio_o       => gpio_out,
    gpio_i       => gpio_in,
    gpio_dir_o   => open,
    uart0_txd_o  => uart0_txd_o,
    uart0_rxd_i  => uart0_rxd_i
  );

  -- LED output: GPIO[7:0]
  gpio_o <= gpio_out(7 downto 0);

end architecture;
