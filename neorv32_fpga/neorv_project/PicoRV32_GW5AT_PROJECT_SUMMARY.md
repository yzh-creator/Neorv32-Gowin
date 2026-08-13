# PicoRV32 移植 Gowin GW5AT 工程总结

> 芯片: GW5AT-LV60PG484AC1/I0  |  工具: xPack GCC 15.2.0 + Gowin EDA V1.9.12

---

## 一、工程概览

### 已实现功能 ✅

| 功能 | 状态 | 说明 |
|------|------|------|
| GPIO 输出控制 | ✅ | 7 位 GPIO 驱动 LED |
| UART 串口 (115200) | ✅ | simpleuart + 打印函数 |
| 硬件乘法 (MUL) | ✅ | 32×32=64 位 |
| 硬件除法 (DIV/REM) | ✅ | 32÷32 商+余 |
| 高位乘法 (MULH/MULHU) | ✅ | 有/无符号 |
| 周期/指令计数器 | ✅ | RDCYCLE/RDTIME/RDINSTRET |
| 字节/半字访存 | ✅ | LB/SB/LH/SH |
| C 语言全链路 | ✅ | C → 编译 → BRAM → FPGA |
| 外部中断 | ⚠️ 仅 IRQ 3-31 | 可通过 irq 输入触发 |
| 定时器中断 | ❌ | timer 硬件不计数 |

### 不可用功能 ❌

| 功能 | 原因 |
|------|------|
| 压缩指令 (RV32C) | GowinSynthesis 综合后 C.BNEZ 分支异常 |
| 定时器中断 | timer 在 TWO_CYCLE_ALU 下不计数 |
| retirq 返回 | TWO_CYCLE_ALU 下流水线冲突 |
| EBREAK 中断 | PicoRV32 实现问题 |

---

## 二、解决问题清单

### 2.1 Verilog 语法与综合

#### [E1] `{24'h0, leds}` 常量拼接

- **错误**: `EX3820 : constant is not allowed here`
- **原因**: GowinSynthesis 不允许在模块端口连接中使用常量拼接表达式
- **修复**: 改用中间线网 `wire [31:0] gpio_out_full;` + 外部 `assign`

#### [E2] `.name` 隐式端口连接

- **错误**: `EX3615 : .name implicit port connection not allowed`
- **原因**: Gowin 不支持 Verilog-2001 的 `.name(name)` 缩写语法
- **修复**: 全部改为 `.name(signal)` 显式连接

#### [E3] `reg/wire` 声明冲突

- **错误**: `mem_ready` 同时声明为 `reg` 和用 `assign` 驱动
- **原因**: 混合使用 `reg` 声明和 `assign` 连续赋值
- **修复**: 统一为 `wire mem_ready; assign mem_ready = ...`

### 2.2 BRAM 初始化

#### [E4] `$readmemh` 被忽略

- **原因**: GowinSynthesis 不支持在 `initial` 块中用 `$readmemh` 初始化 BRAM
- **修复 1**: `(* ram_init_file = "firmware.hex" *)` 属性——测试无效
- **修复 2**: `initial` 块硬编码 `bram[N] = 32'hxxxxxx;`——**仅对分布式 RAM 有效**
- **修复 3**: Gowin IP Generator 生成 SP BRAM + `.mi` 文件——最终方案

#### [E5] BRAM WRITE_MODE=2'b10

- **错误**: `PA2122 : Not support WRITE_MODE = 2'b10`
- **原因**: Verilog 中无条件 `rdata <= mem[addr]` 使 Gowin 推断 NO_CHANGE 模式
- **修复**: 改为 if/else 风格的 WRITE_FIRST：
  ```verilog
  if (wen) begin
      mem[addr] <= wdata;  rdata <= wdata;
  end else begin
      rdata <= mem[addr];
  end
  ```

#### [E6] 分布式 RAM 容量上限

- **结论**: Gowin 分布式 RAM 的 `initial` 块支持约 256 字 (1KB)
- **超出时**: Gowin 自动切换为块 RAM，`initial` 初始化失效
- **方案**: 小固件用分布式 RAM（≤256字），大固件用 IP Generator

### 2.3 外设时序

#### [E7] GPIO/mem_ready 组合逻辑

- **症状**: CPU 写 GPIO 不生效，LED 全灭
- **原因**: GPIO 的 ready 信号用组合逻辑直接返回，`gpio_sel && !mem_ready` 永假
- **修复**: 所有外设 ready 信号寄存器化：
  ```verilog
  reg gpio_ready;
  always @(posedge clk) gpio_ready <= gpio_sel && !mem_ready;
  assign mem_ready = bram_ready | gpio_ready | ...;
  ```

### 2.4 固件编译

#### [E8] `objcopy` 截断

- **症状**: 固件执行失败，LED 卡在初始值
- **原因**: `objcopy -O binary` 按 4 字节对齐输出，丢弃末尾不足 4 字节的部分
- **修复**: 汇编文件末尾加 `.balign 4`

#### [E9] 链接脚本 `//` 注释

- **错误**: `syntax error`（GNU LD 不识别 `//`）
- **修复**: 改为 `/* */` 注释

### 2.5 CPU 配置

#### [E10] 压缩指令 C.BNEZ 不良

- **症状**: 含 `bnez` 延迟循环的固件卡死
- **原因**: GowinSynthesis 综合 PicoRV32 后，压缩条件分支 `C.BNEZ` 行为异常
- **修复**:
  ```verilog
  .COMPRESSED_ISA(0)          // RTL
  -march=rv32i                 // 固件编译
  ```

#### [E11] 自定义指令编码错误

- **症状**: timer/maskirq/retirq 指令无响应
- **原因**: `picorv32-main/firmware/custom_ops.S` 的 funct7 编码与 picorv32.v 硬件不匹配
- **正确编码**:

| 指令 | funct7 | opcode | Verilog 常量 |
|------|--------|--------|-------------|
| timer | 0x05 | 0x0001011 | `0x0A00000B` |
| maskirq | 0x03 | 0x0001011 | `0x0600000B` |
| retirq | 0x02 | 0x0001011 | `0x0400000B` |

#### [E12] `ENABLE_IRQ=1` 时序不收敛

- **症状**: CPU 完全不启动
- **原因**: IRQ 逻辑增大关键路径，50MHz 时序不收敛
- **修复**: `TWO_CYCLE_ALU(1)`, `TWO_CYCLE_COMPARE(1)`

#### [E13] TWO_CYCLE_ALU 下流水线延迟

- **症状**: `lui` 后立即使用寄存器 → 读到旧值；`li` 后立即 timer → 设置错误值
- **原因**: TWO_CYCLE_ALU 增加一级流水线，寄存器结果滞后一个周期
- **修复**: 关键操作间加 NOP（具体位置见附录）

#### [E14] `maskirq` 语义误解

- **症状**: `maskirq(~0)` 后中断不触发
- **原因**: PicoRV32 的 mask 是 1=屏蔽，0=启用。`~0`=全屏蔽
- **修复**: `maskirq(0)` = 全启用

#### [E15] GPIO 读返回 0

- **症状**: ISR 中 `lw` 读 GPIO 始终为 0
- **原因**: 顶层读通路未处理 GPIO 读请求
- **修复**: 在 mem_rdata mux 中先于 gpio_ready 判断 gpio_sel + 读条件

### 2.6 IRQ 指令分析

#### retirq 执行路径（已确认）

```
decode:    mem_rdata_latched → instr_retirq (line 871)
ld_rs1:    default case → alu_wait=1 (line 1745)   ← 问题点
exec:      alu_wait=1 → 跳过 retirq case (line 1807)
exec+1:    alu_wait=0 → retirq case 执行 (line 1667)
```

**结论**: retirq 的延迟执行可通过修 RTL 规避，但 timer 不计数问题（使 timer 中断不可用）无解——社区最新版无相关修复。

---

## 三、最终方案

### 无中断的稳定版

```verilog
.COMPRESSED_ISA(0), .ENABLE_MUL(1), .ENABLE_DIV(1), .ENABLE_COUNTERS(1)
// ENABLE_IRQ=0 (default)
```

| 容量 | 编译 | 工具链 |
|------|------|--------|
| 分布式 RAM ≤256 字 | `-march=rv32i` | xPack riscv-none-elf-gcc |

### 含中断的方案

| 方案 | 说明 |
|------|------|
| **NEORV32** | 标准 RISC-V 中断，~2300 LUTs，Gowin 已有社区验证 |
| **Gowin IP** | `Gowin_PicoRV32_Top`（加密 IP，中断可用） |

---

## 四、工具链使用

### 一键脚本

| 文件 | 功能 |
|------|------|
| `build_fw.bat` | 双击编译固件 → 生成 `bram_init.txt` |
| `update_top.ps1` | 双击更新 `picorv32_fpga_top.v` |

### 开发流程

```
编辑 hello.c → 双击 build_fw.bat → 双击 update_top.ps1 → Gowin EDA 综合
```

---

## 五、附录：TWO_CYCLE_ALU 下 NOP 位置

所有需 NOP 的 `lui→lw` 和 `li→custom` 序列：

```asm
// lui → lw (寄存器地址)
lui t0, 0x03000
.nop; .nop; .nop       // 等 lui 结果
lw  t1, 0(t0)

// li → timer 指令
li  t1, 0x100000
.nop; .nop; .nop       // 等 li 结果
timer_insn(0, t1)

// li → maskirq 指令
li  a0, 0
.nop; .nop; .nop
maskirq_insn(0, a0)

// lw → xori → sw
lw  t1, 0(t0)
.nop; .nop              // 等 lw 结果
xori t1, t1, 4
.nop; .nop; .nop        // 等 xori 结果
sw  t1, 0(t0)
```
