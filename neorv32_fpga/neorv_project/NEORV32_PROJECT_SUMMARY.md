# NEORV32 移植到 Gowin FPGA 项目总结

> 项目：将 NEORV32 RISC-V SoC 移植到 Gowin FPGA
> 芯片：GW5AT-60B (GW5AT-LV60PG484AC1/I0) → 后切换 GW2A 系列
> 工具：Gowin EDA V1.9.12 / xPack RISC-V GCC 15.2.0 / MinGW-w64
> 日期：2026-07

---

## 1. 整体架构

### 1.1 NEORV32 项目结构

```
neorv32-main/
├── rtl/core/          56个VHDL源文件（CPU + SoC）
│   ├── neorv32_top.vhd        顶层SoC实体（~90 generics, ~55 ports）
│   ├── neorv32_package.vhd    包定义（地址映射、常量、类型）
│   ├── neorv32_cpu*.vhd       CPU核心（20个文件）
│   ├── neorv32_prim.vhd       基础原语（spram/dpram/fifo）
│   └── ...                    外设（uart/gpio/clint/spi...）
├── sw/
│   ├── common/                common.mk + crt0.S + neorv32.ld
│   ├── lib/                   设备驱动库（27头文件+25源文件）
│   ├── example/               25个官方示例
│   └── image_gen/             固件→VHDL镜像生成器
└── docs/                      datasheet + userguide
```

### 1.2 工程结构

```
neorv32_fpga/neorv_project/
├── neorv_project.gprj        Gowin 工程文件
├── neorv32/core/             NEORV32 VHDL源码（已修改库引用+BRAM模式）
├── src/                      用户工程
│   ├── neorv32_gowin_top.vhd Gowin顶层wrapper
│   ├── main.c                固件
│   ├── Makefile              编译配置（引用官方common.mk）
│   ├── build_fw.bat          一键编译入口
│   └── fix_vhdl_lib.ps1      VHDL库修复脚本
└── impl/                     Gowin综合/布局布线输出
```

### 1.3 顶层配置（当前）

```vhdl
CLOCK_FREQUENCY => 50_000_000,    -- 50MHz
BOOT_MODE_SELECT => 2,            -- 从预初始化IMEM启动
RISCV_ISA_M      => true,         -- 硬件乘除
RISCV_ISA_C      => false,        -- 压缩指令（暂关）
IMEM_SIZE        => 32KB / DMEM_SIZE => 8KB
IO_GPIO_NUM      => 8,            -- LED
IO_UART0_EN      => true,         -- 串口
IO_CLINT_EN      => true          -- 定时器
```

---

## 2. 工具链流程

### 2.1 工具清单

| 工具 | 路径 | 用途 |
|------|------|------|
| xPack RISC-V GCC 15.2.0 | `E:\Download\xpack-riscv-none-elf-gcc-15.2.0-1\bin` | 交叉编译 |
| MinGW-w64 | `E:\mingw64\bin` | `mingw32-make` + 编译 `image_gen.exe` |
| Gowin EDA 1.9.12 | 系统安装 | 综合/布局布线/下载 |

### 2.2 编译流程

```
双击 build_fw.bat
  → mingw32-make hw（调用官方 common.mk）
      ├─ 编译 main.c + 25个库文件 + crt0.S（riscv-none-elf-gcc）
      ├─ 链接 neorv32.ld（-Wl,--defsym 定义 ROM/RAM 大小）
      ├─ objcopy → neorv32_raw_exe.bin
      ├─ image_gen.exe → neorv32_imem_image.vhd
      └─ 复制 VHD → neorv32/core/neorv32_imem_image.vhd
  → Gowin EDA: Synthesize → Place&Route → Download
```

### 2.3 常用 make 目标

| 目标 | 作用 |
|------|------|
| `hw` | 编译+生成VHD+复制到core（一键） |
| `elf` / `bin` / `image` | 各阶段产物 |
| `clean` | 清理（Windows下需手动 `rmdir /s /q build`） |

### 2.4 修改固件后的完整流程

```
改 main.c → build_fw.bat → Gowin Synthesize → Place&Route → Download
```

> ⚠️ 每次改固件都必须走完整流程（VHD 是综合输入的一部分），不能只点 Download。

---

## 3. 难点与解决方案

### 3.1 VHDL 库名问题（已解决）

**现象**：NEORV32 源码用 `library neorv32;`，Gowin EDA 只支持默认 `work` 库 → 编译失败。

**解决**：`fix_vhdl_lib.ps1` 批量替换 56 个文件：
```
library neorv32;  →  library work;
use neorv32.xxx   →  use work.xxx
entity neorv32.xxx → entity work.xxx
```

### 3.2 bat 文件编码崩溃（已解决）

**现象**：`build_fw.bat` 用 UTF-8 保存，CMD 按 GBK 解析中文注释 → 命令行破碎乱码。

**解决**：bat 文件纯 ASCII；复杂逻辑用 PowerShell 脚本（原生 UTF-8）。

### 3.3 BRAM WRITE_MODE 问题（关键，依芯片而异）

**现象**：Gowin 报 `PA2122: Not support WRITE_MODE = 2'b10`（NO_CHANGE 模式）。

**结论**（实测）：
- **GW5AT (Arora-V)**：物理不支持 NO_CHANGE → 需改 WRITE_FIRST
- **GW2A (Arora)**：原生支持 NO_CHANGE → 保持原始代码

**WRITE_FIRST 修改**（仅 GW5AT 需要）：
```vhdl
-- neorv32_prim.vhd memory_core
if (rw_i = '1') then
    spram(addr) <= data_i;
    rdata <= data_i;     -- WRITE_FIRST: 写时返回写数据
else
    rdata <= spram(addr);
end if;
```

**安全性**：NEORV32 总线保证读写互斥（写周期不采样 rdata），WRITE_FIRST/NO_CHANGE 功能等价。寄存器文件同理可用 READ_FIRST。

### 3.4 DFF 超限（RP0001）（已解决）

**现象**：`DFF exceeds resource limit` — Gowin 未把内存推断为 BSRAM，全部用寄存器（DFF）实现。

**原因**：VHDL 泛型内存综合成 BRAM 的推断依赖工具识别，配置不当会退回分布式实现。

**解决**：
1. 缩小内存到 BSRAM 单块容量内（临时）
2. **最终**：确认 GW2A 支持 NO_CHANGE 后，原始代码 + 原配置即可正常推断 BSRAM，LUT/DFF 大降

### 3.5 PowerShell byte 位移溢出（已修复）

**现象**：生成的 VHD 中所有指令高 24 位为 0，固件全是 NOP，LED 不工作。

**原因**：`[byte] 变量 -shl 24` 溢出截断。

**修复**：
```powershell
$b0 = [int]$bytes[$i]; ... $b3 = [int]$bytes[$i+3]
$word = ($b3 -shl 24) -bor ($b2 -shl 16) -bor ($b1 -shl 8) -bor $b0
```
（后已改用官方 `image_gen.exe`，彻底避开此问题）

### 3.6 GPIO 基址错误（已解决）

**现象**：硬编码 `0xFFE60000` 访问 GPIO 无效，LED 全灭。

**原因**：实际 GPIO 基址是 `0xFFFC0000`（HAL 宏 `NEORV32_GPIO_BASE`）。

**教训**：**永远用 HAL 宏，不要硬编码地址。**

### 3.7 asm("nop") 被优化掉

**现象**：手写 `for + asm("nop")` 延时在 `-Os` 下失效。

**解决**：用 `asm volatile("nop")`，或直接用 `neorv32_aux_delay_ms(clk, ms)`（读 CSR，优化不掉）。

### 3.8 编译产物未更新

**现象**：改完代码编译，产物还是旧的（make 认为无变化）。

**解决**：手动删 `build/` 目录再 make；`common.mk` 的 `clean` 目标用 `rm`，Windows 下需 `rmdir /s /q build`。

---

## 4. 测试进展与结果

| 测试 | 状态 | 方法 |
|------|------|------|
| LED 点灯（GPIO输出） | ✅ 通过 | `neorv32_gpio_dir_set(0xFF)` + `neorv32_gpio_port_set(led)` |
| UART0 串口输出 | ✅ 通过 | `neorv32_uart0_setup(115200,0)` + `neorv32_uart0_puts()` |
| CLINT 定时器 | ✅ 正常 | `neorv32_aux_delay_ms(50000000, ms)` |
| MTI 中断（GPIO+CLINT） | 🔄 测试中 | `neorv32_rte_handler_install(TRAP_CODE_MTI, ...)` |
| 压缩指令 C 扩展 | ⏳ 未测 | `RISCV_ISA_C => true` + `MARCH=rv32imc_...` |
| SPI / PWM / TRNG 等 | ⏳ 未测 | 按需启用 |

---

## 5. 常用 HAL API 速查

| 功能 | 函数 | 头文件 |
|------|------|--------|
| GPIO 方向 | `neorv32_gpio_dir_set(mask)` | neorv32_gpio.h |
| GPIO 输出 | `neorv32_gpio_port_set(val)` | neorv32_gpio.h |
| UART 初始化 | `neorv32_uart0_setup(baud, irq)` | neorv32_uart.h |
| UART 打印 | `neorv32_uart0_printf(fmt, ...)` | neorv32_uart.h |
| 延时 | `neorv32_aux_delay_ms(clk, ms)` | neorv32_aux.h |
| cycle 计数 | `neorv32_cpu_get_cycle()` | neorv32_cpu.h |
| 定时器比较 | `neorv32_clint_mtimecmp_set(v)` | neorv32_clint.h |
| 定时器时间 | `neorv32_clint_time_get()` | neorv32_clint.h |
| 中断安装 | `neorv32_rte_handler_install(TRAP_CODE_MTI, fn)` | neorv32_rte.h |
| 开中断 | `neorv32_cpu_csr_set(CSR_MIE, 1<<CSR_MIE_MTIE)` | neorv32_cpu.h |
| 睡眠 | `neorv32_cpu_sleep()` | neorv32_cpu.h |
| 异常处理 | `neorv32_rte_setup()` | neorv32_rte.h |

### 中断示例（MTI 定时中断）

```c
#include <neorv32.h>
volatile int tick = 0;

void mti_irq_handler(void) {
  tick = 1;
  neorv32_clint_mtimecmp_set(neorv32_clint_mtimecmp_get() + 50000000);
}

int main() {
  neorv32_rte_setup();
  neorv32_rte_handler_install(TRAP_CODE_MTI, mti_irq_handler);
  neorv32_clint_mtimecmp_set(neorv32_clint_time_get() + 50000000);
  neorv32_cpu_csr_set(CSR_MIE, 1 << CSR_MIE_MTIE);
  neorv32_cpu_csr_set(CSR_MSTATUS, 1 << CSR_MSTATUS_MIE);

  while (1) {
    if (tick) { tick = 0; /* 处理 */ }
    neorv32_cpu_sleep();
  }
}
```

---

## 6. 标准库使用

- **逻辑/数学/字符串**：标准库随便用（newlib 已内置）
- **printf 输出**：默认走 semihosting，需要重定向 `_write()` 才能到串口；或直接用 `neorv32_uart0_printf()`
- **外设访问**：没有标准库封装，必须用 `neorv32.h` HAL

---

## 7. 遗留问题 / 注意事项

1. **GW5AT vs GW2A 差异**：BRAM 写模式不同（见 3.3），移植时需按芯片选择
2. **clean 目标**：Windows 下 `rm` 不可用，需手动删 build 目录
3. **固件大小**：使用 `printf` 会显著增大固件（~3KB），小 ROM 下改用 `puts`
4. **C 扩展**：启用后固件体积减 25%，但需 `MARCH=rv32imc_zicsr_zifencei` 同步修改
5. **OCD/JTAG 调试**：暂未启用（需额外管脚+OpenOCD）
6. **Verilog 退路**：如果 Gowin VHDL 综合遇到死结，可用 `rtl/verilog/` 的 GHDL 转换方案
