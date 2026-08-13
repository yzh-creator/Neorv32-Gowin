// ==============================================================================
// Gowin SP BRAM — byte-wide Verilog wrapper (READ_BEFORE_WRITE)
// ==============================================================================
// GowinSynthesis auto-maps to hardware BSRAM. Same pattern as PicoRV32 GW5AT.
// READ_BEFORE_WRITE is the most compatible mode across all Gowin device families.
// ==============================================================================

module gowin_sp_byte (
  output reg [7:0] DO,
  input  [7:0] DI,
  input  [13:0] AD,
  input  WRE,
  input  CE,
  input  CLK,
  input  RESET
);

  reg [7:0] mem [0:4095];

  always @(posedge CLK) begin
    if (CE) begin
      if (WRE) begin
        mem[AD] <= DI;
        DO      <= DI;          // WRITE_FIRST → Gowin 2'b01 ✅
      end else begin
        DO      <= mem[AD];
      end
    end
  end

endmodule
