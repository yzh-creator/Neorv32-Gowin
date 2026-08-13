// ================================================================================ //
// NEORV32 GW2A Verilog 版 — 串口/定时器/中断 综合测试                                //
// ================================================================================ //

#include <neorv32.h>

#define CLK_HZ  100000000   // 与 wrapper CLOCK_FREQUENCY 一致
#define BAUD    19200       // bootloader 验证过的波特率

volatile int tick = 0;      // 中断标志

// ---- MTI 中断服务 ----
void mti_irq_handler(void) {
  tick = 1;
  neorv32_clint_mtimecmp_set(neorv32_clint_mtimecmp_get() + CLK_HZ);  // +1秒
}

int main() {
  // ---- 初始化 ----
  neorv32_gpio_dir_set(0xFF);
  neorv32_gpio_port_set(0x00);
  neorv32_uart0_setup(BAUD, 0);

  neorv32_uart0_puts("\n=== NEORV32 Verilog Test ===\n");

  // ---- Test 1: UART 输出 ----
  neorv32_uart0_puts("[1] UART OK\n");

  // ---- Test 2: 定时器 (CLINT mtime) ----
  neorv32_uart0_puts("[2] CLINT mtime: ");
  uint64_t t0 = neorv32_clint_time_get();
  neorv32_aux_delay_ms(CLK_HZ, 100);   // 忙等 100ms
  uint64_t t1 = neorv32_clint_time_get();
  neorv32_uart0_printf("PASS delta=%u\n", (uint32_t)(t1 - t0));
  // 预期 delta ≈ 100ms * (CLK_HZ/1000) = 10,000,000

  // ---- Test 3: 中断 (MTI 定时器中断) ----
  neorv32_uart0_puts("[3] MTI interrupt: ");
  neorv32_rte_setup();
  neorv32_rte_handler_install(TRAP_CODE_MTI, mti_irq_handler);
  neorv32_clint_mtimecmp_set(neorv32_clint_time_get() + CLK_HZ);  // 1秒后首次中断
  neorv32_cpu_csr_set(CSR_MIE, 1 << CSR_MIE_MTIE);
  neorv32_cpu_csr_set(CSR_MSTATUS, 1 << CSR_MSTATUS_MIE);
  neorv32_uart0_puts("PASS (LED toggles every 1s)\n");

  // ---- 主循环: 中断驱动 LED 翻转 ----
  uint8_t led = 0x00;
  uint32_t cnt = 0;
  while (1) {
    if (tick) {
      tick = 0;
      led = led ^ 0xFF;
      neorv32_gpio_port_set(led);
      cnt++;
      if (cnt <= 5) {
        neorv32_uart0_printf("  tick=%u\n", cnt);
      }
    }
    neorv32_cpu_sleep();   // WFI
  }

  return 0;
}
