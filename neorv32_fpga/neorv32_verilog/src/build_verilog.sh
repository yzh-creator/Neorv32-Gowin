#!/bin/bash
# ==============================================================================
# NEORV32 Verilog 一键构建脚本
# 1. 编译固件 (neorv_project 工具链)
# 2. 复制 IMEM 镜像到 GHDL 源目录
# 3. GHDL 转换 wrapper -> Verilog
# 4. 复制生成文件到工程
# ==============================================================================
set -e

GHDL=/d/neorv32/tools/ghdl/bin/ghdl.exe
NEORV32_HOME=/d/neorv32/neorv32-main
VERILOG_DIR=$NEORV32_HOME/rtl/verilog
PROJ_SRC=/d/neorv32/neorv32_fpga/neorv32_verilog/src
FW_DIR=/d/neorv32/neorv32_fpga/neorv_project/src

echo "=== [1/4] Compile firmware ==="
cd "$FW_DIR"
export PATH="/e/Download/xpack-riscv-none-elf-gcc-15.2.0-1/bin:/e/mingw64/bin:$PATH"
rm -rf build
mingw32-make hw 2>&1 | grep -E "text|Error|error" || true
cp "$FW_DIR/neorv32_imem_image.vhd" "$NEORV32_HOME/rtl/core/neorv32_imem_image.vhd"
echo "      IMEM image: $(grep image_size_c $NEORV32_HOME/rtl/core/neorv32_imem_image.vhd)"

echo "=== [2/4] GHDL import ==="
cd "$VERILOG_DIR"
rm -rf build && mkdir -p build
sed 's|\$NEORV32_HOME|../..|g' "$NEORV32_HOME/rtl/file_list_soc.f" > build_srcs.txt
"$GHDL" -i --std=08 --work=neorv32 --workdir=build $(cat build_srcs.txt) neorv32_verilog_wrapper.vhd
echo "      import OK"

echo "=== [3/4] GHDL elaborate + synth ==="
"$GHDL" -m --std=08 --work=neorv32 --workdir=build neorv32_verilog_wrapper
"$GHDL" synth --std=08 --work=neorv32 --workdir=build --out=verilog neorv32_verilog_wrapper > "$PROJ_SRC/neorv32_verilog_wrapper.v"
echo "      lines: $(wc -l < $PROJ_SRC/neorv32_verilog_wrapper.v)"

echo "=== [4/4] Verify top ports ==="
awk '/^module neorv32_verilog_wrapper$/{found=1} found{print; if(/\);/) exit}' "$PROJ_SRC/neorv32_verilog_wrapper.v" | head -12

echo ""
echo "DONE! Next: Gowin EDA -> Synthesize"
echo "  NOTE: After synthesize, patch WRITE_MODE0=2'b10 -> 2'b00 in .vg"
