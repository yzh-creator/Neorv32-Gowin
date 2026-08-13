# Neorv32-Gowin

**NEORV32 RISC-V 软核 SoC 在国产 Gowin FPGA 上的移植与基准测试工程**

将开源 [NEORV32](https://github.com/stnolting/neorv32) RISC-V 处理器移植到 Gowin FPGA(GW2A-18),通过内部 bootloader 经 UART 上传固件运行,并完成 **CoreMark® 基准测试**与**性能调优**。

- 目标芯片:GW2A-LV18PG256C8/I7(GW2A-18)
- 综合工具:Gowin EDA V1.9.12
- 交叉编译:xPack RISC-V GCC 15.2.0
- 最终成绩:**48 CoreMark @50 MHz(0.96 CM/MHz,追平官方参考配置)**

---

## 1. 这个工程是做什么的

1. **移植**:把 NEORV32 SoC(RTL VHDL 源码)移植到 Gowin FPGA,解决 Gowin EDA 的 VHDL 库名限制(`library neorv32` → `library work`)、BRAM 写模式(WRITE_MODE)等平台适配问题;
2. **运行**:配置为 `BOOT_MODE_SELECT=0` —— 芯片上电后从内部 bootloader 启动,通过 **UART(19200,8N1)上传 `.exe` 镜像**并自动运行;
3. **基准**:移植 EEMBC CoreMark 并跑分,逐步调优至接近软核架构上限;
4. **验证**:UART 输出、CLINT 定时器、MTI 中断、GPIO LED 的综合测试(`main.c`)。

---

## 2. 目录结构

```
D:\neorv32\                              ← 仓库根
├── neorv32-main/                        NEORV32 官方框架(上游源码,只读使用)
│   ├── rtl/core/                        SoC VHDL 源码(neorv32_top / neorv32_package / cpu / 外设)
│   ├── sw/common/                       构建系统 common.mk + crt0.S + neorv32.ld
│   ├── sw/lib/                          HAL 驱动库(neorv32.h, 27 头文件 + 25 源文件)
│   ├── sw/image_gen/                    固件→VHDL/EXE 镜像生成器 image_gen.exe + uart_upload.sh
│   └── sw/bootloader/                   UART bootloader(19200 波特率)
│
├── neorv32-coremark-main/               CoreMark 基准移植(已适配 32KB IMEM)
│   ├── makefile                         构建配置(ISA/优化/内存布局/链接选项)
│   ├── core_portme.c / core_portme.h    平台移植层(计时/串口/种子/内存)
│   ├── coremark/                        ⚠️ 子模块 → github.com/eembc/coremark(官方基准源码)
│   └── neorv32/                         ⚠️ 子模块 → github.com/stnolting/neorv32
│
├── neorv32_fpga/                        Gowin FPGA 工程
│   ├── neorv_project/                   主工程
│   │   ├── neorv_project.gprj           Gowin 工程文件
│   │   ├── neorv32/core/                NEORV32 VHDL 副本(已改库引用 + BRAM 适配)
│   │   ├── src/                         用户源码
│   │   │   ├── neorv32_gowin_top.vhd    SoC 顶层配置(性能调优参数在此)
│   │   │   ├── main.c                   测试固件(UART/CLINT/MTI 中断/LED)
│   │   │   ├── Makefile                 固件构建(引用官方 common.mk)
│   │   │   ├── neorv32.cst / .sdc       管脚/时序约束
│   │   │   ├── build_fw.bat / .ps1      一键构建脚本
│   │   │   └── NEORV32_PROJECT_SUMMARY.md  移植总结文档(难点/测试记录/HAL 速查)
│   │   └── impl/                        ⚠️ 不入库:Gowin 综合/布线产物(可重新生成)
│   └── neorv32_verilog/                 备用:VHDL→Verilog 转换尝试
│
├── tools/                               ⚠️ 不入库:RISC-V 工具链(约 1.8GB)
└── .gitignore / .gitmodules             排除规则 / 子模块 URL 引用
```

> `⚠️ 不入库` 的内容按"最小备份"策略排除(`.gitignore`):工具链、`impl/` 综合产物、`build/`、`*.elf/*.bin/*_image.vhd` 等生成物。

---

## 3. 工具链内容

| 工具 | 版本/路径 | 用途 |
|---|---|---|
| **xPack RISC-V GCC** | `riscv-none-elf-gcc 15.2.0` | 交叉编译 RISC-V 固件(`-march=rv32imc_zicsr_zifencei -mabi=ilp32`) |
| **MinGW-w64** | `mingw32-make`(GNU Make 4.2.1) | 驱动官方 `common.mk` 构建 |
| **MinGW gcc**(宿主) | `gcc` | 编译 `image_gen.exe`(固件→VHDL/EXE 镜像) |
| **Gowin EDA** | V1.9.12 | 综合 → Place&Route → 下载 `.fs` 比特流 |
| **Git Bash** | `sh/sed/cp/rm` | `common.mk` 依赖的 Unix 命令 |
| **串口工具** | sscom/XCOM/PuTTY 等 | bootloader UART 上传(19200 8N1) |

**构建流程**:
```bash
# 1. 编译固件 + 生成镜像(在 neorv32_fpga/neorv_project/src/)
mingw32-make hw        # 或双击 build_fw.bat
# 产物: neorv32_exe.bin(UART 上传) / neorv32_imem_image.vhd(复制到 core/)

# 2. Gowin EDA: Synthesize → Place & Route → Download(生成 .fs)

# 3. 复位板子,串口工具 19200 8N1 → 输 'u' → 二进制发送 neorv32_exe.bin → 等 'OK' 自动运行
```

---

## 4. CoreMark 性能调优记录

**最终配置**(`neorv32_gowin_top.vhd` + `makefile`):

| 层 | 配置 |
|---|---|
| CPU | RV32IMC + M + Zicntr;`CPU_FAST_MUL_EN`、`CPU_FAST_SHIFT_EN` |
| 缓存 | I$/D$ 各 4KB(64 块 × 64B) |
| 存储 | IMEM 32KB + DMEM 8KB,全片内 BRAM,0 等待 |
| 编译 | `-O2 -mdiv -specs=nano.specs -march=rv32imc_zicsr_zifencei` |

**成绩变化**:

| 阶段 | CM/s @50MHz | 手段 |
|---|---|---|
| 基线 | 27.4 | rv32im / -Os / 无缓存 / 软件除法 |
| +27% | 34 | 快速乘除+移位 / C 扩展 / 1KB 缓存 |
| +9% | 37 | 缓存 1KB→4KB |
| **+30%** | **48** | **-O2**(替代 -Os) |
| ❌ 回退 | 47 | -flto / -fomit-frame-pointer(实测无收益) |

**结论**:0.96 CM/MHz 已达 NEORV32 在该配置下的架构上限;进一步提速需提高时钟频率(50→100MHz)。

**踩坑要点**(详见 `neorv32_fpga/neorv_project/src/NEORV32_PROJECT_SUMMARY.md`):
- newlib 完整版 `vfprintf` 会无条件链接 76KB 的 `dtoa` → 用 `-specs=nano.specs` 规避,固件 77KB→22KB;
- 固件须与 FPGA 内存匹配:镜像内容必须 < IMEM(32KB),否则 bootloader 写入越界挂死;
- 编译 ISA 须与顶层 `RISCV_ISA_C/M` 一致(否则非法指令)。

---

## 5. 克隆与子模块

```bash
git clone --recurse-submodules https://github.com/yzh-creator/Neorv32-Gowin.git
# 或:git clone ... && git submodule update --init
```

子模块(仅记录 commit 引用,内容从上游拉取):
- `neorv32-coremark-main/coremark` → https://github.com/eembc/coremark.git
- `neorv32-coremark-main/neorv32` → https://github.com/stnolting/neorv32.git

> `neorv32-main/` 与 `neorv32_fpga/neorv_project/neorv32/` 为普通目录(内容已入库),克隆后即可用,无需网络。

---

## 6. 许可

- 本工程适配代码:Apache-2.0 / BSD-3-Clause(遵循上游)
- NEORV32:BSD-3-Clause;CoreMark:Apache-2.0
