--------------------------------------------------------------------------------
-- File Name: uart_rx_top.vhd
-- Project  : UART Receiver using FSM on Terasic DE2-115
-- Target   : Cyclone IV E EP4CE115F29C7
-- Author   : FPGA Design Engineer
-- Standard : VHDL-93 / VHDL-2008
-- Description:
--   Khối Top-Level tích hợp toàn bộ hệ thống UART Receiver trên kit DE2-115:
--   - uart_rx        : Nhận byte nối tiếp, kiểm tra start, parity, stop bit.
--   - uart_tx        : Echo gửi lại PC hoặc phát dữ liệu test On-board từ SW.
--   - hex_to_7seg    : 2 bộ giải mã hiển thị byte dữ liệu Hexa lên HEX1:HEX0.
--   - pulse_stretcher: Kéo dài xung rx_done 100 ms ra LEDR[8].
--   - LEDR[7..0]     : Hiển thị 8 bit dữ liệu vừa nhận.
--   - LEDR[8]        : Đèn báo nhận byte thành công, kéo dài xung 100 ms.
--   - LEDR[9]        : Cờ frame_err được chốt lại, xóa bằng nút KEY[1].
--   - LEDR[12..10]   : Hiển thị trạng thái FSM Moore bằng mã nhị phân 3-bit từ 0 đến 5.
--   - LEDR[16]       : Đèn báo UART TX đang bận truyền.
--   - LEDR[17]       : Đèn báo chế độ On-board Test Mode đang bật khi SW[17] = '1'.
--   - Chế độ hoạt động điều khiển bởi SW[17]:
--       + SW[17] = '1': Chế độ On-Board Loopback nội bộ. Phát từ SW[7..0],
--                       nhấn KEY[2] để truyền, không cần cáp nối ngoài!
--       + SW[17] = '0': Chế độ kết nối máy tính PC qua cổng RS-232 DB9.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx_top is
    generic (
        CLK_FREQ     : natural := 50_000_000; -- Clock hệ thống 50 MHz
        BAUD_RATE    : natural := 115_200;    -- Baud rate mặc định 115200
        DATA_BITS    : natural := 8;          -- 8 bit dữ liệu
        PARITY_EN    : boolean := false       -- Mặc định không kiểm tra Parity
    );
    port (
        -- Clock và các nút bấm
        CLOCK_50 : in  std_logic;                    -- Chân PIN_Y2 chuẩn 3.3-V LVTTL
        KEY      : in  std_logic_vector(2 downto 0); -- KEY[0]: Reset, KEY[1]: Clear Err, KEY[2]: Phát On-Board
        
        -- Các công tắc gạt
        SW       : in  std_logic_vector(17 downto 0);-- SW[7..0]: Data phát, SW[17]: 1=Test On-board, 0=PC Mode
        
        -- Cổng nối tiếp UART kết nối DB9 / RS232 transceiver
        UART_RXD : in  std_logic;                    -- Chân PIN_G12 chuẩn 3.3-V LVTTL
        UART_TXD : out std_logic;                    -- Chân PIN_G9 chuẩn 3.3-V LVTTL, Echo / Transmit
        
        -- Dãy LED đỏ hiển thị dữ liệu và trạng thái
        LEDR     : out std_logic_vector(17 downto 0);
        
        -- LED 7 đoạn hiển thị mã Hexa
        HEX0     : out std_logic_vector(6 downto 0); -- Hiển thị 4 bit thấp 3..0
        HEX1     : out std_logic_vector(6 downto 0)  -- Hiển thị 4 bit cao 7..4
    );
end entity uart_rx_top;

architecture rtl of uart_rx_top is

    ----------------------------------------------------------------------------
    -- Khai báo tín hiệu nội bộ
    ----------------------------------------------------------------------------
    signal rst_n           : std_logic;
    signal rx_data_out     : std_logic_vector(7 downto 0);
    signal rx_done_pulse   : std_logic;
    signal rx_frame_err    : std_logic;
    signal rx_parity_err   : std_logic;
    signal fsm_dbg         : std_logic_vector(3 downto 0);

    -- Thanh ghi chốt dữ liệu nhận được để hiển thị ổn định
    signal data_latch      : std_logic_vector(7 downto 0) := (others => '0');
    signal frame_err_latch : std_logic := '0';

    -- Tín hiệu điều khiển truyền phát Echo hoặc On-board test
    signal tx_data_reg     : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_start_sig    : std_logic := '0';
    signal tx_busy_sig     : std_logic;
    signal tx_serial_out   : std_logic;

    -- Tín hiệu chọn nguồn UART RX: Loopback nội bộ hoặc Chân DB9
    signal rx_mux_in       : std_logic;

    -- Bộ phát hiện cạnh nhấn nút KEY[2] để gửi dữ liệu từ SW[7..0]
    signal key2_sync       : std_logic_vector(1 downto 0) := "11";
    signal key2_press      : std_logic;

    -- Tín hiệu LEDR[8] từ mạch kéo dài xung
    signal led8_stretched  : std_logic;

begin

    -- KEY[0] trên DE2-115 tích cực mức thấp, khi nhấn có mức '0'
    rst_n <= KEY(0);

    ----------------------------------------------------------------------------
    -- BẮT CẠNH NHẤN NÚT KEY[2] TÍCH CỰC MỨC THẤP
    ----------------------------------------------------------------------------
    process(CLOCK_50, rst_n)
    begin
        if rst_n = '0' then
            key2_sync <= "11";
        elsif rising_edge(CLOCK_50) then
            key2_sync <= key2_sync(0) & KEY(2);
        end if;
    end process;
    -- Xung tích cực mức '1' trong đúng 1 chu kỳ clock khi vừa nhấn KEY[2]
    key2_press <= '1' when (key2_sync = "10") else '0';

    ----------------------------------------------------------------------------
    -- ĐA HỢP NGUỒN VÀO CHO UART RECEIVER
    ----------------------------------------------------------------------------
    -- Khi SW[17] = '1': Lấy từ đầu ra tx_serial_out để chạy Loopback nội bộ trong chip
    -- Khi SW[17] = '0': Lấy từ chân vật lý UART_RXD của cổng RS-232 DB9 ngoài
    rx_mux_in <= tx_serial_out when (SW(17) = '1') else UART_RXD;

    -- Nối tín hiệu ra cổng phát ngoài
    UART_TXD  <= tx_serial_out;

    ----------------------------------------------------------------------------
    -- 1. KHỞI TẠO KHỐI UART RECEIVER
    ----------------------------------------------------------------------------
    u_uart_rx : entity work.uart_rx
        generic map (
            CLK_FREQ    => CLK_FREQ,
            BAUD_RATE   => BAUD_RATE,
            DATA_BITS   => DATA_BITS,
            PARITY_EN   => PARITY_EN,
            PARITY_ODD  => false
        )
        port map (
            clk           => CLOCK_50,
            rst_n         => rst_n,
            rx            => rx_mux_in,
            rx_data       => rx_data_out,
            rx_done       => rx_done_pulse,
            frame_err     => rx_frame_err,
            parity_err    => rx_parity_err,
            fsm_state_dbg => fsm_dbg
        );

    ----------------------------------------------------------------------------
    -- 2. CHỐT DỮ LIỆU VÀ ĐIỀU KHIỂN TRUYỀN PHÁT
    ----------------------------------------------------------------------------
    process(CLOCK_50, rst_n)
    begin
        if rst_n = '0' then
            data_latch      <= (others => '0');
            frame_err_latch <= '0';
            tx_start_sig    <= '0';
            tx_data_reg     <= (others => '0');
        elsif rising_edge(CLOCK_50) then
            -- Mặc định xung kích hoạt tx chỉ kéo dài 1 chu kỳ clock
            tx_start_sig <= '0';

            -- Khi nhận xong 1 byte hợp lệ: chốt dữ liệu
            if rx_done_pulse = '1' then
                data_latch <= rx_data_out;
                -- Ở chế độ PC ngoài khi SW[17] = '0', kích hoạt Echo byte vừa nhận về PC
                if SW(17) = '0' and tx_busy_sig = '0' then
                    tx_data_reg  <= rx_data_out;
                    tx_start_sig <= '1';
                end if;
            end if;

            -- Khi người dùng nhấn nút KEY[2] để phát dữ liệu từ SW[7..0]:
            if key2_press = '1' and tx_busy_sig = '0' then
                tx_data_reg  <= SW(7 downto 0);
                tx_start_sig <= '1';
            end if;

            -- Chốt cờ Frame Error: Bật khi có lỗi, xóa khi nhấn KEY[1] ở mức '0'
            if KEY(1) = '0' then
                frame_err_latch <= '0';
            elsif rx_frame_err = '1' then
                frame_err_latch <= '1';
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- 3. KHỞI TẠO KHỐI UART TRANSMITTER
    ----------------------------------------------------------------------------
    u_uart_tx : entity work.uart_tx
        generic map (
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => BAUD_RATE
        )
        port map (
            clk      => CLOCK_50,
            rst_n    => rst_n,
            tx_start => tx_start_sig,
            tx_data  => tx_data_reg,
            tx       => tx_serial_out,
            tx_busy  => tx_busy_sig
        );

    ----------------------------------------------------------------------------
    -- 4. KÉO DÀI XUNG rx_done 100 MS CHO LEDR[8]
    ----------------------------------------------------------------------------
    u_pulse_stretcher : entity work.pulse_stretcher
        generic map (
            PULSE_CLOCKS => CLK_FREQ / 10 -- 100 ms tại 50 MHz = 5,000,000 chu kỳ
        )
        port map (
            clk       => CLOCK_50,
            rst_n     => rst_n,
            pulse_in  => rx_done_pulse,
            pulse_out => led8_stretched
        );

    ----------------------------------------------------------------------------
    -- 5. GIẢI MÃ LED 7 THANH HEX1 : HEX0
    ----------------------------------------------------------------------------
    -- HEX0 hiển thị 4 bit thấp của data_latch
    u_hex0 : entity work.hex_to_7seg
        port map (
            hex_digit => data_latch(3 downto 0),
            seg       => HEX0
        );

    -- HEX1 hiển thị 4 bit cao của data_latch
    u_hex1 : entity work.hex_to_7seg
        port map (
            hex_digit => data_latch(7 downto 4),
            seg       => HEX1
        );

    ----------------------------------------------------------------------------
    -- 6. GÁN CÁC ĐẦU RA LED ĐỎ LEDR
    ----------------------------------------------------------------------------
    -- LEDR[7..0]   : 8 bit dữ liệu vừa nhận được
    LEDR(7 downto 0)   <= data_latch;
    -- LEDR[8]      : Báo nhận byte thành công, chớp sáng 100 ms
    LEDR(8)            <= led8_stretched;
    -- LEDR[9]      : Cờ Framing Error lưu trạng thái, xóa bằng KEY[1]
    LEDR(9)            <= frame_err_latch;
    -- LEDR[12..10] : Trạng thái FSM Moore mã hóa 3 bit từ 000=IDLE đến 101=DONE
    LEDR(12 downto 10) <= fsm_dbg(2 downto 0);
    -- LEDR[15..13] : Dự phòng, luôn tắt
    LEDR(15 downto 13) <= (others => '0');
    -- LEDR[16]     : Đèn báo UART TX đang bận truyền
    LEDR(16)           <= tx_busy_sig;
    -- LEDR[17]     : Đèn báo chế độ On-board Test Mode đang bật
    LEDR(17)           <= SW(17);

end architecture rtl;
