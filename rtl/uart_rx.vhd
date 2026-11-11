--------------------------------------------------------------------------------
-- File Name: uart_rx.vhd
-- Project  : UART Receiver using FSM on Terasic DE2-115
-- Author   : FPGA Design Engineer
-- Standard : VHDL-93 / VHDL-2008
-- Description:
--   Khối UART Receiver chuẩn công nghiệp, điều khiển bởi máy trạng thái
--   hữu hạn Moore FSM.
--
--   Đặc tính kỹ thuật:
--   - Chuẩn truyền: 1 start bit mức 0, DATA_BITS mặc định 8, tùy chọn Parity, 1 stop bit mức 1.
--   - Lấy mẫu quá mức 16x với bộ chia baud tự động tính toán.
--   - Bộ đồng bộ 2 tầng D-FF chống hiện tượng bất ổn định.
--   - Bộ lọc nhiễu Start bit: kiểm tra lại mức logic tại giữa bit ở tick thứ 7.
--   - Lấy mẫu chính xác giữa các bit dữ liệu và stop bit sau mỗi 16 tick.
--   - Phát hiện lỗi khung truyền và lỗi Parity.
--   - FSM kiểu Moore, viết theo phong cách rõ ràng, không sinh chốt.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    generic (
        CLK_FREQ    : natural := 50_000_000; -- Tần số clock hệ thống tính theo Hz
        BAUD_RATE   : natural := 115_200;    -- Tốc độ baud tính theo bps
        DATA_BITS   : natural := 8;          -- Số bit dữ liệu mặc định là 8
        PARITY_EN   : boolean := false;      -- Bật/tắt bit kiểm tra chẵn lẻ
        PARITY_ODD  : boolean := false       -- false: Chẵn, true: Lẻ
    );
    port (
        clk          : in  std_logic;        -- Clock hệ thống 50 MHz
        rst_n        : in  std_logic;        -- Reset bất đồng bộ, tích cực mức thấp
        rx           : in  std_logic;        -- Đường truyền nối tiếp UART RX bất đồng bộ
        
        -- Dữ liệu và cờ trạng thái đầu ra
        rx_data      : out std_logic_vector(DATA_BITS - 1 downto 0); -- Byte dữ liệu nhận được
        rx_done      : out std_logic;        -- Xung mức cao 1 chu kỳ clock khi nhận xong byte hợp lệ
        frame_err    : out std_logic;        -- Xung mức cao 1 chu kỳ clock khi Stop bit = '0'
        parity_err   : out std_logic;        -- Xung mức cao 1 chu kỳ clock khi sai Parity
        
        -- Tín hiệu giám sát trạng thái FSM đưa ra LEDR trên kit
        fsm_state_dbg: out std_logic_vector(3 downto 0)
    );
end entity uart_rx;

architecture rtl of uart_rx is

    ----------------------------------------------------------------------------
    -- Hằng số tính toán bộ chia baud 16x
    -- Hệ số chia M = CLK_FREQ / 16 * BAUD_RATE làm tròn tới số nguyên gần nhất
    ----------------------------------------------------------------------------
    constant BAUD_DIVISOR : natural := (CLK_FREQ + (8 * BAUD_RATE)) / (16 * BAUD_RATE);

    ----------------------------------------------------------------------------
    -- Khai báo kiểu trạng thái FSM Moore
    ----------------------------------------------------------------------------
    type state_type is (
        S_IDLE,    -- Chờ phát hiện cạnh xuống của Start bit
        S_START,   -- Đếm 8 ticks tới tâm Start bit và kiểm tra nhiễu
        S_DATA,    -- Lấy mẫu 8 bit dữ liệu tại tâm mỗi bit sau mỗi 16 ticks
        S_PARITY,  -- Lấy mẫu và kiểm tra bit Parity khi được bật
        S_STOP,    -- Lấy mẫu Stop bit tại tâm sau 16 ticks và kiểm tra lỗi khung
        S_DONE     -- Phát xung rx_done trong đúng 1 chu kỳ clock
    );

    -- Các thanh ghi trạng thái FSM
    signal state_reg, state_next : state_type;

    ----------------------------------------------------------------------------
    -- Tín hiệu đồng bộ hóa 2 flip-flop và bắt cạnh
    ----------------------------------------------------------------------------
    signal rx_sync_stage1 : std_logic := '1';
    signal rx_sync        : std_logic := '1';
    signal rx_prev        : std_logic := '1';
    signal rx_falling_edge: std_logic;

    ----------------------------------------------------------------------------
    -- Bộ tạo xung baud tick 16x
    ----------------------------------------------------------------------------
    signal baud_counter   : natural range 0 to BAUD_DIVISOR - 1 := 0;
    signal baud_tick_16x  : std_logic := '0';

    ----------------------------------------------------------------------------
    -- Các bộ đếm và thanh ghi dữ liệu
    ----------------------------------------------------------------------------
    signal tick_cnt_reg, tick_cnt_next : natural range 0 to 15 := 0;
    signal bit_cnt_reg, bit_cnt_next   : natural range 0 to DATA_BITS - 1 := 0;
    signal data_reg, data_next         : std_logic_vector(DATA_BITS - 1 downto 0) := (others => '0');
    signal rx_data_reg                 : std_logic_vector(DATA_BITS - 1 downto 0) := (others => '0');

    -- Cờ lỗi nội bộ
    signal frame_err_reg, frame_err_next   : std_logic := '0';
    signal parity_err_reg, parity_err_next : std_logic := '0';
    signal parity_calc                     : std_logic;

    ----------------------------------------------------------------------------
    -- Hàm tính bit Parity chẵn/lẻ từ vector dữ liệu
    ----------------------------------------------------------------------------
    function compute_parity(d : std_logic_vector; odd : boolean) return std_logic is
        variable p : std_logic := '0';
    begin
        for i in d'range loop
            p := p xor d(i);
        end loop;
        if odd then
            return not p;
        else
            return p;
        end if;
    end function;

begin

    ----------------------------------------------------------------------------
    -- 1. BỘ ĐỒNG BỘ 2 TẦNG D-FF VÀ PHÁT HIỆN CẠNH XUỐNG
    -- Chống hiện tượng bất ổn định từ đường truyền rx bên ngoài.
    ----------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            rx_sync_stage1 <= '1';
            rx_sync        <= '1';
            rx_prev        <= '1';
        elsif rising_edge(clk) then
            rx_sync_stage1 <= rx;
            rx_sync        <= rx_sync_stage1;
            rx_prev        <= rx_sync;
        end if;
    end process;

    -- Phát hiện cạnh xuống: chu kỳ trước là '1', chu kỳ này là '0'
    rx_falling_edge <= '1' when (rx_prev = '1' and rx_sync = '0') else '0';

    ----------------------------------------------------------------------------
    -- 2. BỘ PHÁT XUNG BAUD TICK 16X
    -- Tạo xung baud_tick_16x có độ rộng 1 chu kỳ clock hệ thống.
    -- Khi FSM ở S_IDLE và bắt được cạnh xuống, bộ đếm được reset về 0 để đồng pha.
    ----------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            baud_counter  <= 0;
            baud_tick_16x <= '0';
        elsif rising_edge(clk) then
            if state_reg = S_IDLE and rx_falling_edge = '1' then
                -- Đồng pha tức thời với cạnh xuống của Start bit
                baud_counter  <= 0;
                baud_tick_16x <= '0';
            elsif baud_counter = BAUD_DIVISOR - 1 then
                baud_counter  <= 0;
                baud_tick_16x <= '1';
            else
                baud_counter  <= baud_counter + 1;
                baud_tick_16x <= '0';
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- 3. THANH GHI TRẠNG THÁI VÀ DỮ LIỆU ĐỒNG BỘ
    ----------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state_reg      <= S_IDLE;
            tick_cnt_reg   <= 0;
            bit_cnt_reg    <= 0;
            data_reg       <= (others => '0');
            rx_data_reg    <= (others => '0');
            frame_err_reg  <= '0';
            parity_err_reg <= '0';
        elsif rising_edge(clk) then
            state_reg      <= state_next;
            tick_cnt_reg   <= tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            data_reg       <= data_next;
            frame_err_reg  <= frame_err_next;
            parity_err_reg <= parity_err_next;
            
            -- Chốt dữ liệu đầu ra khi nhận thành công ở trạng thái S_DONE
            if state_next = S_DONE then
                rx_data_reg <= data_next;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- 4. LOGIC CHUYỂN TRẠNG THÁI TỔ HỢP
    -- Thiết kế chuẩn Moore, gán giá trị mặc định tránh hoàn toàn sinh latch.
    ----------------------------------------------------------------------------
    parity_calc <= compute_parity(data_reg, PARITY_ODD);

    process(state_reg, rx_falling_edge, rx_sync, baud_tick_16x,
            tick_cnt_reg, bit_cnt_reg, data_reg, parity_calc)
    begin
        -- Giá trị mặc định nhằm ngăn chặn latch tổ hợp
        state_next      <= state_reg;
        tick_cnt_next   <= tick_cnt_reg;
        bit_cnt_next    <= bit_cnt_reg;
        data_next       <= data_reg;
        frame_err_next  <= '0';
        parity_err_next <= '0';

        case state_reg is

            --------------------------------------------------------------------
            -- S_IDLE: Đường truyền rỗi ở mức '1'. Chờ cạnh xuống Start bit.
            --------------------------------------------------------------------
            when S_IDLE =>
                tick_cnt_next <= 0;
                bit_cnt_next  <= 0;
                if rx_falling_edge = '1' then
                    state_next <= S_START;
                end if;

            --------------------------------------------------------------------
            -- S_START: Chờ 8 ticks tới tâm Start bit. Kiểm tra Start bit còn là 0.
            --------------------------------------------------------------------
            when S_START =>
                if baud_tick_16x = '1' then
                    if tick_cnt_reg = 7 then
                        -- Lấy mẫu giữa Start bit
                        if rx_sync = '0' then
                            -- Start bit hợp lệ, bắt đầu nhận Data
                            tick_cnt_next <= 0;
                            bit_cnt_next  <= 0;
                            state_next    <= S_DATA;
                        else
                            -- Nhiễu gai, Start bit không giữ mức 0 -> quay về IDLE
                            state_next <= S_IDLE;
                        end if;
                    else
                        tick_cnt_next <= tick_cnt_reg + 1;
                    end if;
                end if;

            --------------------------------------------------------------------
            -- S_DATA: Lấy mẫu DATA_BITS bit, gửi LSB trước. Mỗi bit kéo dài 16 tick.
            --------------------------------------------------------------------
            when S_DATA =>
                if baud_tick_16x = '1' then
                    if tick_cnt_reg = 15 then
                        -- Đúng tâm bit dữ liệu: lấy mẫu rx_sync
                        tick_cnt_next <= 0;
                        data_next(bit_cnt_reg) <= rx_sync; -- Nhận LSB trước từ bit 0 đến 7

                        if bit_cnt_reg = DATA_BITS - 1 then
                            if PARITY_EN then
                                state_next <= S_PARITY;
                            else
                                state_next <= S_STOP;
                            end if;
                        else
                            bit_cnt_next <= bit_cnt_reg + 1;
                        end if;
                    else
                        tick_cnt_next <= tick_cnt_reg + 1;
                    end if;
                end if;

            --------------------------------------------------------------------
            -- S_PARITY: Lấy mẫu bit kiểm tra chẵn lẻ tại tâm sau 16 ticks
            --------------------------------------------------------------------
            when S_PARITY =>
                if baud_tick_16x = '1' then
                    if tick_cnt_reg = 15 then
                        tick_cnt_next <= 0;
                        if rx_sync /= parity_calc then
                            parity_err_next <= '1';
                        end if;
                        state_next <= S_STOP;
                    else
                        tick_cnt_next <= tick_cnt_reg + 1;
                    end if;
                end if;

            --------------------------------------------------------------------
            -- S_STOP: Lấy mẫu Stop bit tại tâm sau 16 ticks. Stop bit bắt buộc = '1'.
            --------------------------------------------------------------------
            when S_STOP =>
                if baud_tick_16x = '1' then
                    if tick_cnt_reg = 15 then
                        tick_cnt_next <= 0;
                        if rx_sync = '1' then
                            -- Stop bit hợp lệ -> chuyển sang S_DONE
                            state_next <= S_DONE;
                        else
                            -- Lỗi khung truyền khi Stop bit = '0'
                            frame_err_next <= '1';
                            state_next     <= S_IDLE;
                        end if;
                    else
                        tick_cnt_next <= tick_cnt_reg + 1;
                    end if;
                end if;

            --------------------------------------------------------------------
            -- S_DONE: Phát xung rx_done trong 1 chu kỳ clock, sau đó quay về IDLE.
            --------------------------------------------------------------------
            when S_DONE =>
                state_next <= S_IDLE;

            when others =>
                state_next <= S_IDLE;

        end case;
    end process;

    ----------------------------------------------------------------------------
    -- 5. ĐẦU RA FSM THEO CHUẨN MOORE
    ----------------------------------------------------------------------------
    -- rx_done chỉ kích hoạt mức cao khi đang ở trạng thái S_DONE trong 1 chu kỳ clock
    rx_done    <= '1' when (state_reg = S_DONE) else '0';
    rx_data    <= rx_data_reg;
    frame_err  <= frame_err_reg;
    parity_err <= parity_err_reg;

    -- Mã hóa trạng thái FSM dạng nhị phân 4-bit đưa ra LEDR
    process(state_reg)
    begin
        case state_reg is
            when S_IDLE   => fsm_state_dbg <= "0000"; -- 0: Chờ
            when S_START  => fsm_state_dbg <= "0001"; -- 1: Nhận Start
            when S_DATA   => fsm_state_dbg <= "0010"; -- 2: Nhận Data
            when S_PARITY => fsm_state_dbg <= "0011"; -- 3: Kiểm tra Parity
            when S_STOP   => fsm_state_dbg <= "0100"; -- 4: Nhận Stop
            when S_DONE   => fsm_state_dbg <= "0101"; -- 5: Hoàn tất
            when others   => fsm_state_dbg <= "1111";
        end case;
    end process;

end architecture rtl;
