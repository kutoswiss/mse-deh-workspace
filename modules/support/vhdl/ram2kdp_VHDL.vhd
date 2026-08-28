library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dualPortRam2k_VHDL is
  port (
    address1    : in  std_logic_vector(8 downto 0);
    address2    : in  std_logic_vector(8 downto 0);
    clock1      : in  std_logic;
    clock2      : in  std_logic;
    writeEnable : in  std_logic;
    dataIn1     : in  std_logic_vector(31 downto 0);
    dataOut2    : out std_logic_vector(31 downto 0)
  );
end entity dualPortRam2k_VHDL;

architecture rtl of dualPortRam2k_VHDL is

  type ram_type is array (0 to 511) of std_logic_vector(31 downto 0);
  signal memory : ram_type;

begin

  -- Port 1: synchronous write port.
  write_port : process(clock1)
  begin
    if rising_edge(clock1) then
      if writeEnable = '1' then
        memory(to_integer(unsigned(address1))) <= dataIn1;
      end if;
    end if;
  end process;

  -- Port 2: synchronous read port.
  read_port : process(clock2)
  begin
    if rising_edge(clock2) then
      dataOut2 <= memory(to_integer(unsigned(address2)));
    end if;
  end process;

end architecture rtl;
