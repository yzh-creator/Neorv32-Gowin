// ================================================================================ //
// NEORV32 GW2A-18C 顶层 (BOOT_MODE=2)
// ================================================================================ //
// 用户编辑此文件: 接线 / 引脚 / 外设连接                                          //
// 修改后: Gowin EDA 重新综合即可 (核心网表 neorv32_verilog_wrapper.v 不变)         //
// ================================================================================ //

module top (
  input  clk_50m,          // 50 MHz 时钟
  input  rstn,             // 复位, 低有效
  output [7:0] led,        // LED[7:0]
  output uart_txd,         // UART TX
  input  uart_rxd          // UART RX
);

  // ---- 核心连接信号 ----
  wire [31:0] gpio_out;    // GPIO 输出
  wire [31:0] gpio_in  = 32'h0;  // GPIO 输入 (未用, 接 0)

  // ---- NEORV32 核心 (GHDL 生成的固化网表) ----
  neorv32_verilog_wrapper u_core (
    .clk_i       (clk_50m),
    .rstn_i      (rstn),
    .gpio_o      (gpio_out),
    .gpio_i      (gpio_in),
    .uart0_txd_o (uart_txd),
    .uart0_rxd_i (uart_rxd)
  );

  // ---- LED: GPIO 低 8 位 ----
  assign led = gpio_out[7:0];

endmodule
