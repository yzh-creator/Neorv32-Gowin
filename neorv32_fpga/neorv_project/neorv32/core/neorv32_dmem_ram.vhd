-- ================================================================================ --
-- NEORV32 SoC - Data Memory (DMEM) - RAM Primitive Wrapper                         --
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;
use work.neorv32_package.all;

entity neorv32_dmem_ram is
  generic ( AWIDTH : natural;  OUTREG : natural );
  port (
    clk_i  : in  std_ulogic;
    en_i   : in  std_ulogic_vector(3 downto 0);
    rw_i   : in  std_ulogic;
    addr_i : in  std_ulogic_vector(31 downto 0);
    data_i : in  std_ulogic_vector(31 downto 0);
    data_o : out std_ulogic_vector(31 downto 0)
  );
end entity;

architecture neorv32_dmem_ram_rtl of neorv32_dmem_ram is
begin
  ram_gen:
  for i in 0 to 3 generate
    ram_inst: entity work.neorv32_prim_spram
    generic map ( AWIDTH => AWIDTH-2, DWIDTH => 8, OUTREG => OUTREG )
    port map (
      clk_i  => clk_i,  en_i   => en_i(i),  rw_i   => rw_i,
      addr_i => addr_i(AWIDTH-1 downto 2),
      data_i => data_i(i*8+7 downto i*8),
      data_o => data_o(i*8+7 downto i*8)
    );
  end generate;
end architecture;
