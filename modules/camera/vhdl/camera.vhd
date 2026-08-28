library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity camera is
  generic (
    baseAddress        : std_logic_vector(31 downto 0) := x"50000060";
    clockFrequencyInHz : integer := 2000
  );
  port (
    clock  : in  std_logic;
    pclk   : in  std_logic;
    reset  : in  std_logic;
    hsync  : in  std_logic;
    vsync  : in  std_logic;
    camData : in std_logic_vector(7 downto 0);

    -- MMIO slave interface.
    slaveBeginTransactionIn : in  std_logic;
    slaveEndTransactionIn   : in  std_logic;
    slaveReadNotWriteIn     : in  std_logic;
    slaveDataValidIn        : in  std_logic;
    slaveBusyIn             : in  std_logic;
    slaveAddressDataIn      : in  std_logic_vector(31 downto 0);
    slaveByteEnablesIn      : in  std_logic_vector(3 downto 0);
    slaveBurstSizeIn        : in  std_logic_vector(7 downto 0);
    slaveAddressDataOut     : out std_logic_vector(31 downto 0);
    slaveEndTransactionOut  : out std_logic;
    slaveDataValidOut       : out std_logic;
    slaveBusErrorOut        : out std_logic;

    -- DMA master interface.
    masterRequestBus          : out std_logic;
    masterBusGrant            : in  std_logic;
    masterBusyIn              : in  std_logic;
    masterBusErrorIn          : in  std_logic;
    masterBeginTransactionOut : out std_logic;
    masterEndTransactionOut   : out std_logic;
    masterDataValidOut        : out std_logic;
    masterAddressDataOut      : out std_logic_vector(31 downto 0);
    masterByteEnablesOut      : out std_logic_vector(3 downto 0);
    masterBurstSizeOut        : out std_logic_vector(7 downto 0)
  );
end entity camera;

architecture rtl of camera is

  -- This deliberately reproduces the Verilog function. It returns the number
  -- of shifts needed to reduce VALUE to zero (rather than mathematical ceil(log2)).
  function verilog_clog2(value : integer) return integer is
    variable remaining : integer := value;
    variable result    : integer := 0;
  begin
    while remaining > 0 loop
      result    := result + 1;
      remaining := remaining / 2;
    end loop;
    return result;
  end function;

  constant KHZ_DIVIDE_VALUE : integer := clockFrequencyInHz / 1000;
  constant KHZ_NR_OF_BITS    : integer := verilog_clog2(KHZ_DIVIDE_VALUE);

  constant DMA_IDLE        : std_logic_vector(2 downto 0) := "000";
  constant DMA_REQUEST_BUS : std_logic_vector(2 downto 0) := "001";
  constant DMA_INIT_BURST  : std_logic_vector(2 downto 0) := "010";
  constant DMA_DO_BURST    : std_logic_vector(2 downto 0) := "011";
  constant DMA_END_TRANS   : std_logic_vector(2 downto 0) := "100";
  constant DMA_END_ERROR   : std_logic_vector(2 downto 0) := "101";

  constant SLAVE_IDLE : std_logic_vector(1 downto 0) := "00";
  constant SLAVE_WAIT : std_logic_vector(1 downto 0) := "01";
  constant SLAVE_END  : std_logic_vector(1 downto 0) := "10";

  component synchroFlop_VHDL is
    port (
      clockIn  : in  std_logic;
      clockOut : in  std_logic;
      reset    : in  std_logic;
      D        : in  std_logic;
      Q        : out std_logic
    );
  end component;

  component dualPortRam2k_VHDL is
    port (
      address1    : in  std_logic_vector(8 downto 0);
      address2    : in  std_logic_vector(8 downto 0);
      clock1      : in  std_logic;
      clock2      : in  std_logic;
      writeEnable : in  std_logic;
      dataIn1     : in  std_logic_vector(31 downto 0);
      dataOut2    : out std_logic_vector(31 downto 0)
    );
  end component;

  -- MMIO-controlled acquisition state.
  signal s_frame_buffer_base_reg    : std_logic_vector(31 downto 0);
  signal s_grabber_active_reg       : std_logic;
  signal s_grabber_single_shot_reg  : std_logic;
  signal s_single_shot_done_reg     : std_logic;
  signal s_grabber_running_reg      : std_logic;
  signal s_single_shot_action_reg   : std_logic_vector(1 downto 0);

  -- Camera measurements.
  signal s_khz_count_reg            : unsigned(KHZ_NR_OF_BITS-1 downto 0);
  signal s_hz_count_reg             : unsigned(9 downto 0);
  signal s_vsync_detect_reg         : std_logic_vector(1 downto 0);
  signal s_hsync_detect_reg         : std_logic_vector(1 downto 0);
  signal s_pixel_count_reg          : unsigned(10 downto 0);
  signal s_pixel_count_value_reg    : unsigned(10 downto 0);
  signal s_line_count_reg           : unsigned(10 downto 0);
  signal s_line_count_value_reg     : unsigned(10 downto 0);
  signal s_pclk_count_reg           : unsigned(16 downto 0);
  signal s_pclk_count_value_reg     : unsigned(16 downto 0);
  signal s_fps_count_reg            : unsigned(7 downto 0);
  signal s_fps_count_value_reg      : unsigned(7 downto 0);

  -- Pixel packing and line-buffer read address.
  signal s_byte3_reg                : std_logic_vector(7 downto 0);
  signal s_byte2_reg                : std_logic_vector(7 downto 0);
  signal s_byte1_reg                : std_logic_vector(7 downto 0);
  signal s_bus_select_reg           : unsigned(8 downto 0);

  -- DMA master registers.
  signal s_dma_state_reg            : std_logic_vector(2 downto 0);
  signal s_dma_state_next           : std_logic_vector(2 downto 0);
  signal s_dma_bus_address_reg      : unsigned(31 downto 0);
  signal s_dma_address_data_out_reg : std_logic_vector(31 downto 0);
  signal s_nr_words_per_line_reg    : unsigned(8 downto 0);
  signal s_burst_count_reg          : unsigned(8 downto 0);
  signal s_dma_begin_transaction_reg : std_logic;
  signal s_dma_end_transaction_reg   : std_logic;
  signal s_dma_data_valid_reg        : std_logic;
  signal s_dma_byte_enables_reg      : std_logic_vector(3 downto 0);
  signal s_dma_burst_size_reg        : unsigned(7 downto 0);

  -- MMIO slave registers.
  signal s_slave_state_reg              : std_logic_vector(1 downto 0);
  signal s_slave_state_next             : std_logic_vector(1 downto 0);
  signal s_slave_start_transaction_reg  : std_logic;
  signal s_slave_transaction_active_reg : std_logic;
  signal s_slave_read_not_write_reg      : std_logic;
  signal s_slave_data_in_valid_reg       : std_logic;
  signal s_slave_data_out_valid_reg      : std_logic;
  signal s_slave_end_transaction_reg     : std_logic;
  signal s_slave_bus_error_reg           : std_logic;
  signal s_slave_byte_enables_reg        : std_logic_vector(3 downto 0);
  signal s_slave_burst_size_reg          : std_logic_vector(7 downto 0);
  signal s_slave_bus_address_reg         : unsigned(31 downto 0);
  signal s_slave_data_in_reg             : std_logic_vector(31 downto 0);
  signal s_slave_data_out_reg            : std_logic_vector(31 downto 0);
  signal s_slave_read_value_cpu          : std_logic_vector(31 downto 0);

  signal s_slave_read_value_bus          : std_logic_vector(31 downto 0);
  signal s_slave_write_value_cpu         : std_logic_vector(31 downto 0);
  signal s_khz_count_zero                : std_logic;
  signal s_hz_count_zero                 : std_logic;
  signal s_khz_count_next                : unsigned(KHZ_NR_OF_BITS-1 downto 0);
  signal s_hz_count_next                 : unsigned(9 downto 0);
  signal s_vsync_neg_edge                : std_logic;
  signal s_hsync_neg_edge                : std_logic;
  signal s_clock_pclk_value              : std_logic;
  signal s_clock_fps                     : std_logic;
  signal s_is_my_slave_transaction       : std_logic;
  signal s_slave_address_offset          : unsigned(31 downto 0);
  signal s_slave_word_address            : unsigned(2 downto 0);
  signal s_slave_access_error             : std_logic;
  signal s_start_slave_read               : std_logic;
  signal s_reset_slave_read_data          : std_logic;
  signal s_slave_write                    : std_logic;
  signal s_write_framebuffer              : std_logic;
  signal s_write_control                  : std_logic;
  signal s_pixel_word                     : std_logic_vector(31 downto 0);
  signal s_we_line_buffer                 : std_logic;
  signal s_bus_pixel_word                 : std_logic_vector(31 downto 0);
  signal s_new_screen                     : std_logic;
  signal s_new_line                       : std_logic;
  signal s_do_write                       : std_logic;
  signal s_dma_bus_address_next           : unsigned(31 downto 0);
  signal s_burst_size_next                : unsigned(7 downto 0);

begin

  assert KHZ_DIVIDE_VALUE > 0
    report "clockFrequencyInHz must be at least 1000"
    severity failure;

  -----------------------------------------------------------------------------
  -- Timing-reference counters (system-clock domain)
  -----------------------------------------------------------------------------
  s_khz_count_zero <= '1' when s_khz_count_reg = 0 else '0';
  s_hz_count_zero  <= s_khz_count_zero when s_hz_count_reg = 0 else '0';

  s_khz_count_next <=
    to_unsigned(KHZ_DIVIDE_VALUE - 1, KHZ_NR_OF_BITS)
      when reset = '1' or s_khz_count_zero = '1' else
    s_khz_count_reg - 1;

  s_hz_count_next <=
    to_unsigned(999, 10) when reset = '1' or s_hz_count_zero = '1' else
    s_hz_count_reg - 1  when s_khz_count_zero = '1' else
    s_hz_count_reg;

  timing_reference_registers : process(clock)
  begin
    if rising_edge(clock) then
      s_khz_count_reg <= s_khz_count_next;
      s_hz_count_reg  <= s_hz_count_next;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Camera measurements (pixel-clock domain)
  -----------------------------------------------------------------------------
  s_vsync_neg_edge <= (not s_vsync_detect_reg(0)) and s_vsync_detect_reg(1);
  s_hsync_neg_edge <= (not s_hsync_detect_reg(0)) and s_hsync_detect_reg(1);

  camera_measurements : process(pclk)
  begin
    if rising_edge(pclk) then
      s_vsync_detect_reg <= s_vsync_detect_reg(0) & vsync;
      s_hsync_detect_reg <= s_hsync_detect_reg(0) & hsync;

      if s_hsync_neg_edge = '1' then
        s_pixel_count_value_reg <= s_pixel_count_reg;
        s_pixel_count_reg       <= (others => '0');
      elsif hsync = '1' then
        s_pixel_count_reg <= s_pixel_count_reg + 1;
      end if;

      if s_vsync_neg_edge = '1' then
        s_line_count_value_reg <= s_line_count_reg;
        s_line_count_reg       <= (others => '0');
      elsif s_hsync_neg_edge = '1' then
        s_line_count_reg <= s_line_count_reg + 1;
      end if;

      if reset = '1' or s_clock_pclk_value = '1' then
        s_pclk_count_reg <= (others => '0');
      else
        s_pclk_count_reg <= s_pclk_count_reg + 1;
      end if;

      if reset = '1' then
        s_pclk_count_value_reg <= (others => '0');
      elsif s_clock_pclk_value = '1' then
        s_pclk_count_value_reg <= s_pclk_count_reg;
      end if;

      if reset = '1' or s_clock_fps = '1' then
        s_fps_count_reg <= (others => '0');
      elsif s_vsync_neg_edge = '1' then
        s_fps_count_reg <= s_fps_count_reg + 1;
      end if;

      if reset = '1' then
        s_fps_count_value_reg <= (others => '0');
      elsif s_clock_fps = '1' then
        s_fps_count_value_reg <= s_fps_count_reg;
      end if;
    end if;
  end process;

  pclk_measurement_tick : synchroFlop_VHDL
    port map (clockIn => clock, clockOut => pclk, reset => reset,
              D => s_khz_count_zero, Q => s_clock_pclk_value);

  fps_measurement_tick : synchroFlop_VHDL
    port map (clockIn => clock, clockOut => pclk, reset => reset,
              D => s_hz_count_zero, Q => s_clock_fps);

  -----------------------------------------------------------------------------
  -- MMIO slave
  -----------------------------------------------------------------------------
  -- The shared OR1420 bus reverses the four byte lanes at the MMIO boundary.
  s_slave_read_value_bus <=
    s_slave_read_value_cpu(7 downto 0) &
    s_slave_read_value_cpu(15 downto 8) &
    s_slave_read_value_cpu(23 downto 16) &
    s_slave_read_value_cpu(31 downto 24);

  s_slave_write_value_cpu <=
    s_slave_data_in_reg(7 downto 0) &
    s_slave_data_in_reg(15 downto 8) &
    s_slave_data_in_reg(23 downto 16) &
    s_slave_data_in_reg(31 downto 24);

  s_is_my_slave_transaction <= '1'
    when s_slave_transaction_active_reg = '1' and
         s_slave_bus_address_reg >= unsigned(baseAddress) and
         s_slave_bus_address_reg < unsigned(baseAddress) + 32
    else '0';

  s_slave_address_offset <= s_slave_bus_address_reg - unsigned(baseAddress);
  s_slave_word_address   <= s_slave_address_offset(4 downto 2);

  s_slave_access_error <= '1'
    when s_is_my_slave_transaction = '1' and
         (s_slave_burst_size_reg /= x"00" or
          (s_slave_read_not_write_reg = '0' and
           s_slave_byte_enables_reg /= x"F"))
    else '0';

  s_start_slave_read <= '1'
    when s_slave_state_reg = SLAVE_IDLE and
         s_slave_start_transaction_reg = '1' and
         s_is_my_slave_transaction = '1' and
         s_slave_read_not_write_reg = '1' and
         s_slave_access_error = '0'
    else '0';

  s_reset_slave_read_data <= '1'
    when reset = '1' or
         (s_slave_state_reg = SLAVE_WAIT and slaveBusyIn = '0')
    else '0';

  s_slave_write <= '1'
    when s_slave_data_in_valid_reg = '1' and
         s_is_my_slave_transaction = '1' and
         s_slave_access_error = '0' and
         s_slave_read_not_write_reg = '0'
    else '0';

  s_write_framebuffer <= '1'
    when s_slave_write = '1' and s_slave_word_address = 4 else '0';

  s_write_control <= '1'
    when s_slave_write = '1' and s_slave_word_address = 5 else '0';

  slave_read_mux : process(all)
  begin
    case to_integer(s_slave_word_address) is
      when 0 =>
        s_slave_read_value_cpu <=
          std_logic_vector(to_unsigned(0, 21)) &
          std_logic_vector(s_pixel_count_value_reg);
      when 1 =>
        s_slave_read_value_cpu <=
          std_logic_vector(to_unsigned(0, 21)) &
          std_logic_vector(s_line_count_value_reg);
      when 2 =>
        s_slave_read_value_cpu <=
          std_logic_vector(to_unsigned(0, 15)) &
          std_logic_vector(s_pclk_count_value_reg);
      when 3 =>
        s_slave_read_value_cpu <=
          x"000000" & std_logic_vector(s_fps_count_value_reg);
      when 4 =>
        s_slave_read_value_cpu <= s_frame_buffer_base_reg;
      when 5 =>
        s_slave_read_value_cpu <=
          (31 downto 2 => '0') &
          s_grabber_single_shot_reg & s_grabber_active_reg;
      when 6 =>
        s_slave_read_value_cpu <=
          (31 downto 2 => '0') &
          s_grabber_running_reg & s_single_shot_done_reg;
      when others =>
        s_slave_read_value_cpu <= (others => '0');
    end case;
  end process;

  slave_next_state : process(all)
  begin
    case s_slave_state_reg is
      when SLAVE_IDLE =>
        if s_start_slave_read = '1' then
          s_slave_state_next <= SLAVE_WAIT;
        else
          s_slave_state_next <= SLAVE_IDLE;
        end if;
      when SLAVE_WAIT =>
        if slaveBusyIn = '1' then
          s_slave_state_next <= SLAVE_WAIT;
        else
          s_slave_state_next <= SLAVE_END;
        end if;
      when others =>
        s_slave_state_next <= SLAVE_IDLE;
    end case;
  end process;

  slave_registers : process(clock)
  begin
    if rising_edge(clock) then
      if reset = '1' then
        s_slave_start_transaction_reg <= '0';
      else
        s_slave_start_transaction_reg <= slaveBeginTransactionIn;
      end if;

      if reset = '1' or slaveEndTransactionIn = '1' then
        s_slave_transaction_active_reg <= '0';
      elsif slaveBeginTransactionIn = '1' then
        s_slave_transaction_active_reg <= '1';
      end if;

      if reset = '1' then
        s_slave_read_not_write_reg <= '0';
        s_slave_byte_enables_reg   <= (others => '0');
        s_slave_burst_size_reg     <= (others => '0');
        s_slave_bus_address_reg    <= (others => '0');
      elsif slaveBeginTransactionIn = '1' then
        s_slave_read_not_write_reg <= slaveReadNotWriteIn;
        s_slave_byte_enables_reg   <= slaveByteEnablesIn;
        s_slave_burst_size_reg     <= slaveBurstSizeIn;
        s_slave_bus_address_reg    <= unsigned(slaveAddressDataIn);
      end if;

      if reset = '1' then
        s_slave_data_in_reg <= (others => '0');
      elsif slaveDataValidIn = '1' then
        s_slave_data_in_reg <= slaveAddressDataIn;
      end if;

      if reset = '1' then
        s_slave_data_in_valid_reg <= '0';
      elsif slaveDataValidIn = '1' and
            s_is_my_slave_transaction = '1' and
            s_slave_access_error = '0' and
            s_slave_read_not_write_reg = '0' then
        s_slave_data_in_valid_reg <= '1';
      else
        s_slave_data_in_valid_reg <= '0';
      end if;

      if s_reset_slave_read_data = '1' then
        s_slave_data_out_reg       <= (others => '0');
        s_slave_data_out_valid_reg <= '0';
      elsif s_start_slave_read = '1' then
        s_slave_data_out_reg       <= s_slave_read_value_bus;
        s_slave_data_out_valid_reg <= '1';
      end if;

      if reset = '1' then
        s_slave_state_reg <= SLAVE_IDLE;
      else
        s_slave_state_reg <= s_slave_state_next;
      end if;

      if reset = '1' then
        s_slave_end_transaction_reg <= '0';
      elsif s_slave_state_reg = SLAVE_END then
        s_slave_end_transaction_reg <= '1';
      else
        s_slave_end_transaction_reg <= '0';
      end if;

      if reset = '1' or slaveEndTransactionIn = '1' then
        s_slave_bus_error_reg <= '0';
      else
        s_slave_bus_error_reg <= s_slave_access_error;
      end if;
    end if;
  end process;

  camera_configuration : process(clock)
  begin
    if rising_edge(clock) then
      if reset = '1' then
        s_frame_buffer_base_reg <= (others => '0');
      elsif s_write_framebuffer = '1' then
        s_frame_buffer_base_reg <= s_slave_write_value_cpu(31 downto 2) & "00";
      end if;

      if reset = '1' then
        s_grabber_active_reg <= '0';
      elsif s_write_control = '1' then
        s_grabber_active_reg <=
          s_slave_write_value_cpu(0) and not s_slave_write_value_cpu(1);
      end if;

      if reset = '1' or s_single_shot_action_reg(0) = '1' then
        s_grabber_single_shot_reg <= '0';
      elsif s_write_control = '1' then
        s_grabber_single_shot_reg <=
          s_slave_write_value_cpu(1) and not s_slave_write_value_cpu(0);
      end if;

      if reset = '1' then
        s_single_shot_done_reg <= '0';
      elsif s_write_control = '1' and
            s_slave_write_value_cpu(1) = '1' and
            s_slave_write_value_cpu(0) = '0' then
        s_single_shot_done_reg <= '0';
      elsif s_single_shot_action_reg(1) = '1' then
        s_single_shot_done_reg <= '1';
      end if;
    end if;
  end process;

  slaveAddressDataOut    <= s_slave_data_out_reg when s_slave_data_out_valid_reg = '1' else (others => '0');
  slaveDataValidOut      <= s_slave_data_out_valid_reg;
  slaveEndTransactionOut <= s_slave_end_transaction_reg;
  slaveBusErrorOut       <= s_slave_bus_error_reg;

  -----------------------------------------------------------------------------
  -- Pixel packing and dual-clock line buffer
  -----------------------------------------------------------------------------
  s_pixel_word <= s_byte1_reg & camData & s_byte3_reg & s_byte2_reg;
  s_we_line_buffer <= hsync when s_pixel_count_reg(1 downto 0) = "11" else '0';

  pixel_packer : process(pclk)
  begin
    if rising_edge(pclk) then
      if s_pixel_count_reg(1 downto 0) = "00" and hsync = '1' then
        s_byte3_reg <= camData;
      end if;
      if s_pixel_count_reg(1 downto 0) = "01" and hsync = '1' then
        s_byte2_reg <= camData;
      end if;
      if s_pixel_count_reg(1 downto 0) = "10" and hsync = '1' then
        s_byte1_reg <= camData;
      end if;
    end if;
  end process;

  line_buffer : dualPortRam2k_VHDL
    port map (
      address1    => std_logic_vector(s_pixel_count_reg(10 downto 2)),
      address2    => std_logic_vector(s_bus_select_reg),
      clock1      => pclk,
      clock2      => clock,
      writeEnable => s_we_line_buffer,
      dataIn1     => s_pixel_word,
      dataOut2    => s_bus_pixel_word
    );

  new_screen_sync : synchroFlop_VHDL
    port map (clockIn => pclk, clockOut => clock, reset => reset,
              D => s_vsync_neg_edge, Q => s_new_screen);

  new_line_sync : synchroFlop_VHDL
    port map (clockIn => pclk, clockOut => clock, reset => reset,
              D => s_hsync_neg_edge, Q => s_new_line);

  -----------------------------------------------------------------------------
  -- DMA master
  -----------------------------------------------------------------------------
  s_do_write <= '1'
    when s_dma_state_reg = DMA_DO_BURST and s_burst_count_reg(8) = '0' and
         masterBusyIn = '0'
    else '0';

  s_dma_bus_address_next <=
    unsigned(s_frame_buffer_base_reg)
      when reset = '1' or s_new_screen = '1' else
    s_dma_bus_address_reg + 4
      when s_do_write = '1' else
    s_dma_bus_address_reg;

  s_burst_size_next <=
    to_unsigned(16, 8)
      when s_dma_state_reg = DMA_INIT_BURST and s_nr_words_per_line_reg > 16 else
    s_nr_words_per_line_reg(7 downto 0);

  dma_next_state : process(all)
  begin
    case s_dma_state_reg is
      when DMA_IDLE =>
        if (s_grabber_running_reg = '1' or s_single_shot_action_reg(0) = '1') and
           s_new_line = '1' then
          s_dma_state_next <= DMA_REQUEST_BUS;
        else
          s_dma_state_next <= DMA_IDLE;
        end if;
      when DMA_REQUEST_BUS =>
        if masterBusGrant = '1' then
          s_dma_state_next <= DMA_INIT_BURST;
        else
          s_dma_state_next <= DMA_REQUEST_BUS;
        end if;
      when DMA_INIT_BURST =>
        s_dma_state_next <= DMA_DO_BURST;
      when DMA_DO_BURST =>
        if masterBusErrorIn = '1' then
          s_dma_state_next <= DMA_END_ERROR;
        elsif s_burst_count_reg(8) = '1' and masterBusyIn = '0' then
          s_dma_state_next <= DMA_END_TRANS;
        else
          s_dma_state_next <= DMA_DO_BURST;
        end if;
      when DMA_END_TRANS =>
        if s_nr_words_per_line_reg /= 0 then
          s_dma_state_next <= DMA_REQUEST_BUS;
        else
          s_dma_state_next <= DMA_IDLE;
        end if;
      when others =>
        s_dma_state_next <= DMA_IDLE;
    end case;
  end process;

  dma_registers : process(clock)
  begin
    if rising_edge(clock) then
      if reset = '1' then
        s_dma_state_reg <= DMA_IDLE;
      else
        s_dma_state_reg <= s_dma_state_next;
      end if;

      if reset = '1' then
        s_dma_bus_address_reg <= (others => '0');
      else
        s_dma_bus_address_reg <= s_dma_bus_address_next;
      end if;

      if reset = '1' then
        s_grabber_running_reg <= '0';
      elsif s_new_screen = '1' then
        s_grabber_running_reg <= s_grabber_active_reg;
      end if;

      if reset = '1' or s_single_shot_action_reg(1) = '1' then
        s_single_shot_action_reg <= "00";
      elsif s_new_screen = '1' then
        s_single_shot_action_reg <=
          s_single_shot_action_reg(0) & s_grabber_single_shot_reg;
      end if;

      if reset = '1' then
        s_dma_begin_transaction_reg <= '0';
      elsif s_dma_state_reg = DMA_INIT_BURST then
        s_dma_begin_transaction_reg <= '1';
      else
        s_dma_begin_transaction_reg <= '0';
      end if;

      if reset = '1' then
        s_dma_end_transaction_reg <= '0';
      elsif s_dma_state_reg = DMA_END_TRANS or s_dma_state_reg = DMA_END_ERROR then
        s_dma_end_transaction_reg <= '1';
      else
        s_dma_end_transaction_reg <= '0';
      end if;

      if reset = '1' then
        s_dma_byte_enables_reg <= (others => '0');
      elsif s_dma_state_reg = DMA_INIT_BURST then
        s_dma_byte_enables_reg <= x"F";
      else
        s_dma_byte_enables_reg <= (others => '0');
      end if;

      if reset = '1' then
        s_dma_address_data_out_reg <= (others => '0');
      elsif s_dma_state_reg = DMA_INIT_BURST then
        s_dma_address_data_out_reg <= std_logic_vector(s_dma_bus_address_reg);
      elsif s_do_write = '1' then
        s_dma_address_data_out_reg <= s_bus_pixel_word;
      elsif masterBusyIn = '0' then
        s_dma_address_data_out_reg <= (others => '0');
      end if;

      if reset = '1' then
        s_dma_data_valid_reg <= '0';
      elsif s_do_write = '1' then
        s_dma_data_valid_reg <= '1';
      elsif masterBusyIn = '0' then
        s_dma_data_valid_reg <= '0';
      end if;

      if reset = '1' then
        s_dma_burst_size_reg <= (others => '0');
      elsif s_dma_state_reg = DMA_INIT_BURST then
        s_dma_burst_size_reg <= s_burst_size_next - 1;
      else
        s_dma_burst_size_reg <= (others => '0');
      end if;

      if reset = '1' then
        s_burst_count_reg <= (others => '0');
      elsif s_dma_state_reg = DMA_INIT_BURST then
        s_burst_count_reg <= resize(s_burst_size_next, 9) - 1;
      elsif s_do_write = '1' then
        s_burst_count_reg <= s_burst_count_reg - 1;
      end if;

      if reset = '1' or s_dma_state_reg = DMA_IDLE then
        s_bus_select_reg <= (others => '0');
      elsif s_do_write = '1' then
        s_bus_select_reg <= s_bus_select_reg + 1;
      end if;

      if reset = '1' then
        s_nr_words_per_line_reg <= (others => '0');
      elsif s_new_line = '1' then
        s_nr_words_per_line_reg <= s_pixel_count_value_reg(10 downto 2);
      elsif s_dma_state_reg = DMA_INIT_BURST then
        s_nr_words_per_line_reg <=
          s_nr_words_per_line_reg - resize(s_burst_size_next, 9);
      end if;
    end if;
  end process;

  masterRequestBus          <= '1' when s_dma_state_reg = DMA_REQUEST_BUS else '0';
  masterBeginTransactionOut <= s_dma_begin_transaction_reg;
  masterEndTransactionOut   <= s_dma_end_transaction_reg;
  masterDataValidOut        <= s_dma_data_valid_reg;
  masterAddressDataOut      <= s_dma_address_data_out_reg
    when s_dma_begin_transaction_reg = '1' or
         s_dma_data_valid_reg = '1' or masterBusyIn = '1'
    else (others => '0');
  masterByteEnablesOut <= s_dma_byte_enables_reg;
  masterBurstSizeOut   <= std_logic_vector(s_dma_burst_size_reg);

end architecture rtl;
