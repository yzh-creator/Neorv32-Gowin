//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12.02_SP2 (64-bit) 
//Created Time: 2026-07-23 11:32:01
create_clock -name clk_i -period 20 -waveform {0 10} [get_ports {clk_i}] -add
