# ==============================================================================
# NEORV32 GW5AT-60B Application Makefile
# ==============================================================================

# ---- RISC-V ISA (must match neorv32_gowin_top.vhd generics!) ----
MARCH  = rv32im_zicsr_zifencei
MABI   = ilp32
EFFORT = -Os

# ---- Memory sizes (must match neorv32_gowin_top.vhd generics!) ----
USER_FLAGS += -Wl,--defsym,__neorv32_rom_size=32k
USER_FLAGS += -Wl,--defsym,__neorv32_ram_size=8k

# ---- NEORV32 root directory ----
NEORV32_HOME ?= ../../../neorv32-main

# ---- Core VHDL directory ----
CORE_DIR = ../neorv32/core

# ---- image_gen path (pre-compiled for Windows) ----
IMAGE_GEN = $(NEORV32_HOME)/sw/image_gen/image_gen.exe

# ---- Include NEORV32 common build system ----
include $(NEORV32_HOME)/sw/common/common.mk

# ==============================================================================
# Convenience targets
# ==============================================================================

# One-shot: compile + generate VHD + copy to core dir
hw: image
	@echo ">>> Copying IMEM image to RTL core directory..."
	copy /y "$(APP_VHD)" "$(subst /,\,$(CORE_DIR))\neorv32_imem_image.vhd"
	@echo ">>> Done! Now re-run Synthesize in Gowin EDA."
