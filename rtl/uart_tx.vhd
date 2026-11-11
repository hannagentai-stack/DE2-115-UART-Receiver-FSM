--------------------------------------------------------------------------------
-- File Name: uart_tx.vhd
-- Project  : UART Receiver using FSM on Terasic DE2-115
-- Author   : FPGA Design Engineer
-- Standard : VHDL-93 / VHDL-2008
-- Description:
--   Khối UART Transmitter đơn giản phục vụ tính năng Echo dữ liệu.
--   Khi nhận được xung tx_start, khối sẽ truyền byte tx_data qua đường tx:
--   1 start bit mức '0', 8 data bit truyền LSB trước, 1 stop bit mức '1'.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    generic (
        CLK_FREQ  : natural := 50_000_000; -- Tần số clock hệ thống tính theo Hz
        BAUD_RATE : natural := 115_200     -- Tốc độ baud tính theo bps
    );
    port (
        clk      : in  std_logic;                    -- Clock hệ thống 50 MHz
        rst_n    : in  std_logic;                    -- Reset bất đồng bộ mức thấp
        tx_start : in  std_logic;                    -- Xung kích hoạt truyền 1 byte
        tx_data  : in  std_logic_vector(7 downto 0); -- Byte cần truyền
        tx       : out std_logic;                    -- Đường truyền nối tiếp UART TX
        tx_busy  : out std_logic                     -- Cờ báo đang bận truyền dữ liệu
    );
end entity uart_tx;

architecture rtl of uart_tx is

    constant BAUD_DIVISOR : natural := (CLK_FREQ + (BAUD_RATE / 2)) / BAUD_RATE;

    type state_type is (S_IDLE, S_START, S_DATA, S_STOP);
    signal state_reg, state_next : state_type := S_IDLE;

    signal baud_cnt_reg, baud_cnt_next : natural range 0 to BAUD_DIVISOR - 1 := 0;
    signal bit_cnt_reg, bit_cnt_next   : natural range 0 to 7 := 0;
    signal shift_reg, shift_next       : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_reg, tx_next             : std_logic := '1';

begin

    ----------------------------------------------------------------------------
    -- Thanh ghi đồng bộ
    ----------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state_reg    <= S_IDLE;
            baud_cnt_reg <= 0;
            bit_cnt_reg  <= 0;
            shift_reg    <= (others => '0');
            tx_reg       <= '1';
        elsif rising_edge(clk) then
            state_reg    <= state_next;
            baud_cnt_reg <= baud_cnt_next;
            bit_cnt_reg  <= bit_cnt_next;
            shift_reg    <= shift_next;
            tx_reg       <= tx_next;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Logic chuyển trạng thái và xử lý truyền
    ----------------------------------------------------------------------------
    process(state_reg, baud_cnt_reg, bit_cnt_reg, shift_reg, tx_reg, tx_start, tx_data)
    begin
        state_next    <= state_reg;
        baud_cnt_next <= baud_cnt_reg;
        bit_cnt_next  <= bit_cnt_reg;
        shift_next    <= shift_reg;
        tx_next       <= tx_reg;

        case state_reg is

            when S_IDLE =>
                tx_next <= '1'; -- Đường truyền rỗi ở mức 1
                if tx_start = '1' then
                    shift_next    <= tx_data;
                    baud_cnt_next <= 0;
                    state_next    <= S_START;
                end if;

            when S_START =>
                tx_next <= '0'; -- Start bit ở mức 0
                if baud_cnt_reg = BAUD_DIVISOR - 1 then
                    baud_cnt_next <= 0;
                    bit_cnt_next  <= 0;
                    state_next    <= S_DATA;
                else
                    baud_cnt_next <= baud_cnt_reg + 1;
                end if;

            when S_DATA =>
                tx_next <= shift_reg(bit_cnt_reg); -- Truyền LSB trước
                if baud_cnt_reg = BAUD_DIVISOR - 1 then
                    baud_cnt_next <= 0;
                    if bit_cnt_reg = 7 then
                        state_next <= S_STOP;
                    else
                        bit_cnt_next <= bit_cnt_reg + 1;
                    end if;
                else
                    baud_cnt_next <= baud_cnt_reg + 1;
                end if;

            when S_STOP =>
                tx_next <= '1'; -- Stop bit ở mức 1
                if baud_cnt_reg = BAUD_DIVISOR - 1 then
                    baud_cnt_next <= 0;
                    state_next    <= S_IDLE;
                else
                    baud_cnt_next <= baud_cnt_reg + 1;
                end if;

            when others =>
                state_next <= S_IDLE;

        end case;
    end process;

    tx      <= tx_reg;
    tx_busy <= '0' when (state_reg = S_IDLE) else '1';

end architecture rtl;
