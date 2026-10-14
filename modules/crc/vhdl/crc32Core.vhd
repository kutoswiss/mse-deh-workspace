-- HEPIA CoRES. Same algorithm and port interface as the course CRC core.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity crc32Core is
  port (
    clock, reset : in std_logic;
    restart      : in std_logic;
    dataValid    : in std_logic;
    dataIn       : in std_logic_vector(31 downto 0);
    crcOut       : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of crc32Core is
  constant INITIAL : unsigned(31 downto 0) := x"FFFFFFFF";
  constant POLY    : unsigned(31 downto 0) := x"EDB88320";
  signal crcReg   : unsigned(31 downto 0);

  function updateWord(current : unsigned(31 downto 0);
                      word : std_logic_vector(31 downto 0))
                      return unsigned is
    variable crc : unsigned(31 downto 0);
  begin
    crc := current;
    for byteIndex in 0 to 3 loop
      -- Lowest byte first; then lowest bit first within each byte.
      crc(7 downto 0) := crc(7 downto 0) xor
                        unsigned(word(8*byteIndex+7 downto 8*byteIndex));
      for bitIndex in 0 to 7 loop
        if crc(0) = '1' then
          crc := shift_right(crc, 1) xor POLY;
        else
          crc := shift_right(crc, 1);
        end if;
      end loop;
    end loop;
    return crc;
  end function;
begin
  -- Only the output is finalized; crcReg remains ready for the next word.
  crcOut <= std_logic_vector(crcReg xor INITIAL);
  process(clock)
  begin
    if rising_edge(clock) then
      if reset = '1' or restart = '1' then
        crcReg <= INITIAL;
      elsif dataValid = '1' then
        crcReg <= updateWord(crcReg, dataIn);
      end if;
    end if;
  end process;
end architecture;
