# GIẢI THÍCH CHI TIẾT TỪNG DÒNG CODE VHDL TRONG HỆ THỐNG UART RECEIVER

Tài liệu này cung cấp bản giải thích chuyên sâu, cặn kẽ từng dòng lệnh (line-by-line explanation) cho toàn bộ các mô-đun phần cứng VHDL thuộc đồ án **UART Receiver FSM trên FPGA Altera Cyclone IV E (Kit Terasic DE2-115)**.

---

# MỤC LỤC
1. [Khối Top-Level: `rtl/uart_rx_top.vhd`](#1-khối-top-level-rtluart_rx_topvhd)
2. [Khối Nhân Thu UART Receiver: `rtl/uart_rx.vhd`](#2-khối-nhân-thu-uart-receiver-rtluart_rxvhd)
3. [Khối Phát UART Transmitter: `rtl/uart_tx.vhd`](#3-khối-phát-uart-transmitter-rtluart_txvhd)
4. [Khối Giải Mã LED 7 Thanh: `rtl/hex_to_7seg.vhd`](#4-khối-giải-mã-led-7-thanh-rtlhex_to_7segvhd)
5. [Khối Kéo Dài Xung Hiển Thị: `rtl/pulse_stretcher.vhd`](#5-khối-kéo-dài-xung-hiển-thị-rtlpulse_stretchervhd)

---

## 1. KHỐI TOP-LEVEL: `rtl/uart_rx_top.vhd`

Khối Top-level giữ vai trò trung tâm điều phối, kết nối tất cả các thực thể con với các chân I/O vật lý của chip FPGA Cyclone IV E trên kit DE2-115.

```vhdl
1: library ieee;
2: use ieee.std_logic_1164.all;
3: use ieee.numeric_std.all;
```
* **Dòng 1-3:** Khai báo các thư viện chuẩn của IEEE:
  * `std_logic_1164`: Định nghĩa các kiểu dữ liệu mức logic chuẩn trong phần cứng như `std_logic` ('0', '1', 'Z', 'X'...) và `std_logic_vector`.
  * `numeric_std`: Cung cấp các kiểu số học `unsigned`, `signed` và các phép toán cộng trừ số học cho phần cứng.

```vhdl
22: entity uart_rx_top is
23:     generic (
24:         CLK_FREQ     : natural := 50_000_000; -- Clock hệ thống 50 MHz
25:         BAUD_RATE    : natural := 115_200;    -- Baud rate mặc định 115200
26:         DATA_BITS    : natural := 8;          -- 8 bit dữ liệu
27:         PARITY_EN    : boolean := false       -- Mặc định không kiểm tra Parity
28:     );
```
* **Dòng 22-28:** Khai báo phần thông số chung `generic`:
  * `CLK_FREQ`: Tần số thạch anh trên kit DE2-115 là $50\text{ MHz}$ ($50\,000\,000\text{ Hz}$).
  * `BAUD_RATE`: Tốc độ truyền thông nối tiếp mặc định chuẩn công nghiệp $115\,200\text{ bps}$.
  * `DATA_BITS`: Độ rộng khung dữ liệu là 8 bit (1 byte).
  * `PARITY_EN`: `false` nghĩa là khung truyền chuẩn `8N1` (8 data bits, No parity, 1 stop bit).

```vhdl
29:     port (
30:         CLOCK_50 : in  std_logic;                    -- PIN_Y2 (3.3-V LVTTL)
31:         KEY      : in  std_logic_vector(2 downto 0); -- KEY[0]: Reset, KEY[1]: Clear Err, KEY[2]: Phát On-Board
32:         SW       : in  std_logic_vector(17 downto 0);-- SW[7..0]: Data phát, SW[17]: 1=Test On-board, 0=PC Mode
33:         UART_RXD : in  std_logic;                    -- PIN_G12 (3.3-V LVTTL)
34:         UART_TXD : out std_logic;                    -- PIN_G9  (3.3-V LVTTL, Echo / Transmit)
35:         LEDR     : out std_logic_vector(17 downto 0);-- Dãy 18 LED đỏ hiển thị
36:         HEX0     : out std_logic_vector(6 downto 0); -- Low nibble (bit 3..0)
37:         HEX1     : out std_logic_vector(6 downto 0)  -- High nibble (bit 7..4)
38:     );
39: end entity uart_rx_top;
```
* **Dòng 30:** `CLOCK_50`: Ngõ vào xung nhịp toàn cục $50\text{ MHz}$ từ chân `PIN_Y2`.
* **Dòng 31:** `KEY`: Vector 3 ngõ vào nút bấm cơ tích cực mức thấp:
  * `KEY(0)` (`PIN_M23`): Nút Master Reset hệ thống.
  * `KEY(1)` (`PIN_M21`): Nút xóa chốt cờ lỗi khung truyền.
  * `KEY(2)` (`PIN_N21`): Nút kích hoạt phát dữ liệu trong chế độ kiểm tra On-Board.
* **Dòng 32:** `SW`: Vector 18 ngõ vào công tắc gạt:
  * `SW(7 downto 0)`: 8 switch cài đặt byte dữ liệu muốn phát trên kit.
  * `SW(17)`: Switch chuyển chế độ (gạt lên '1' để bật On-board test, gạt xuống '0' để nhận từ PC).
* **Dòng 33-34:** `UART_RXD` và `UART_TXD`: 2 chân nối tiếp của cổng RS-232 DB9 thông qua chip MAX3232.
* **Dòng 35:** `LEDR`: Dãy 18 LED đỏ hiển thị toàn diện dữ liệu và trạng thái hệ thống.
* **Dòng 36-37:** `HEX0`, `HEX1`: 2 bộ ngõ ra điều khiển 7 đoạn (Anode chung) hiển thị 2 số Hexa.

```vhdl
53:     signal rst_n           : std_logic;
54:     signal rx_data_out     : std_logic_vector(7 downto 0);
55:     signal rx_done_pulse   : std_logic;
56:     signal rx_frame_err    : std_logic;
57:     signal rx_parity_err   : std_logic;
58:     signal fsm_dbg         : std_logic_vector(3 downto 0);
59:     signal data_latch      : std_logic_vector(7 downto 0) := (others => '0');
60:     signal frame_err_latch : std_logic := '0';
61:     signal tx_data_reg     : std_logic_vector(7 downto 0) := (others => '0');
62:     signal tx_start_sig    : std_logic := '0';
63:     signal tx_busy_sig     : std_logic;
64:     signal tx_serial_out   : std_logic;
65:     signal rx_mux_in       : std_logic;
66:     signal key2_sync       : std_logic_vector(1 downto 0) := "11";
67:     signal key2_press      : std_logic;
68:     signal led8_stretched  : std_logic;
```
* **Dòng 53:** `rst_n`: Tín hiệu reset tích cực mức thấp nội bộ lấy từ `KEY(0)`.
* **Dòng 54-58:** Các tín hiệu đầu ra của khối nhân `uart_rx` (byte nhận, xung done, các cờ lỗi, mã trạng thái FSM).
* **Dòng 59-60:** Thanh ghi chốt `data_latch` để giữ dữ liệu hiển thị ổn định trên LED và `frame_err_latch` để lưu trạng thái lỗi cho tới khi người dùng ấn nút xóa.
* **Dòng 61-64:** Các đường kết nối tới khối phát `uart_tx` (dữ liệu phát, xung kích phát, cờ bận, đường bit nối tiếp).
* **Dòng 65:** `rx_mux_in`: Tín hiệu đa hợp chọn nguồn nhận UART (nội bộ hoặc chân DB9).
* **Dòng 66-67:** Thanh ghi 2 tầng `key2_sync` để chống dội phím và tạo xung cạnh xuống `key2_press`.
* **Dòng 68:** `led8_stretched`: Tín hiệu xung 100 ms từ mạch kéo dài xung đưa ra `LEDR(8)`.

```vhdl
72:     rst_n <= KEY(0);
73: 
74:     process(CLOCK_50, rst_n)
75:     begin
76:         if rst_n = '0' then
77:             key2_sync <= "11";
78:         elsif rising_edge(CLOCK_50) then
79:             key2_sync <= key2_sync(0) & KEY(2);
80:         end if;
81:     end process;
82:     key2_press <= '1' when (key2_sync = "10") else '0';
```
* **Dòng 72:** Nối trực tiếp nút bấm `KEY(0)` vào tín hiệu reset hệ thống `rst_n`.
* **Dòng 74-81:** Mạch đồng bộ 2 tầng D-FF cho nút bấm `KEY(2)`:
  * Nút `KEY(2)` không bấm ở mức '1', khi bấm xuống mức '0'.
  * Thanh ghi dịch `key2_sync` lưu 2 chu kỳ clock liên tiếp.
* **Dòng 82:** `key2_press <= '1' when (key2_sync = "10") else '0'`: Phát hiện cạnh xuống (Falling Edge Detector). Khi nút chuyển từ '1' sang '0' (người dùng vừa nhấn nút), `key2_press` bật lên '1' trong đúng **1 chu kỳ clock**, đảm bảo dù người dùng giữ tay lâu trên nút thì mạch cũng chỉ phát đúng 1 byte duy nhất.

```vhdl
88:     rx_mux_in <= tx_serial_out when (SW(17) = '1') else UART_RXD;
89:     UART_TXD  <= tx_serial_out;
```
* **Dòng 88:** Bộ chuyển mạch đa hợp (Multiplexer) 2 sang 1:
  * Nếu `SW(17) = '1'` (On-Board Test Mode): Đường vào `rx_mux_in` lấy trực tiếp từ đầu ra phát `tx_serial_out` (Loopback nội bộ trong vi mạch).
  * Nếu `SW(17) = '0'` (PC Mode): Đường vào `rx_mux_in` lấy từ chân vật lý `UART_RXD` của cổng DB9.
* **Dòng 89:** Luôn xuất tín hiệu phát `tx_serial_out` ra chân vật lý `UART_TXD`.

```vhdl
94:     u_uart_rx : entity work.uart_rx
95:         generic map (
96:             CLK_FREQ    => CLK_FREQ,
97:             BAUD_RATE   => BAUD_RATE,
98:             DATA_BITS   => DATA_BITS,
99:             PARITY_EN   => PARITY_EN,
100:            PARITY_ODD  => false
101:        )
102:        port map (
103:            clk           => CLOCK_50,
104:            rst_n         => rst_n,
105:            rx            => rx_mux_in,
106:            rx_data       => rx_data_out,
107:            rx_done       => rx_done_pulse,
108:            frame_err     => rx_frame_err,
109:            parity_err    => rx_parity_err,
110:            fsm_state_dbg => fsm_dbg
111:        );
```
* **Dòng 94-111:** Khởi tạo (instantiate) thực thể lõi `uart_rx`:
  * Nối xung clock `CLOCK_50`, reset `rst_n`.
  * Nối đường vào thu từ ngõ ra của bộ đa hợp `rx_mux_in`.
  * Đón nhận các tín hiệu đầu ra `rx_data_out`, `rx_done_pulse`, cờ lỗi và bus trạng thái FSM.

```vhdl
116:     process(CLOCK_50, rst_n)
117:     begin
118:         if rst_n = '0' then
119:             data_latch      <= (others => '0');
120:             frame_err_latch <= '0';
121:             tx_start_sig    <= '0';
122:             tx_data_reg     <= (others => '0');
123:         elsif rising_edge(CLOCK_50) then
124:             tx_start_sig <= '0';
125: 
126:             if rx_done_pulse = '1' then
127:                 data_latch <= rx_data_out;
128:                 if SW(17) = '0' and tx_busy_sig = '0' then
129:                     tx_data_reg  <= rx_data_out;
130:                     tx_start_sig <= '1';
131:                 end if;
132:             end if;
133: 
134:             if key2_press = '1' and tx_busy_sig = '0' then
135:                 tx_data_reg  <= SW(7 downto 0);
136:                 tx_start_sig <= '1';
137:             end if;
138: 
139:             if KEY(1) = '0' then
140:                 frame_err_latch <= '0';
141:             elsif rx_frame_err = '1' then
142:                 frame_err_latch <= '1';
143:             end if;
144:         end if;
145:     end process;
```
* **Dòng 116-124:** Tiến trình tuần tự đồng bộ theo cạnh lên của xung clock $50\text{ MHz}$. Mặc định mỗi chu kỳ xung `tx_start_sig` được xóa về '0' để chỉ tạo xung rộng 1 chu kỳ.
* **Dòng 126-132:** Khi nhận xong 1 byte hợp lệ (`rx_done_pulse = '1'`):
  * Nạp ngay byte vừa nhận vào thanh ghi `data_latch` để hiển thị ra LED.
  * Nếu đang ở chế độ PC ngoài (`SW(17) = '0'`), nạp byte vào `tx_data_reg` và bật `tx_start_sig = '1'` để truyền Echo ngược lại PC.
* **Dòng 134-137:** Khi người dùng bấm nút `KEY(2)` (`key2_press = '1'`) và bộ phát rảnh (`tx_busy_sig = '0'`):
  * Nạp giá trị từ 8 công tắc `SW(7 downto 0)` vào thanh ghi phát `tx_data_reg`.
  * Tạo xung `tx_start_sig = '1'` để kích hoạt phát.
* **Dòng 139-143:** Cơ chế chốt cờ lỗi khung (RS Latch bằng thanh ghi):
  * Bấm nút `KEY(1)` (`KEY(1) = '0'`): Xóa cờ lỗi về 0.
  * Khi `rx_frame_err = '1'`: Bật cờ lỗi lên 1 và giữ nguyên cho đến khi được xóa.

```vhdl
148:     u_uart_tx : entity work.uart_tx
149:         generic map (CLK_FREQ => CLK_FREQ, BAUD_RATE => BAUD_RATE)
150:         port map (
151:             clk => CLOCK_50, rst_n => rst_n,
152:             tx_start => tx_start_sig, tx_data => tx_data_reg,
153:             tx => tx_serial_out, tx_busy => tx_busy_sig
154:         );
155: 
156:     u_pulse_stretcher : entity work.pulse_stretcher
157:         generic map (PULSE_CLOCKS => CLK_FREQ / 10)
158:         port map (
159:             clk => CLOCK_50, rst_n => rst_n,
160:             pulse_in => rx_done_pulse, pulse_out => led8_stretched
161:         );
162: 
163:     u_hex0 : entity work.hex_to_7seg
164:         port map (hex_digit => data_latch(3 downto 0), seg => HEX0);
165: 
166:     u_hex1 : entity work.hex_to_7seg
167:         port map (hex_digit => data_latch(7 downto 4), seg => HEX1);
```
* **Dòng 148-154:** Khởi tạo khối phát `uart_tx` để phục vụ Echo và phát On-board.
* **Dòng 156-161:** Khởi tạo khối `pulse_stretcher`: `PULSE_CLOCKS = CLK_FREQ / 10` = $5\,000\,000$ chu kỳ tương đương thời gian sáng $100\text{ ms}$.
* **Dòng 163-167:** Khởi tạo 2 bộ giải mã LED 7 thanh:
  * `u_hex0` giải mã 4 bit thấp (Nibble thấp: bit 3..0).
  * `u_hex1` giải mã 4 bit cao (Nibble cao: bit 7..4).

```vhdl
172:     LEDR(7 downto 0)   <= data_latch;
173:     LEDR(8)            <= led8_stretched;
174:     LEDR(9)            <= frame_err_latch;
175:     LEDR(12 downto 10) <= fsm_dbg(2 downto 0);
176:     LEDR(15 downto 13) <= (others => '0');
177:     LEDR(16)           <= tx_busy_sig;
178:     LEDR(17)           <= SW(17);
```
* **Dòng 172-178:** Ánh xạ các tín hiệu hiển thị ra toàn bộ dãy 18 LED đỏ `LEDR`:
  * `LEDR[7..0]`: 8 bit dữ liệu vừa nhận được.
  * `LEDR[8]`: Xung nháy 100 ms báo nhận thành công byte.
  * `LEDR[9]`: Cờ báo lỗi khung truyền (Stop bit sai).
  * `LEDR[12..10]`: 3 bit mã hóa trạng thái hiện tại của FSM Moore.
  * `LEDR[15..13]`: Các chân dự phòng được gán mức '0' (tắt).
  * `LEDR[16]`: Đèn báo khối phát UART TX đang bận (`tx_busy`).
  * `LEDR[17]`: Đèn báo chế độ On-Board Test Mode đang BẬT (`SW[17] = '1'`).

---

## 2. KHỐI NHÂN THU UART RECEIVER: `rtl/uart_rx.vhd`

Đây là khối lõi quan trọng nhất của đề tài, thực hiện lấy mẫu quá mức 16x và điều khiển luồng giải mã tuần tự bằng máy trạng thái hữu hạn Moore.

```vhdl
54: constant BAUD_DIVISOR : natural := (CLK_FREQ + (8 * BAUD_RATE)) / (16 * BAUD_RATE);
```
* **Dòng 54:** Công thức số học tính toán hệ số chia tần số cho bộ tạo xung lấy mẫu 16x:
  $$\text{BAUD\_DIVISOR} = \frac{50\,000\,000 + 8 \times 115\,200}{16 \times 115\,200} = \frac{50\,921\,600}{1\,843\,200} = 27$$
  Phần tử tử số cộng thêm nửa mẫu số $(8 \times R_b)$ thực hiện phép làm tròn số học (Rounding), giúp giảm thiểu tối đa sai số lượng tử hóa định thời xuống chỉ còn $+0.469\%$.

```vhdl
59: type state_type is (
60:     S_IDLE,    -- Chờ phát hiện cạnh xuống của Start bit
61:     S_START,   -- Đếm 8 ticks (tâm Start bit) và kiểm tra nhiễu
62:     S_DATA,    -- Lấy mẫu 8 bit dữ liệu tại tâm mỗi bit (mỗi 16 ticks)
63:     S_PARITY,  -- Lấy mẫu và kiểm tra bit Parity (nếu được bật)
64:     S_STOP,    -- Lấy mẫu Stop bit tại tâm (16 ticks) và kiểm tra lỗi khung
65:     S_DONE     -- Phát xung rx_done trong đúng 1 chu kỳ clock
66: );
```
* **Dòng 59-66:** Định nghĩa kiểu liệt kê `state_type` gồm 6 trạng thái độc lập của máy FSM Moore.

```vhdl
120: process(clk, rst_n)
121: begin
122:     if rst_n = '0' then
123:         rx_sync_stage1 <= '1';
124:         rx_sync        <= '1';
125:         rx_prev        <= '1';
126:     elsif rising_edge(clk) then
127:         rx_sync_stage1 <= rx;
128:         rx_sync        <= rx_sync_stage1;
129:         rx_prev        <= rx_sync;
130:     end if;
131: end process;
132: 
133: rx_falling_edge <= '1' when (rx_prev = '1' and rx_sync = '0') else '0';
```
* **Dòng 120-131:** **Bộ đồng bộ hóa 2 tầng D Flip-Flop (Two-Stage Synchronizer):**
  * Tín hiệu `rx` từ bên ngoài là bất đồng bộ đối với xung clock $50\text{ MHz}$ của FPGA.
  * Tầng 1 (`rx_sync_stage1`) có thể rơi vào vùng bất định (Metastability) nếu vi phạm thời gian $t_{su}/t_h$.
  * Tầng 2 (`rx_sync`) lấy mẫu sau 1 chu kỳ clock đầy đủ ($20\text{ ns}$), cho phép điện áp sụp đổ về mức logic ổn định tuyệt đối, nâng chỉ số MTBF lên mức hàng triệu năm.
  * Tầng 3 (`rx_prev`) lưu giữ giá trị của chu kỳ trước đó.
* **Dòng 133:** `rx_falling_edge`: Phát hiện cạnh xuống của Start bit khi chu kỳ trước là '1' và chu kỳ này sụt xuống '0'.

```vhdl
141: process(clk, rst_n)
142: begin
143:     if rst_n = '0' then
144:         baud_counter  <= 0;
145:         baud_tick_16x <= '0';
146:     elsif rising_edge(clk) then
147:         if state_reg = S_IDLE and rx_falling_edge = '1' then
148:             baud_counter  <= 0;
149:             baud_tick_16x <= '0';
150:         elsif baud_counter = BAUD_DIVISOR - 1 then
151:             baud_counter  <= 0;
152:             baud_tick_16x <= '1';
153:         else
154:             baud_counter  <= baud_counter + 1;
155:             baud_tick_16x <= '0';
156:         end if;
157:     end if;
158: end process;
```
* **Dòng 141-158:** **Bộ phát xung lấy mẫu Baud Rate Generator (16x):**
  * Bộ đếm `baud_counter` đếm tuần hoàn từ `0` đến `BAUD_DIVISOR - 1` (tức 26). Mỗi khi đạt 26, sinh ra một xung `baud_tick_16x = '1'` rộng đúng 1 chu kỳ clock.
  * **Cực kỳ quan trọng (Dòng 147-149):** Khi FSM đang ở `S_IDLE` và bắt được cạnh xuống của Start bit, bộ đếm bị **xóa về 0 tức thời**. Thao tác này giúp tái đồng pha (Phase Resynchronization) ngay tại sườn bắt đầu của Start bit, triệt tiêu hoàn toàn sai lệch pha ngẫu nhiên trước đó.

```vhdl
164: process(clk, rst_n)
165: begin
166:     if rst_n = '0' then
167:         state_reg      <= S_IDLE;
168:         tick_cnt_reg   <= 0;
169:         bit_cnt_reg    <= 0;
170:         data_reg       <= (others => '0');
171:         rx_data_reg    <= (others => '0');
172:         frame_err_reg  <= '0';
173:         parity_err_reg <= '0';
174:     elsif rising_edge(clk) then
175:         state_reg      <= state_next;
176:         tick_cnt_reg   <= tick_cnt_next;
177:         bit_cnt_reg    <= bit_cnt_next;
178:         data_reg       <= data_next;
179:         frame_err_reg  <= frame_err_next;
180:         parity_err_reg <= parity_err_next;
181:         if state_next = S_DONE then
182:             rx_data_reg <= data_next;
183:         end if;
184:     end if;
185: end process;
```
* **Dòng 164-185:** Tiến trình đồng bộ thanh ghi (State & Data Register):
  * Chuyển các giá trị kế tiếp (`*_next`) vào các thanh ghi hiện tại (`*_reg`) tại mỗi cạnh lên của xung clock.
  * Khi chuyển trạng thái sang `S_DONE`, chốt dữ liệu cuối cùng vào `rx_data_reg` để đưa ra ngoài ổn định.

```vhdl
195: process(state_reg, rx_falling_edge, rx_sync, baud_tick_16x,
196:         tick_cnt_reg, bit_cnt_reg, data_reg, parity_calc)
197: begin
198:     state_next      <= state_reg;
199:     tick_cnt_next   <= tick_cnt_reg;
200:     bit_cnt_next    <= bit_cnt_reg;
201:     data_next       <= data_reg;
202:     frame_err_next  <= '0';
203:     parity_err_next <= '0';
```
* **Dòng 195-205:** Tiến trình tổ hợp tính toán trạng thái kế tiếp (Next-State Logic).
* **Quy tắc thiết kế RTL (Dòng 198-204):** Mọi tín hiệu đều được gán giá trị mặc định ngay đầu tiến trình. Điều này đảm bảo công cụ tổng hợp Quartus không bao giờ suy luận ra chốt nhớ bất định (Latch-Free Design).

```vhdl
211:     when S_IDLE =>
212:         tick_cnt_next <= 0;
213:         bit_cnt_next  <= 0;
214:         if rx_falling_edge = '1' then
215:             state_next <= S_START;
216:         end if;
```
* **Dòng 211-216:** `S_IDLE`: Trạng thái nghỉ. Đường truyền ở mức '1'. Khi phát hiện cạnh xuống (`rx_falling_edge = '1'`), chuyển sang trạng thái `S_START`.

```vhdl
221:     when S_START =>
222:         if baud_tick_16x = '1' then
223:             if tick_cnt_reg = 7 then
224:                 if rx_sync = '0' then
225:                     tick_cnt_next <= 0;
226:                     bit_cnt_next  <= 0;
227:                     state_next    <= S_DATA;
228:                 else
229:                     state_next <= S_IDLE;
230:                 end if;
231:             else
232:                 tick_cnt_next <= tick_cnt_reg + 1;
233:             end if;
234:         end if;
```
* **Dòng 221-237:** `S_START` (Cơ chế chống nhiễu Glitch Rejection):
  * Một bit trong chuẩn 16x kéo dài đúng 16 tick lấy mẫu (từ tick 0 đến tick 15). Tâm của bit nằm tại vị trí tick thứ 7 (8 tick đầu tiên).
  * Tại tick thứ 7:
    * Nếu `rx_sync = '0'`: Start bit hoàn toàn hợp lệ $\rightarrow$ reset bộ đếm và chuyển sang `S_DATA`.
    * Nếu `rx_sync = '1'`: Tín hiệu đã nhảy về 1 trước khi tới giữa bit. Đây là một xung nhiễu gai (Glitch) có độ rộng $< 4.34\,\mu\text{s}$ $\rightarrow$ FSM lập tức hủy bỏ và quay về `S_IDLE`, không nhận dữ liệu rác.

```vhdl
242:     when S_DATA =>
243:         if baud_tick_16x = '1' then
244:             if tick_cnt_reg = 15 then
245:                 tick_cnt_next <= 0;
246:                 data_next(bit_cnt_reg) <= rx_sync;
247:                 if bit_cnt_reg = DATA_BITS - 1 then
248:                     if PARITY_EN then
249:                         state_next <= S_PARITY;
250:                     else
251:                         state_next <= S_STOP;
252:                     end if;
253:                 else
254:                     bit_cnt_next <= bit_cnt_reg + 1;
255:                 end if;
256:             else
257:                 tick_cnt_next <= tick_cnt_reg + 1;
258:             end if;
259:         end if;
```
* **Dòng 242-260:** `S_DATA`: Lấy mẫu 8 bit dữ liệu:
  * Sau mỗi 16 tick lấy mẫu (`tick_cnt_reg = 15`), mạch định vị chính xác vị trí tâm của bit dữ liệu tiếp theo (Center Sampling).
  * `data_next(bit_cnt_reg) <= rx_sync`: Nạp giá trị mức logic vào mảng dữ liệu. Thứ tự nạp từ bit 0 đến bit 7 (LSB First đúng chuẩn UART).
  * Khi nạp đủ 8 bit (`bit_cnt_reg = 7`), chuyển sang trạng thái kiểm tra Stop bit (`S_STOP`).

```vhdl
282:     when S_STOP =>
283:         if baud_tick_16x = '1' then
284:             if tick_cnt_reg = 15 then
285:                 tick_cnt_next <= 0;
286:                 if rx_sync = '1' then
287:                     state_next <= S_DONE;
288:                 else
289:                     frame_err_next <= '1';
290:                     state_next     <= S_IDLE;
291:                 end if;
292:             else
293:                 tick_cnt_next <= tick_cnt_reg + 1;
294:             end if;
295:         end if;
```
* **Dòng 282-297:** `S_STOP`: Kiểm tra tính toàn vẹn của Stop bit:
  * Đếm 16 tick đến tâm Stop bit.
  * Nếu `rx_sync = '1'`: Stop bit hợp lệ $\rightarrow$ chuyển sang `S_DONE` để hoàn tất.
  * Nếu `rx_sync = '0'`: Xảy ra lỗi khung truyền (Framing Error) $\rightarrow$ kích hoạt cờ `frame_err_next <= '1'` và hủy bỏ khung truyền, quay về `S_IDLE`.

```vhdl
302:     when S_DONE =>
303:         state_next <= S_IDLE;
```
* **Dòng 302-304:** `S_DONE`: Trạng thái kết thúc. Chỉ lưu lại đúng 1 chu kỳ clock rồi lập tức quay về `S_IDLE` để sẵn sàng nhận byte tiếp theo.

```vhdl
315: rx_done    <= '1' when (state_reg = S_DONE) else '0';
316: rx_data    <= rx_data_reg;
317: frame_err  <= frame_err_reg;
318: parity_err <= parity_err_reg;
```
* **Dòng 315-318:** **Đầu ra chuẩn Moore (Moore Outputs):**
  * Tín hiệu `rx_done` chỉ tích cực lên '1' khi FSM đang ở trạng thái `S_DONE`. Vì `S_DONE` chỉ tồn tại 1 chu kỳ clock, nên `rx_done` là một xung chuẩn có độ rộng đúng 1 chu kỳ clock ($20\text{ ns}$).

---

## 3. KHỐI PHÁT UART TRANSMITTER: `rtl/uart_tx.vhd`

Khối phát đảm nhận nhiệm vụ chuyển đổi dữ liệu song song 8-bit thành dòng bit nối tiếp tuần tự đưa ra chân `tx`.

```vhdl
33: constant BAUD_DIVISOR : natural := (CLK_FREQ + (BAUD_RATE / 2)) / BAUD_RATE;
```
* **Dòng 33:** Hệ số chia tần số cho khối phát (lấy mẫu 1x):
  $$\text{BAUD\_DIVISOR} = \frac{50\,000\,000 + 57\,600}{115\,200} \approx 434\text{ chu kỳ clock/bit}$$

```vhdl
86: when S_START =>
87:     tx_next <= '0'; -- Phát Start bit mức 0
88:     if baud_cnt_reg = BAUD_DIVISOR - 1 then
89:         baud_cnt_next <= 0;
90:         bit_cnt_next  <= 0;
91:         state_next    <= S_DATA;
92:     else
93:         baud_cnt_next <= baud_cnt_reg + 1;
94:     end if;
```
* **Dòng 86-95:** Phát Start bit: Kéo đường truyền xuống mức '0' trong suốt 434 chu kỳ clock, sau đó chuyển sang `S_DATA`.

```vhdl
96: when S_DATA =>
97:     tx_next <= shift_reg(bit_cnt_reg); -- Đẩy bit ra ngoài (LSB trước)
98:     if baud_cnt_reg = BAUD_DIVISOR - 1 then
99:         baud_cnt_next <= 0;
100:        if bit_cnt_reg = 7 then
101:            state_next <= S_STOP;
102:        else
103:            bit_cnt_next <= bit_cnt_reg + 1;
104:        end if;
105:    else
106:        baud_cnt_next <= baud_cnt_reg + 1;
107:    end if;
```
* **Dòng 96-108:** Phát tuần tự 8 bit dữ liệu:
  * Mỗi bit được giữ ổn định trong 434 chu kỳ clock.
  * Lần lượt đẩy từ bit 0 (`shift_reg(0)`) đến bit 7 (`shift_reg(7)`).

```vhdl
109: when S_STOP =>
110:     tx_next <= '1'; -- Stop bit ở mức 1
111:     if baud_cnt_reg = BAUD_DIVISOR - 1 then
112:         baud_cnt_next <= 0;
113:         state_next    <= S_IDLE;
114:     else
115:         baud_cnt_next <= baud_cnt_reg + 1;
116:     end if;
```
* **Dòng 109-117:** Phát Stop bit mức '1' trong 434 chu kỳ clock để kết thúc khung truyền.

```vhdl
124: tx_busy <= '0' when (state_reg = S_IDLE) else '1';
```
* **Dòng 124:** Cờ báo bận: Chỉ về mức 0 khi ở trạng thái nghỉ `S_IDLE`. Khi đang phát bất kỳ bit nào, cờ giữ ở mức '1' để ngăn chặn phát chồng chéo dữ liệu.

---

## 4. KHỐI GIẢI MÃ LED 7 THANH: `rtl/hex_to_7seg.vhd`

Bộ giải mã tổ hợp thuần túy chuyển đổi mã 4-bit Hexa (0-F) sang điều khiển 7 thanh LED.

```vhdl
20: hex_digit : in  std_logic_vector(3 downto 0);
21: seg       : out std_logic_vector(6 downto 0)
```
* **Dòng 20-21:** Đầu vào là số 4-bit ($0$ đến $15$), đầu ra là vector 7 đoạn theo thứ tự: `seg[6..0] = g, f, e, d, c, b, a`.

```vhdl
30: case hex_digit is
31:     --                              gfedcba
32:     when x"0"   => seg <= "1000000"; -- '0': Sáng a,b,c,d,e,f (Tắt g)
33:     when x"1"   => seg <= "1111001"; -- '1': Sáng b,c
34:     when x"2"   => seg <= "0100100"; -- '2': Sáng a,b,d,e,g
...
43:     when x"A"   => seg <= "0001000"; -- 'A': Sáng a,b,c,e,f,g
...
47:     when x"F"   => seg <= "0001110"; -- 'F': Sáng a,e,f,g
48:     when others => seg <= "1111111"; -- Tắt toàn bộ
```
* **Dòng 30-49:** Bảng chân lý giải mã Anode chung (**Active-Low**):
  * Mức logic `'0'` = Bật sáng LED.
  * Mức logic `'1'` = Tắt LED.
  * Ví dụ số `0`: Cần sáng 6 đoạn $a, b, c, d, e, f$ và tắt đoạn giữa $g$, do đó vector là `"1000000"` (bit 6 = 1, các bit khác = 0).

---

## 5. KHỐI KÉO DÀI XUNG HIỂN THỊ: `rtl/pulse_stretcher.vhd`

Khối mạch giải quyết bài toán chênh lệch thang đo thời gian giữa thế giới vi mạch nano-giây và thị giác con người.

```vhdl
19: generic (
20:     PULSE_CLOCKS : natural := 5_000_000
21: );
```
* **Dòng 20:** Tham số $5\,000\,000$ chu kỳ clock:
  $$t_{\text{pulse}} = 5\,000\,000 \times 20\text{ ns} = 100\text{ ms} = 0.1\text{ giây}$$

```vhdl
37: process(clk, rst_n)
38: begin
39:     if rst_n = '0' then
40:         counter_reg <= 0;
41:     elsif rising_edge(clk) then
42:         if pulse_in = '1' then
43:             counter_reg <= PULSE_CLOCKS;
44:         elsif counter_reg > 0 then
45:             counter_reg <= counter_reg - 1;
46:         end if;
47:     end if;
48: end process;
49: 
50: pulse_out <= '1' when (counter_reg > 0) else '0';
```
* **Dòng 37-48:** Tiến trình đếm lùi (Down-Counter):
  * Khi có xung đầu vào `pulse_in = '1'` (chỉ kéo dài 20 ns từ `rx_done`), bộ đếm được nạp tức thì giá trị cực đại $5\,000\,000$.
  * Trong các chu kỳ tiếp theo, bộ đếm giảm dần từng đơn vị về 0.
* **Dòng 50:** Trong suốt thời gian bộ đếm đang giảm từ $5\,000\,000$ về $1$, đầu ra `pulse_out` được giữ nguyên ở mức logic `'1'`, giúp mắt người nhìn thấy đèn LED nhấp nháy rõ ràng, mượt mà.
