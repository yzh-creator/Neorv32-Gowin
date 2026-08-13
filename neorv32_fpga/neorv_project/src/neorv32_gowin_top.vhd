-- ================================================================================ --
-- NEORV32 GW5AT-60B 顶层Wrapper                                                     --
-- -------------------------------------------------------------------------------- --
-- 芯片: GW5AT-LV60PG484AC1/I0  (GW5AT-60B)                                         --
-- 工具: Gowin EDA V1.9.12                                                           --
-- -------------------------------------------------------------------------------- --
-- 【重要】VHDL 库配置说明                                                            --
-- NEORV32 所有 core 文件内部使用了 `library neorv32;`                                --
-- 在 Gowin EDA 中需要创建一个名为 neorv32 的 VHDL 库                                 --
--   GUI: Project → Settings → VHDL Library → Add → "neorv32"                        --
--   然后将所有 neorv32/core/*.vhd 文件分配到 neorv32 库                               --
--                                                                                   --
-- 如果 Gowin EDA 不支持自定义库，需要批量修改所有 neorv32 源文件：                      --
--   1. 将 library neorv32;  改为  library work;                                      --
--   2. 将 use neorv32.xxx;  改为  use work.xxx;                                      --
--   3. 将 entity neorv32.xxx 改为 entity work.xxx（如果有）                            --
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.neorv32_package.all;

entity neorv32_gowin_top is
  port (
    -- 全局控制 --
    clk_i       : in  std_ulogic;       -- 50MHz 输入时钟
    rstn_i      : in  std_ulogic;       -- 复位，低有效（异步）

    -- UART0 --
    uart0_txd_o : out std_ulogic;       -- UART0 串行发送
    uart0_rxd_i : in  std_ulogic;       -- UART0 串行接收

    -- LED 输出（GPIO[7:0]）--
    led_o       : out std_ulogic_vector(7 downto 0)   -- 8位LED
  );
end entity;

architecture rtl of neorv32_gowin_top is

  -- GPIO 32位中间信号（避免在端口映射中使用切片表达式）
  signal gpio_out : std_ulogic_vector(31 downto 0);
  signal gpio_in  : std_ulogic_vector(31 downto 0) := (others => '0');

begin

  -- =============================================================================== --
  -- NEORV32 SoC 实例化（最小化配置）                                                    --
  -- =============================================================================== --
  neorv32_inst: neorv32_top
  generic map (
    -- 时钟频率 --
    CLOCK_FREQUENCY => 50_000_000,       -- 50 MHz

    -- 启动配置: BOOT_MODE_SELECT = 0 通过内部 bootloader 启动（UART 上传程序） --
    BOOT_MODE_SELECT => 0,

    -- RISC-V CPU 扩展 --
    RISCV_ISA_C      => true,           -- 禁用压缩指令（参考 PicoRV32 经验，避免 Gowin 综合问题；稳定后可启用）
    RISCV_ISA_M      => true,            -- 硬件乘除法
    RISCV_ISA_Zicntr => true,            -- 基础计数器（cycle + instret）


    -- 内部存储器 --
    IMEM_EN          => true,
    IMEM_SIZE        => 32 * 1024,       -- 16KB (VHDL常量数组，占1块pROM)
    DMEM_EN          => true,
    DMEM_SIZE        => 8 * 1024,

    -- 外设配置 --
    IO_GPIO_NUM      => 8,                -- 8 位 GPIO（仅点灯，不需要UART）
    IO_UART0_EN      => true,
    IO_UART0_RX_FIFO => 4,
    IO_UART0_TX_FIFO => 4,
    IO_CLINT_EN      => true
    -- 其余 generics 使用默认值（全部禁用）--
  )
  port map (
    -- 全局控制 --
    clk_i        => clk_i,
    rstn_i       => rstn_i,

    -- 未连接输出（使用 open）--
    rstn_ocd_o   => open,
    rstn_wdt_o   => open,

    -- GPIO --
    gpio_o       => gpio_out,
    gpio_i       => gpio_in,
    gpio_dir_o   => open,               -- 不使用方向控制

    -- UART0 --
    uart0_txd_o  => uart0_txd_o,
    uart0_rxd_i  => uart0_rxd_i,
    uart0_rtsn_o => open,               -- 不使用硬件流控
    uart0_ctsn_i => 'L'

    -- 其余端口使用 entity 声明的默认值（'L'），无需显式列出 --
  );

  -- =============================================================================== --
  -- LED 输出：GPIO 低 8 位驱动 LED                                                      --
  -- =============================================================================== --
  led_o <= gpio_out(7 downto 0);

end architecture;
