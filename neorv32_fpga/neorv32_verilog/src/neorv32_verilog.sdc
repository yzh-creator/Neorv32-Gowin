//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12.02_SP2 (64-bit)
create_clock -name clk_50m -period 10 -waveform {0 5} [get_ports {clk_50m}] -add
