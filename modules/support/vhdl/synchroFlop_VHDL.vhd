library ieee;
use ieee.std_logic_1164.all;

entity synchroFlop_VHDL is
  port (
    clockIn  : in  std_logic;
    clockOut : in  std_logic;
    reset    : in  std_logic;
    D        : in  std_logic;
    Q        : out std_logic
  );
end entity synchroFlop_VHDL;

architecture rtl of synchroFlop_VHDL is
  signal s_states : std_logic_vector(2 downto 0);
  signal s_d      : std_logic_vector(2 downto 0);
  signal s_reset0 : std_logic;
begin

  -- Exact equivalent of:
  -- {s_states[1:0], {s_states[0] | D}}
  s_d <= s_states(1 downto 0) & (s_states(0) or D);

  s_reset0 <= reset or s_states(1);

  Q <= s_states(2);

  -- Input-clock-domain event latch.
  input_domain : process(clockIn, s_reset0)
  begin
    if s_reset0 = '1' then
      s_states(0) <= '0';
    elsif rising_edge(clockIn) then
      s_states(0) <= s_d(0);
    end if;
  end process;

  -- Output-clock-domain synchronizer.
  output_domain : process(clockOut, reset)
  begin
    if reset = '1' then
      s_states(2 downto 1) <= "00";
    elsif rising_edge(clockOut) then
      s_states(2 downto 1) <= s_d(2 downto 1);
    end if;
  end process;

end architecture rtl;
