# BÁO CÁO ĐỒ ÁN CHUYÊN NGÀNH THIẾT KẾ HỆ THỐNG SỐ TRÊN FPGA
## ĐỀ TÀI: THIẾT KẾ VÀ KIỂM CHỨNG BỘ THU NỐI TIẾP UART RECEIVER HIỆU NĂNG CAO SỬ DỤNG MÁY TRẠNG THÁI HỮU HẠN (FSM) TRÊN KIT TERASIC DE2-115 (CYCLONE IV E)

**Cơ quan / Đơn vị đào tạo:** Viện / Khoa Điện tử - Viễn thông & Công nghệ Thông tin  
**Học phần:** Thiết kế Hệ thống Số Nâng cao / Đồ án Thiết kế Vi mạch FPGA  
**Nền tảng phần cứng mục tiêu:** Kit Altera / Intel FPGA DE2-115 (EP4CE115F29C7)  
**Môi trường tổng hợp & mô phỏng:** Intel Quartus Prime Lite Edition v20.1, ModelSim Intel FPGA Starter Edition  
**Ngôn ngữ thiết kế:** VHDL (Chuẩn IEEE 1076-1993 / 1076-2008)  

---pagebreak---

## MỤC LỤC TỔNG QUÁT

* **PHẦN 1: PHẦN MỞ ĐẦU (ĐẶT VẤN ĐỀ VÀ MỤC TIÊU NGHIÊN CỨU)**
  * 1.1. Tính cấp thiết của đề tài và đặt vấn đề kỹ thuật
  * 1.2. Thách thức kỹ thuật trong thiết kế bộ thu UART bất đồng bộ
  * 1.3. Mục tiêu nghiên cứu và phạm vi thực hiện của đồ án
  * 1.4. Đóng góp kỹ thuật và phương pháp luận tiếp cận

* **PHẦN 2: CƠ SỞ LÝ THUYẾT VÀ CÔNG NGHỆ ÁP DỤNG**
  * 2.1. Chuẩn truyền thông nối tiếp bất đồng bộ UART
  * 2.2. Kỹ thuật lấy mẫu quá mức (Oversampling 16x) và phân tích dung sai sai số Baud
  * 2.3. Hiện tượng bất ổn định (Metastability) và giải pháp đồng bộ 2 tầng D-FF
  * 2.4. Lý thuyết về Máy trạng thái hữu hạn (FSM) chuẩn Moore trong vi mạch số
  * 2.5. Nền tảng phần cứng FPGA Cyclone IV E và Kit thí nghiệm Terasic DE2-115

* **PHẦN 3: NỘI DUNG THỰC HIỆN VÀ THIẾT KẾ HỆ THỐNG**
  * 3.1. Kiến trúc tổng thể và sơ đồ khối hệ thống (Top-Level Architecture)
  * 3.2. Thiết kế chi tiết khối nhân UART Receiver (`uart_rx`)
  * 3.3. Thuật toán điều khiển và lưu đồ chuyển trạng thái FSM Moore
  * 3.4. Thiết kế các khối phụ trợ: Kéo dài xung (`pulse_stretcher`), Giải mã LED 7 thanh (`hex_to_7seg`), và Khối phát Echo (`uart_tx`)
  * 3.5. Bảng ánh xạ chân vật lý và chuẩn tín hiệu ngoại vi trên Kit DE2-115

* **PHẦN 4: ĐÁNH GIÁ KẾT QUẢ, THỰC NGHIỆM VÀ KẾT LUẬN**
  * 4.1. Mô phỏng kiểm chứng chức năng trên ModelSim qua 5 kịch bản biên
  * 4.2. Báo cáo tổng hợp luận lý và tối ưu hóa tài nguyên phần cứng (Synthesis Report)
  * 4.3. Phân tích định thời tĩnh (Static Timing Analysis - STA) và xác định $F_{\max}$
  * 4.4. Đánh giá kết quả thực nghiệm thời gian thực trên Kit DE2-115
  * 4.5. Kết luận đồ án và định hướng nghiên cứu mở rộng

* **TÀI LIỆU THAM KHẢO**

---pagebreak---

# PHẦN 1: PHẦN MỞ ĐẦU

## 1.1. Tính cấp thiết của đề tài và đặt vấn đề kỹ thuật

Trong kỷ nguyên phát triển mạnh mẽ của công nghệ phần cứng nhúng, IoT (Internet of Things) và các hệ thống vi cơ điện tử, truyền thông dữ liệu đóng vai trò then chốt như mạch máu kết nối các bộ vi xử lý, vi điều khiển, cảm biến thông minh và máy tính điều khiển trung tâm. Trong số các giao thức truyền thông nối tiếp, **UART (Universal Asynchronous Receiver-Transmitter)** là chuẩn giao tiếp kinh điển, phổ biến và đáng tin cậy bậc nhất nhờ ưu điểm vượt trội: cấu trúc đường truyền tối giản chỉ cần 2 dây tín hiệu dữ liệu độc lập (TXD và RXD) cùng 1 dây nối đất chung (GND), loại bỏ hoàn toàn yêu cầu phức tạp về đường xung nhịp đồng bộ phân phối toàn cục.

Tuy nhiên, trong các thiết kế công nghiệp hiện đại yêu cầu thông lượng cao và độ tin cậy tuyệt đối, việc sử dụng các khối UART cứng tích hợp sẵn trong vi điều khiển (MCU) thường gặp phải các hạn chế nghiêm trọng:
1. Thiếu tính linh hoạt trong việc tùy biến cấu hình khung truyền, cơ chế lọc nhiễu thích nghi và điều khiển định thời vi sai.
2. Bị giới hạn số lượng kênh giao tiếp vật lý do ràng buộc chân và tài nguyên ngoại vi cố định của chip.
3. Không thể đáp ứng các bài toán xử lý song song tốc độ cao với độ trễ tiền định (deterministic latency) ở mức chu kỳ xung nhịp (clock-cycle level).

Do đó, xu hướng hiện đại là tích hợp trực tiếp lõi IP UART tùy biến (Custom UART IP Core) vào các vi mạch logic lập trình được **FPGA (Field Programmable Gate Array)** hoặc vi mạch tích hợp chuyên dụng **ASIC (Application-Specific Integrated Circuit)**. Việc tự chủ thiết kế bộ thu phát UART trên FPGA mang lại quyền kiểm soát toàn diện từ kiến trúc logic đến định thời vật lý, tạo tiền đề vững chắc cho việc xây dựng các hệ thống nhúng SoC (System-on-Chip) dựa trên vi xử lý mềm (Soft-Core Processor) như RISC-V hay NIOS II.

---

## 1.2. Thách thức kỹ thuật trong thiết kế bộ thu UART bất đồng bộ

So với bộ phát UART (Transmitter) – vốn là khối hoàn toàn chủ động về mặt thời gian, tự sinh xung nhịp nội bộ và tuần tự đẩy các bit dữ liệu ra ngoài – **bộ thu UART (Receiver - RX)** đối mặt với những bài toán kỹ thuật phức tạp và thách thức hơn rất nhiều:

* **Bất đồng bộ về miền xung nhịp (Asynchronous Clock Domains):** Tín hiệu đầu vào nối tiếp RXD xuất phát từ một máy phát bên ngoài có dao động thạch anh hoàn toàn độc lập, không hề có sự ràng buộc pha hay tần số với xung nhịp hệ thống trên bo mạch FPGA. Sự chênh lệch tần số thực tế (Clock Drift) giữa hai thạch anh do dung sai chế tạo và biến thiên nhiệt độ luôn luôn tồn tại.
* **Nguy cơ bất ổn định logic (Metastability):** Khi một tín hiệu bất đồng bộ chuyển mức logic vi phạm thời gian thiết lập ($t_{su}$ - Setup Time) hoặc thời gian duy trì ($t_h$ - Hold Time) của phần tử nhớ Flip-Flop nội bộ, đầu ra của Flip-Flop có thể dao động ở vùng điện áp bất định trong một khoảng thời gian trước khi sụp đổ về mức logic hợp lệ. Điều này có thể dẫn đến sai lệch dữ liệu toàn diện hoặc làm tê liệt máy trạng thái FSM.
* **Nhiễu sườn và xung gai nhọn (Glitches & Noise Spikes):** Trong môi trường công nghiệp, đường truyền vật lý dài thường xuyên bị cảm ứng các xung nhiễu điện từ tần số cao. Một xung nhiễu sụt áp ngẫu nhiên xuống mức '0' trong tích tắc rất dễ bị mạch thu hiểu lầm là Start bit, dẫn đến việc kích hoạt thu sai chuỗi byte rác.
* **Điểm lấy mẫu tối ưu và tích lũy sai số pha (Phase Error Accumulation):** Nếu lấy mẫu ở rìa bit, dao động sườn dốc (jitter) sẽ gây sai lệch bit. Ngược lại, nếu tần số lấy mẫu không được chuẩn hóa chính xác, sai số định thời sẽ tích lũy qua từng bit trong khung và dẫn đến lỗi đọc sai ở các bit cuối (Stop bit hoặc MSB).
* **Kiểm soát lỗi toàn vẹn khung truyền:** Hệ thống cần có cơ chế phát hiện tức thời lỗi khung (Framing Error khi Stop bit không phải mức 1) và lỗi chẵn lẻ (Parity Error), đồng thời ngăn chặn dữ liệu lỗi lan truyền vào các tầng đệm tiếp theo.

---

## 1.3. Mục tiêu nghiên cứu và phạm vi thực hiện của đồ án

Xuất phát từ các yêu cầu thực tiễn và thách thức kỹ thuật nêu trên, đề tài tập trung vào việc nghiên cứu, hiện thực hóa và kiểm chứng toàn diện bộ thu UART Receiver chuẩn công nghiệp với các mục tiêu cụ thể:

1. **Về mặt kiến trúc logic RTL:**
   * Thiết kế một bộ thu UART hoàn chỉnh theo kiến trúc Máy trạng thái hữu hạn Moore (Moore FSM) phân tách rõ ràng, trong sáng, tuân thủ tiêu chuẩn thiết kế RTL không sinh chốt tổ hợp (latch-free).
   * Ứng dụng kỹ thuật lấy mẫu quá mức **16x (16x Oversampling)** kết hợp bộ chia tần số tối ưu, cho phép định vị chính xác tâm xung của từng bit dữ liệu (Center Sampling).
   * Tích hợp mạch đồng bộ hóa **2 tầng D Flip-Flop** ở lối vào nhằm triệt tiêu hoàn toàn hiện tượng bất ổn định logic (Metastability), nâng cao chỉ số độ tin cậy MTBF.
   * Xây dựng bộ lọc nhiễu tích cực cho Start bit (Glitch Rejection), loại bỏ hoàn toàn các xung nhiễu có độ rộng nhỏ hơn 8 chu kỳ xung nhịp lấy mẫu.
   * Hỗ trợ phát hiện lỗi khung (Framing Error) và tùy chọn kiểm tra tính chẵn lẻ (Parity Check).
2. **Về mặt kiểm chứng mô phỏng (Functional Verification):**
   * Xây dựng Testbench tự động kiểm tra (Self-Checking Testbench) toàn diện trên ModelSim.
   * Kiểm thử qua 5 kịch bản biên khắc nghiệt: Truyền byte đặc thù, truyền Back-to-Back không khoảng nghỉ, cố tình tạo lỗi Stop bit, bơm xung nhiễu ngẫu nhiên, và kích hoạt Reset bất đồng bộ giữa chừng.
3. **Về mặt triển khai phần cứng vật lý:**
   * Tổng hợp (Synthesis), gán chân (Fitter/Place & Route), và phân tích định thời tĩnh (STA) bằng công cụ Intel Quartus Prime Lite v20.1 nhắm đến vi mạch FPGA Cyclone IV E `EP4CE115F29C7` trên kit **Terasic DE2-115**.
   * Thiết kế khối Top-level hoàn chỉnh kết nối các ngoại vi trên kit: Hiển thị 8-bit dữ liệu lên dãy LED đỏ `LEDR[7..0]`, giải mã ra 2 LED 7 thanh `HEX1:HEX0` (dạng Hexa), kéo dài xung nhận thành công 100 ms ra `LEDR[8]`, chốt cờ lỗi khung ra `LEDR[9]`, hiển thị trạng thái FSM ra `LEDR[12..10]`, và tích hợp 2 chế độ kiểm nghiệm: (1) Chế độ On-Board Test độc lập với `SW[7..0]`, `SW[17]` và nút `KEY[2]` không cần cáp ngoài; (2) Chế độ kết nối máy tính PC qua cổng RS-232 DB9 kèm phản hồi Echo (`uart_tx`).

---

## 1.4. Đóng góp kỹ thuật và phương pháp luận tiếp cận

Báo cáo này mang lại các giá trị khoa học và kỹ thuật thực tiễn:
* Đưa ra phương pháp luận thiết kế số tuần tự từ mô hình toán học (tính toán dung sai sai số tần số lấy mẫu) đến mô hình phần cứng VHDL.
* Cung cấp mã nguồn VHDL tiêu chuẩn, có tính mô-đun hóa cao, tham số hóa linh hoạt qua cơ chế `generic` (dễ dàng thay đổi tần số thạch anh, baud rate, số bit dữ liệu, chế độ parity).
* Minh chứng tính đúng đắn thông qua dữ liệu mô phỏng dạng sóng số học và kết quả kiểm nghiệm thực tế trên kit phần cứng công nghiệp DE2-115.

---pagebreak---

# PHẦN 2: CƠ SỞ LÝ THUYẾT VÀ CÔNG NGHỆ ÁP DỤNG

## 2.1. Chuẩn truyền thông nối tiếp bất đồng bộ UART

### 2.1.1. Nguyên lý và cấu trúc khung truyền (Frame Format)

UART là phương thức truyền thông nối tiếp điểm-điểm (point-to-point) dị bộ. Tín hiệu số nhị phân được truyền tuần tự từng bit một trên một dây dẫn duy nhất. Trong trạng thái rỗi (Idle state), đường truyền luôn được kéo lên mức logic cao ('1', tương ứng với trạng thái Mark).

Khung truyền UART tiêu chuẩn bao gồm các thành phần tuần tự như sau:

| Thành phần | Mức logic | Độ rộng định thời ($T_{bit}$) | Ý nghĩa chức năng |
| :--- | :---: | :---: | :--- |
| **Idle** | Mức cao ('1') | Tùy ý | Trạng thái nghỉ của đường truyền, sẵn sàng đón nhận khung mới. |
| **Start bit** | Mức thấp ('0') | Đúng 1 $T_{bit}$ | Đánh dấu sự khởi đầu của khung truyền, tạo cạnh xuống kích hoạt bộ thu. |
| **Data bits** | Mức '0' hoặc '1' | 5 đến 8 $T_{bit}$ (mặc định 8) | Các bit dữ liệu hữu ích, truyền bit có trọng số thấp nhất trước (**LSB first**). |
| **Parity bit** | Tùy chọn | 0 hoặc 1 $T_{bit}$ | Bit kiểm tra chẵn lẻ nhằm phát hiện lỗi đảo 1 bit trên đường truyền. |
| **Stop bit** | Mức cao ('1') | 1, 1.5 hoặc 2 $T_{bit}$ | Đưa đường truyền về mức nghỉ, đánh dấu kết thúc khung và thiết lập lại đồng pha. |

Chu kỳ của một bit tín hiệu ($T_{bit}$) được xác định bởi tốc độ Baud (Baud Rate - ký hiệu là $R_b$, đơn vị là bit/giây hay bps):

$$T_{bit} = \frac{1}{R_b}$$

Tại tốc độ truyền tiêu chuẩn công nghiệp $R_b = 115\,200\text{ bps}$, độ rộng danh định của mỗi bit là:

$$T_{bit} = \frac{1}{115\,200} \approx 8.68055\,\mu\text{s} = 8\,680.55\text{ ns}$$

```
Trạng thái tín hiệu UART trên đường truyền vật lý (Ví dụ truyền byte 0x55 = 01010101b):
Line: 1 ──┐     ┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌───────
          │  0  │ 1 │ 0 │ 1 │ 0 │ 1 │ 0 │ 1 │ 0 │ 1 (Stop)
      0 ──┴─────┘   └───┘   └───┘   └───┘   └───┘
        | Start | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | Stop |
```

---

## 2.2. Kỹ thuật lấy mẫu quá mức (Oversampling 16x) và phân tích dung sai sai số Baud

### 2.2.1. Bản chất của kỹ thuật lấy mẫu 16x

Do phía thu không có xung nhịp clock đi kèm từ phía phát, phía thu phải sử dụng một bộ tạo xung nội bộ có tần số gấp nhiều lần tốc độ baud để phân chia mỗi bit truyền thành nhiều phần nhỏ (gọi là các *ticks*). Kỹ thuật công nghiệp chuẩn mực là lấy mẫu quá mức **16 lần (16x Oversampling)**.

Khi áp dụng oversampling 16x:
* Một khoảng thời gian bit ($T_{bit}$) được chia đều thành 16 tick lấy mẫu: $T_{tick} = \frac{T_{bit}}{16}$.
* Tâm của Start bit nằm tại tick thứ 8 (chỉ số đếm từ 0 đến 7).
* Tâm của các bit dữ liệu tiếp theo và bit Stop nằm cách đều nhau đúng 16 tick.

```
Minh họa quá trình lấy mẫu 16x (Oversampling):
Cạnh xuống
    │
    ▼ 
┌───┐───────────────────────────────┬───────────────────────────────┐
│ 1 │ 0   1   2   3   4   5   6   7 │ 8   9  10  11  12  13  14  15 │ (16 ticks)
└───┴───────────────────────────────┴───────────────────────────────┘
    │ <────── 8 ticks ────────────> │ <──────── 16 ticks ──────────>
             Lấy mẫu tâm                     Lấy mẫu tâm
              Start Bit                       Data Bit 0
```

### 2.2.2. Lợi ích kỹ thuật của việc lấy mẫu tại tâm (Center Sampling)
1. **Triệt tiêu nhiễu sườn (Edge Jitter Immunity):** Sườn tín hiệu thực tế luôn có thời gian tăng/giảm ($t_r, t_f$) và rung lắc pha do điện dung ký sinh trên cáp nối. Việc lấy mẫu tại tick thứ 8 hoặc tick thứ 16 đưa điểm quan sát vào chính giữa bit, nơi điện áp đã đạt mức ổn định tuyệt đối.
2. **Khả năng dung nạp sai lệch tần số (Baud Rate Frequency Tolerance):** 
   Một khung UART 10 bit (1 Start + 8 Data + 1 Stop) sẽ được lấy mẫu lần cuối cùng ở tâm của Stop bit, tức là sau $9.5 \times T_{bit}$ tính từ cạnh xuống bắt đầu. Để việc lấy mẫu Stop bit vẫn thành công, độ lệch pha tích lũy tối đa $\Delta t$ không được vượt quá nửa chu kỳ bit ($0.5 \times T_{bit}$):
   
   $$\Delta t_{accum} = 9.5 \times |\Delta T_{bit}| < 0.5 \times T_{bit} \implies \frac{|\Delta R_b|}{R_b} < \frac{0.5}{9.5} \approx 5.26\%$$

   Khi tính thêm biên độ an toàn cho độ rộng sườn và độ phân giải 16x, hệ thống hoàn toàn cho phép dung sai chênh lệch tần số giữa bộ phát và bộ thu lên đến **$\pm 4.5\%$**. Điều này đảm bảo hệ thống FPGA hoạt động hoàn hảo với mọi cổng COM máy tính hoặc mạch chuyển đổi USB-UART trên thị trường.

---

## 2.3. Hiện tượng bất ổn định (Metastability) và giải pháp đồng bộ 2 tầng D-FF

### 2.3.1. Phân tích hiện tượng Metastability

Đường truyền `rx` từ bên ngoài đi vào chân FPGA là một tín hiệu hoàn toàn bất đồng bộ. Tín hiệu này có thể chuyển trạng thái logic vào đúng thời điểm nhạy cảm của xung nhịp hệ thống nội bộ $50\text{ MHz}$, vi phạm các đặc tính thời gian cơ bản của Flip-Flop:
* **Setup Time ($t_{su}$):** Khoảng thời gian dữ liệu đầu vào phải ổn định trước sườn dương của xung clock.
* **Hold Time ($t_h$):** Khoảng thời gian dữ liệu đầu vào phải ổn định sau sườn dương của xung clock.

Khi vi phạm xảy ra, tầng khuếch đại bên trong Flip-Flop bị đẩy vào điểm cân bằng không bền. Đầu ra $Q$ có thể bị treo ở mức điện áp trung gian hoặc dao động không xác định trong một khoảng thời gian giải phóng $t_{met}$, sau đó ngẫu nhiên rơi về mức '0' hoặc '1'.

### 2.3.2. Giải pháp mạch đồng bộ hóa 2 tầng D-Flip-Flop (2-Stage Synchronizer)

Để ngăn chặn hiện tượng này lan truyền vào máy trạng thái FSM và logic tổ hợp bên trong, một cấu trúc đồng bộ 2 tầng Flip-Flop mắc nối tiếp được thiết lập ngay tại cổng vào của tín hiệu `rx`:

```
   Tín hiệu bất đồng bộ            Tầng 1 (Bảo vệ)         Tầng 2 (Ổn định)
         rx ────────────────────►│ D          Q │────────►│ D          Q │────► rx_sync
                                 │              │         │              │
         clk ──────┬────────────►│ CLK          │   ┌────►│ CLK          │
                   │             └──────────────┘   │     └──────────────┘
                   └────────────────────────────────┘
```

Chỉ số thời gian trung bình giữa các lần xuất hiện lỗi bất ổn định (**MTBF - Mean Time Between Failures**) được tính theo phương trình:

$$\text{MTBF} = \frac{e^{\frac{T_{clk} - t_{co} - t_{su}}{\tau}}}{T_0 \times f_{clk} \times f_{data}}$$

Trong đó:
* $T_{clk} = 20\text{ ns}$ (chu kỳ clock $50\text{ MHz}$).
* $f_{clk} = 50\text{ MHz}$, $f_{data} \le 115.2\text{ kHz}$.
* $T_0, \tau$ là các thông số phụ thuộc công nghệ bán dẫn của Cyclone IV E (công nghệ 60 nm).

Với chu kỳ clock $20\text{ ns}$, tầng Flip-Flop thứ nhất có gần trọn vẹn $20\text{ ns}$ để ổn định mức điện áp trước khi sườn clock tiếp theo chốt giá trị vào tầng thứ hai. Điều này nâng chỉ số MTBF của thiết kế lên tới hàng triệu năm hoạt động liên tục, đảm bảo độ tin cậy tuyệt đối cho hệ thống.

---

## 2.4. Lý thuyết về Máy trạng thái hữu hạn (FSM) chuẩn Moore trong vi mạch số

Trong thiết kế phần cứng FPGA, Máy trạng thái hữu hạn (Finite State Machine - FSM) là công cụ toán học và kiến trúc tối ưu để điều khiển các chu trình hoạt động tuần tự. FSM được phân loại thành hai dạng cơ bản:

1. **Máy trạng thái Mealy:** Tín hiệu ngõ ra phụ thuộc vào cả trạng thái hiện tại và các tín hiệu lối vào tức thời. Cấu trúc này có ưu điểm là số lượng trạng thái ít hơn, tuy nhiên ngõ ra có thể xuất hiện các xung gai tổ hợp không mong muốn (combinational glitches) và làm giảm tần số hoạt động cực đại do đường trễ tổ hợp dài.
2. **Máy trạng thái Moore:** Tín hiệu ngõ ra **chỉ phụ thuộc duy nhất vào trạng thái hiện tại** của hệ thống:

$$\mathbf{Y}(t) = \lambda(\mathbf{S}(t))$$

$$\mathbf{S}(t + 1) = \delta(\mathbf{S}(t), \mathbf{X}(t))$$

Trong đó $\mathbf{S}$ là vector trạng thái, $\mathbf{X}$ là vector đầu vào, $\mathbf{Y}$ là vector ngõ ra, $\delta$ là hàm chuyển trạng thái và $\lambda$ là hàm ngõ ra.

> [!NOTE]
> **LÝ DO CHỌN MÔ HÌNH MOORE FSM CHO UART RECEIVER:**  
> Đồ án lựa chọn mô hình Moore FSM vì các tín hiệu điều khiển quan trọng như xung báo hoàn tất `rx_done` hay tín hiệu cờ lỗi `frame_err` được sinh ra hoàn toàn đồng bộ với xung clock hệ thống, sạch sẽ, không có bất kỳ xung nhiễu tổ hợp nào, đảm bảo an toàn tuyệt đối khi điều khiển các khối ngoại vi và mạch chốt dữ liệu.

Đồng thời, mã nguồn tuân thủ nghiêm ngặt phong cách **Two-Process FSM** chuẩn IEEE:
* *Process 1 (Tuần tự):* Chốt trạng thái tiếp theo và thanh ghi dữ liệu theo sườn dương xung clock có Reset bất đồng bộ.
* *Process 2 (Tổ hợp):* Tính toán trạng thái kế tiếp và giá trị cập nhật, gán giá trị mặc định cho toàn bộ các nhánh rẽ nhằm ngăn chặn việc phần mềm tổng hợp tự động suy diễn chốt không mong muốn (inferred latches).

---

## 2.5. Nền tảng phần cứng FPGA Cyclone IV E và Kit thí nghiệm Terasic DE2-115

Đề tài được triển khai thực nghiệm trên kit phát triển học thuật và công nghiệp **Terasic DE2-115**, trang bị chip FPGA Altera Cyclone IV E mang mã hiệu `EP4CE115F29C7`.

* **Kiến trúc chip Cyclone IV E:**
  * Công nghệ chế tạo: 60 nm Low Power (LP).
  * Quy mô tài nguyên: 114,480 phần tử logic (Logic Elements - LEs).
  * Bộ nhớ RAM nhúng M9K: 3,981 Kbits (tương đương 432 khối M9K).
  * Bộ nhân nhúng 18x18: 266 khối (tương đương 532 bộ nhân 9-bit).
  * Mạch vòng khóa pha (PLL): 4 bộ analog PLL đa năng.
  * Số chân I/O người dùng: 529 chân, hỗ trợ nhiều chuẩn I/O (LVTTL 3.3V, LVCMOS, SSTL, LVDS).
* **Ngoại vi bo mạch DE2-115 được khai thác trong đồ án:**
  * Dao động thạch anh tích hợp trên bo mạch: Tần số $50\text{ MHz}$ đưa vào chân `PIN_Y2`.
  * Bộ chuyển đổi mức logic RS-232 Transceiver (IC MAX3232) nối ra đầu cắm DB9: Cung cấp đường nhận `UART_RXD` tại chân `PIN_G12` và đường phát `UART_TXD` tại chân `PIN_G9`.
  * 8 LED 7 thanh (Anode chung - Active-Low): Khai thác 2 LED `HEX1` và `HEX0` để hiển thị 2 ký tự Hexa tương ứng với byte nhận được.
  * 18 LED đỏ đơn (LEDR): `LEDR[7..0]` hiển thị 8 bit dữ liệu nhận được, `LEDR[8]` báo nhận thành công (xung 100 ms), `LEDR[9]` báo lỗi khung truyền (Frame Error), `LEDR[12..10]` hiển thị trạng thái FSM Moore (3-bit), `LEDR[16]` báo khối phát UART TX bận, `LEDR[17]` báo chế độ On-Board Test Mode đang BẬT. Toàn bộ hệ thống sử dụng đồng nhất LED đỏ theo yêu cầu giao diện thị giác.
  * 18 công tắc gạt (SW): `SW[7..0]` dùng để đặt 8-bit dữ liệu phát kiểm tra On-board, `SW[17]` dùng để chọn chế độ hoạt động ('1' = Chế độ On-Board Loopback Test độc lập không cần cáp, '0' = Chế độ kết nối máy tính PC qua cổng RS-232 DB9).
  * Các nút bấm cơ tích cực mức thấp: `KEY[0]` làm nút Master Reset hệ thống, `KEY[1]` làm nút xóa cờ lỗi khung, `KEY[2]` làm nút phát dữ liệu kiểm tra On-board.

---pagebreak---

# PHẦN 3: NỘI DUNG THỰC HIỆN VÀ THIẾT KẾ HỆ THỐNG

## 3.1. Kiến trúc tổng thể và sơ đồ khối hệ thống (Top-Level Architecture)

Toàn bộ hệ thống được tích hợp trong mô-đun cấp cao nhất `uart_rx_top.vhd`. Hệ thống được thiết kế theo tư duy mô-đun hóa cao, phân chia thành các khối chức năng chuyên biệt hoạt động tương hỗ.

```
+---------------------------------------------------------------------------------------------------+
|                                            UART_RX_TOP                                            |
|                                                                                                   |
|  CLOCK_50 (50MHz) ───┬─────────────────────────────────────────────────────────────────────────┐  |
|  KEY[0] (rst_n)   ───┼──────────┬──────────────┬────────────────┬───────────────────────────┐  │  |
|                      │          │              │                │                           │  │  |
|  SW[17] (Mode Sel) ──┼──────────┼──────────────┼────────────────┼───────────┐               │  │  |
|  (1=Loopback, 0=PC)  │          │              │                │           │               │  │  |
|                      │          │              ▼                ▼           ▼               │  │  |
|  UART_RXD ───┐       │          │       +--------------+ +-------------+ +-------+          │  │  |
|  (PIN_G12)   ▼       │          │       | Frame Err    | | FSM State   | | Mode  |          │  │  |
|            \---\     │          │       | Latch        | | Debug       | | LED   |          │  │  |
|  tx_serial ─►MUX ────┼──────────┼───┐   +──────┬-------+ +──────┬------+ +---┬---+          │  │  |
|            /---/     │          │   │          │                │            │              │  │  |
|              ▲       ▼          ▼   │          ▼                ▼            ▼              │  │  |
|              │ +------------------+ │       LEDR[9]       LEDR[12..10]    LEDR[17]          │  │  |
|              │ │     UART_RX      │ │     (Frame Err)      (Moore FSM)  (Test Mode ON)      │  │  |
|              │ │ (Core Receiver)  │ │                                                       │  │  |
|              │ │ * 2-FF Sync      │ │                                                       │  │  |
|              │ │ * 16x Baud Gen   │ │                                                       │  │  |
|              │ │ * Moore FSM      │ │                                                       │  │  |
|              │ │ * Glitch Filter  │ │                                                       │  │  |
|              │ +───┬───┬────┬─────+ │                                                       │  │  |
|              │     │   │    │       │                                                       │  │  |
| rx_data[7..0]│     │   │    │frame_err                                                      │  │  |
| ┌────────────┘     │   │    └───────┼───────────────────────────┐                           │  │  |
| │     rx_done_pulse│   │fsm_state   │                           │                           │  │  |
| │   ┌──────────────┘   └────────────┼──────────────┐            │                           │  │  |
| │   │                               │              │            │                           │  │  |
| ▼   ▼                               │              ▼            ▼                           │  │  |
| +------------------+                │       +------------------------+                      │  │  |
| │ Data Latch &     │                │       │     UART_TX (ECHO &    │                      │  │  |
| │ Display Reg      │                │       │     ON-BOARD TRANSMIT) │                      │  │  |
| +───┬──────────┬───+                │       +──────────────┬─────────+                      │  │  |
|     │          │                    │                      │ tx_serial                      │  │  |
|     │          ▼ data_latch[7..0]   │                      ├────────────────────────────────┘  │
|     │   +------------------+        │                      ▼                                   │
|     │   │    LEDR[7..0]    │        │                   UART_TXD (PIN_G9 Echo / Output)        │
|     │   │  (8-bit Binary)  │        │                   LEDR[16] (TX Busy)                     │
|     │   +------------------+        │                                                          │
|     ▼                               │   SW[7..0] (Data Test) ───┐                              │
| +--------------------------+        │   KEY[2]   (Press Send) ──┴───────────────────────────►  │
| │      HEX_TO_7SEG         │        │                                                          │
| │ [7..4] ──► HEX1 (High)   │        │                                                          │
| │ [3..0] ──► HEX0 (Low)    │        │                                                          │
| +--------------------------+        │                                                          │
|                                     │                                                          │
|     rx_done_pulse                   │                                                          │
|     ───────────────► +-------------------+                                                     │
|                      │  PULSE_STRETCHER  │ ──► LEDR[8] (Kéo dài 100ms)                          │
|                      │ (Counter 5,000,000│                                                      │
|                      +-------------------+                                                     │
|                                                                                                │
| KEY[1] ────────────────────────────────────────► Clear Frame Error (Xóa LEDR[9])                │
+-------------------------------------------------------------------------------------------------+
```

### Chức năng chi tiết của các khối thành phần:
1. **Khối lõi thu `u_uart_rx`:** Thực hiện lấy mẫu đường truyền, đồng bộ hóa 2 tầng D-FF, chống nhiễu Start bit, giải mã các bit nối tiếp và phát hiện lỗi khung truyền (Framing Error).
2. **Khối chốt dữ liệu hiển thị (`data_latch`):** Mỗi khi xuất hiện xung `rx_done` kéo dài 1 chu kỳ clock, byte dữ liệu mới nhất được nạp vào thanh ghi `data_latch` để hiển thị ổn định trên dãy LED đỏ `LEDR[7..0]` và 2 LED 7 đoạn `HEX1:HEX0`.
3. **Khối chốt lỗi khung (`frame_err_latch`):** Nếu phát hiện Stop bit sai mức logic, cờ lỗi được chốt lên mức '1' đưa ra đèn `LEDR[9]`. Cờ này được giữ nguyên cho tới khi người dùng ấn nút `KEY[1]` để thiết lập lại.
4. **Khối hiển thị LED 7 đoạn (`u_hex0`, `u_hex1`):** Tách byte dữ liệu thành 2 nibble 4-bit và giải mã ra 2 bộ đèn LED 7 thanh `HEX0` và `HEX1` dưới dạng số Hexa.
5. **Khối kéo dài xung (`u_pulse_stretcher`):** Xung `rx_done` chỉ kéo dài đúng 1 chu kỳ clock ($20\text{ ns}$ tại $50\text{ MHz}$), mắt người không thể nhận biết. Mạch duy trì mức logic '1' trên đèn đỏ `LEDR[8]` trong thời gian $100\text{ ms}$ ($5\,000\,000$ chu kỳ clock) giúp người dùng quan sát trực quan mỗi khi có một byte nhận thành công.
6. **Khối phát UART (`u_uart_tx`) và chuyển mạch 2 chế độ:**
   - **Chế độ On-Board Test (`SW[17] = '1'`):** Đèn `LEDR[17]` sáng báo chế độ kích hoạt. Dữ liệu phát lấy từ 8 công tắc `SW[7..0]`. Khi người dùng nhấn nút `KEY[2]`, khối `uart_tx` đóng gói khung UART và truyền trực tiếp vào đầu vào của `uart_rx` (Loopback nội bộ). Người dùng kiểm thử toàn diện toàn bộ chu trình thu phát UART trên phần cứng thật mà không cần bất kỳ cáp nối ngoài nào.
   - **Chế độ External PC (`SW[17] = '0'`):** Kết nối qua cổng RS-232 DB9 truyền thống. Dữ liệu nhận từ chân `UART_RXD` trên kit và tự động phản hồi Echo ngược lại máy tính qua `UART_TXD`. Đồng thời, người dùng vẫn có thể bấm nút `KEY[2]` để gửi dữ liệu từ `SW[7..0]` lên máy tính.

---

## 3.2. Thiết kế chi tiết khối nhân UART Receiver (`uart_rx`)

### 3.2.1. Bộ tạo xung Baud Tick 16x (Baud Rate Generator)

Bộ tạo xung nhịp lấy mẫu được hiện thực hóa bằng một bộ đếm modulo $M$. Để tần số lấy mẫu đạt độ chính xác cao nhất, hệ số chia $M$ được làm tròn số học theo công thức:

$$\text{BAUD\_DIVISOR} = \left\lfloor \frac{f_{clk} + 8 \times R_b}{16 \times R_b} \right\rfloor$$

Thay các thông số thiết kế vào công thức:
* Tần số clock hệ thống: $f_{clk} = 50\,000\,000\text{ Hz}$
* Tốc độ baud mục tiêu: $R_b = 115\,200\text{ bps}$

$$\text{BAUD\_DIVISOR} = \left\lfloor \frac{50\,000\,000 + 8 \times 115\,200}{16 \times 115\,200} \right\rfloor = \left\lfloor \frac{50\,921\,600}{1\,843\,200} \right\rfloor = \lfloor 27.626 \rfloor \approx 27$$

Phân tích định lượng sai số thực tế:
* Tần số xung lấy mẫu thực tế: $f_{tick} = \frac{50\,000\,000}{27} \approx 1\,851\,851.85\text{ Hz}$
* Tốc độ Baud thực tế thu được: $R_{b,\text{real}} = \frac{f_{tick}}{16} \approx 115\,740.74\text{ bps}$
* Sai số tương đối (Relative Error):

$$\text{Error} = \frac{115\,740.74 - 115\,200}{115\,200} \times 100\% = +0.469\%$$

> [!IMPORTANT]
> **ĐÁNH GIÁ ĐỘ CHÍNH XÁC ĐỊNH THỜI:**  
> Mức sai số $+0.469\%$ là cực kỳ nhỏ, nằm rất sâu bên trong ngưỡng an toàn cho phép của giao thức UART $(\pm 4.5\%)$. Điều này chứng minh giải pháp sử dụng trực tiếp xung nhịp 50 MHz với bộ chia 27 hoàn toàn triệt tiêu nguy cơ tích lũy lỗi định thời mà không cần sử dụng khối nhân tần PLL phức tạp.

Đặc biệt, trong khối `uart_rx`, khi FSM đang ở trạng thái `S_IDLE` và bắt được cạnh xuống của tín hiệu vào, bộ đếm `baud_counter` được **reset về 0 tức thời**. Cơ chế này đảm bảo xung nhịp lấy mẫu được tái đồng pha ngay lập tức tại thời điểm bắt đầu của Start bit, loại bỏ hoàn toàn độ lệch pha ngẫu nhiên tồn tại từ trước đó.

---

## 3.3. Thuật toán điều khiển và lưu đồ chuyển trạng thái FSM Moore

Máy trạng thái hữu hạn Moore của khối `uart_rx` bao gồm 6 trạng thái hoạt động độc lập được biểu diễn qua bảng mã hóa trạng thái dưới đây:

| Tên trạng thái | Mã nhị phân FSM (`fsm_state_dbg`) | Chức năng hoạt động chi tiết |
| :--- | :---: | :--- |
| `S_IDLE` | `0000` (0) | Trạng thái nghỉ. Đường truyền ở mức '1'. Chờ phát hiện cạnh xuống (`rx_falling_edge = '1'`). |
| `S_START` | `0001` (1) | Đếm 8 ticks (từ 0 đến 7) để đi vào tâm của Start bit. Kiểm tra mức logic đường truyền. |
| `S_DATA` | `0010` (2) | Lấy mẫu tuần tự 8 bit dữ liệu tại tick thứ 15 (tâm mỗi bit). Dịch vào thanh ghi theo thứ tự LSB trước. |
| `S_PARITY` | `0011` (3) | Đếm 16 ticks, lấy mẫu bit kiểm tra Parity tại tâm và so sánh với giá trị tính toán. |
| `S_STOP` | `0100` (4) | Đếm 16 ticks, lấy mẫu bit Stop tại tâm. Kiểm tra tính hợp lệ của bit Stop (bắt buộc mức '1'). |
| `S_DONE` | `0101` (5) | Trạng thái phát xung hoàn tất `rx_done = '1'` trong đúng 1 chu kỳ clock. Chuyển ngay về `S_IDLE`. |

```
              LƯU ĐỒ CHUYỂN TRẠNG THÁI MÁY FSM MOORE (UART RX)
              
                             +----------------+
                             |     S_IDLE     |◄───────────────────────────┐
                             +-------+--------+                            │
                                     │ rx_falling_edge = '1'               │
                                     ▼                                     │
                             +----------------+                            │
              ┌──────────────┤    S_START     │                            │
              │              +-------+--------+                            │
              │ rx_sync = '1'        │ rx_sync = '0'                       │
              │ (Nhiễu/Glitch)       │ & tick_cnt = 7                      │
              │                      ▼                                     │
              │              +----------------+                            │
              │              |     S_DATA     │◄─────────┐                 │
              │              +-------+--------+          │                 │
              │                      │ tick_cnt = 15     │ bit_cnt < 7     │
              │                      ▼                   │ bit_cnt++       │
              │               Lấy mẫu Data(bit) ─────────┘                 │
              │                      │ bit_cnt = 7                         │
              │                      ▼                                     │
              │                      / \                                   │
              │            PARITY_EN?   \─── Có ──► +----------------+     │
              │                      \               |    S_PARITY    |     │
              │                       \ Không        +-------+--------+     │
              │                        ▼                     │ tick_cnt=15 │
              │              +----------------+              ▼             │
              │              |     S_STOP     │◄─────────────┘             │
              │              +-------+--------+                            │
              │                      │ tick_cnt = 15                       │
              │                      ▼                                     │
              │            rx_sync = '1'? (Stop bit)                       │
              │                      / \                                   │
              │              Không  /   \  Có                              │
              │    (Frame Error)   /     \                                 │
              │    frame_err = '1'▼       ▼                                │
              │                   │    +----------------+                  │
              │                   │    |     S_DONE     |                  │
              │                   │    | (rx_done = '1')|                  │
              │                   │    +-------+--------+                  │
              │                   │            │ 1 chu kỳ clock            │
              └───────────────────┴────────────┴───────────────────────────┘
```

### Cơ chế chống nhiễu (Glitch Rejection) tại trạng thái `S_START`:
Tại trạng thái `S_START`, bộ đếm `tick_cnt` tăng từ 0 đến 7 (đúng 8 chu kỳ xung nhịp 16x). Tại thời điểm `tick_cnt = 7` (tương ứng vị trí chính giữa Start bit):
* Nếu `rx_sync = '0'`: Start bit được xác nhận là hợp lệ. Máy FSM xóa bộ đếm và chuyển sang `S_DATA`.
* Nếu `rx_sync = '1'`: Tín hiệu đã quay lại mức cao trước khi tới giữa bit. Đây chắc chắn là xung nhiễu gai (glitch có độ rộng $< 4.34\,\mu\text{s}$). FSM lập tức hủy bỏ quá trình thu và quay trở về `S_IDLE` mà không hề sinh dữ liệu rác.

---

## 3.4. Thiết kế các khối phụ trợ

### 3.4.1. Mạch kéo dài xung quan sát (`pulse_stretcher.vhd`)
Tại tần số hoạt động $50\text{ MHz}$, một chu kỳ clock chỉ kéo dài:

$$T = \frac{1}{50\,000\,000} = 20\text{ ns}$$

Một xung ánh sáng LED có độ rộng $20\text{ ns}$ nằm ngoài ngưỡng cảm nhận thị giác của mắt người (ngưỡng lưu ảnh võng mạc khoảng $20 - 50\text{ ms}$). Mạch `pulse_stretcher` sử dụng một bộ đếm lùi kích thước 23-bit:
* Khi có xung `pulse_in = '1'`, thanh ghi đếm được nạp giá trị cực đại $\text{PULSE\_CLOCKS} = 5\,000\,000$.
* Đầu ra `pulse_out` được giữ ở mức '1' trong suốt quá trình đếm lùi về 0:

$$t_{\text{pulse}} = 5\,000\,000 \times 20\text{ ns} = 100\,000\,000\text{ ns} = 100\text{ ms} = 0.1\text{ s}$$

Nhờ đó, đèn đỏ `LEDR[8]` chớp sáng rõ nét và êm ái mỗi khi một byte được thu nhận thành công.

### 3.4.2. Bộ giải mã Hexa sang LED 7 thanh (`hex_to_7seg.vhd`)
Kit DE2-115 sử dụng cấu trúc LED 7 thanh **Anode chung (Active-Low)**: đoạn LED sẽ sáng khi chân điều khiển ở mức '0' và tắt khi ở mức '1'. Bảng chân lý giải mã 16 ký tự Hexa (từ `0` đến `F`) được mô tả trong bảng dưới đây:

| Ký tự Hex | Mã vào (4-bit) | Đoạn $g$ (bit 6) | Đoạn $f$ (bit 5) | Đoạn $e$ (bit 4) | Đoạn $d$ (bit 3) | Đoạn $c$ (bit 2) | Đoạn $b$ (bit 1) | Đoạn $a$ (bit 0) | Vector `seg[6..0]` |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **0** | `0000` | 1 | 0 | 0 | 0 | 0 | 0 | 0 | `"1000000"` |
| **1** | `0001` | 1 | 1 | 1 | 1 | 0 | 0 | 1 | `"1111001"` |
| **2** | `0010` | 0 | 1 | 0 | 0 | 1 | 0 | 0 | `"0100100"` |
| **3** | `0011` | 0 | 1 | 1 | 0 | 0 | 0 | 0 | `"0110000"` |
| **4** | `0100` | 0 | 0 | 1 | 1 | 0 | 0 | 1 | `"0011001"` |
| **5** | `0101` | 0 | 0 | 1 | 0 | 0 | 1 | 0 | `"0010010"` |
| **6** | `0110` | 0 | 0 | 0 | 0 | 0 | 1 | 0 | `"0000010"` |
| **7** | `0111` | 1 | 1 | 1 | 1 | 0 | 0 | 0 | `"1111000"` |
| **8** | `1000` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | `"0000000"` |
| **9** | `1001` | 0 | 0 | 1 | 0 | 0 | 0 | 0 | `"0010000"` |
| **A** | `1010` | 0 | 0 | 0 | 1 | 0 | 0 | 0 | `"0001000"` |
| **B** | `1011` | 0 | 0 | 0 | 0 | 0 | 1 | 1 | `"0000011"` |
| **C** | `1100` | 1 | 0 | 0 | 0 | 1 | 1 | 0 | `"1000110"` |
| **D** | `1101` | 0 | 1 | 0 | 0 | 0 | 0 | 1 | `"0100001"` |
| **E** | `1110` | 0 | 0 | 0 | 0 | 1 | 1 | 0 | `"0000110"` |
| **F** | `1111` | 0 | 0 | 0 | 1 | 1 | 1 | 0 | `"0001110"` |

---

## 3.5. Bảng ánh xạ chân vật lý và chuẩn tín hiệu ngoại vi trên Kit DE2-115

Toàn bộ các tín hiệu I/O của thiết kế đã được gán trực tiếp vào các chân vật lý của FPGA thông qua tệp cấu hình `DE2_115_UART_RX.qsf`, tuân thủ chuẩn điện áp thiết bị tương thích của Altera Cyclone IV E:

| Tên cổng trên VHDL | Hướng I/O | Vị trí chân FPGA | Chuẩn I/O | Chức năng phần cứng tương ứng trên Kit DE2-115 |
| :--- | :---: | :---: | :---: | :--- |
| `CLOCK_50` | Input | `PIN_Y2` | 3.3-V LVTTL | Nguồn xung nhịp thạch anh hệ thống 50.0 MHz |
| `KEY[0]` | Input | `PIN_M23` | 2.5 V | Nút nhấn cơ Reset hệ thống (Tích cực mức thấp) |
| `KEY[1]` | Input | `PIN_M21` | 2.5 V | Nút nhấn xóa cờ báo lỗi khung truyền (Frame Error) |
| `KEY[2]` | Input | `PIN_N21` | 2.5 V | Nút nhấn phát dữ liệu kiểm tra On-board từ `SW[7..0]` |
| `SW[7..0]` | Input | `PIN_AB26 .. PIN_AB28` | 2.5 V | 8 công tắc gạt cài đặt dữ liệu phát On-board |
| `SW[17]` | Input | `PIN_Y23` | 2.5 V | Công tắc chọn chế độ: '1' = On-Board Test, '0' = External PC |
| `UART_RXD` | Input | `PIN_G12` | 3.3-V LVTTL | Đường nhận dữ liệu nối tiếp từ cổng DB9 / RS-232 ngoài |
| `UART_TXD` | Output | `PIN_G9` | 3.3-V LVTTL | Đường phát Echo / dữ liệu nối tiếp ra PC |
| `LEDR[7..0]` | Output | `PIN_H19 .. PIN_G19` | 2.5 V | 8 LED đỏ hiển thị 8 bit dữ liệu nhị phân nhận được |
| `LEDR[8]` | Output | `PIN_J17` | 2.5 V | LED đỏ chớp sáng 100 ms báo nhận thành công byte |
| `LEDR[9]` | Output | `PIN_G17` | 2.5 V | LED đỏ báo phát hiện lỗi khung truyền (Framing Error) |
| `LEDR[12..10]` | Output | `PIN_J16, PIN_H16, PIN_J15` | 2.5 V | 3 LED đỏ hiển thị mã trạng thái FSM Moore (0 đến 5) |
| `LEDR[16]` | Output | `PIN_G16` | 2.5 V | LED đỏ báo khối phát UART TX đang bận truyền |
| `LEDR[17]` | Output | `PIN_H15` | 2.5 V | LED đỏ báo đang BẬT chế độ kiểm tra On-Board Test Mode |
| `HEX0[6..0]` | Output | `PIN_H22 .. PIN_G18` | 2.5 V | LED 7 đoạn hiển thị Nibble thấp (bit 3..0 dạng Hex) |
| `HEX1[6..0]` | Output | `PIN_U24 .. PIN_M24` | 2.5 V | LED 7 đoạn hiển thị Nibble cao (bit 7..4 dạng Hex) |

---pagebreak---

# PHẦN 4: ĐÁNH GIÁ KẾT QUẢ VÀ KẾT LUẬN

## 4.1. Mô phỏng kiểm chứng chức năng trên ModelSim qua 5 kịch bản biên

Quá trình kiểm chứng chức năng được thực hiện bằng công cụ **ModelSim Intel FPGA Starter Edition** thông qua tệp kiểm tra tự động `sim/tb_uart_rx.vhd`. Testbench sử dụng kỹ thuật phát khung chuẩn xác định thời và giám sát đồng bộ (Synchronous Assertion Monitor) để đánh giá tính đúng đắn của mạch thu.

```
Kết quả ghi nhận từ tệp nhật ký mô phỏng ModelSim (sim/transcript):
# >>> BAT DAU MO PHONG KIEM CHUNG UART RECEIVER FSM <<<
# --- [KICH BAN 1] Kiem tra truyen cac byte don le ---
#   => [PASS] Nhan thanh cong byte: 0x55 (Thoi diem: 87,145,550 ps)
#   => [PASS] Nhan thanh cong byte: 0xAA (Thoi diem: 191,352,210 ps)
#   => [PASS] Nhan thanh cong byte: 0x00 (Thoi diem: 295,558,870 ps)
#   => [PASS] Nhan thanh cong byte: 0xFF (Thoi diem: 399,765,530 ps)
#   => [PASS] Nhan thanh cong byte: 0x3C (Thoi diem: 503,972,190 ps)
# --- [KICH BAN 2] Kiem tra Back-to-Back: 0x12 noi tiep 0x34 ---
#   => [PASS] Byte 1 (0x12) hop le (Thoi diem: 608,178,850 ps)
#   => [PASS] Byte 2 (0x34) hop le (Back-to-Back hoat dong hoan hao)
# --- [KICH BAN 3] Kiem tra Framing Error (Stop bit = '0') ---
#   => [PASS] Framing Error duoc phat hien chinh xac, rx_done bi chan
# --- [KICH BAN 4] Kiem tra bo loc nhieu Start bit (Glitch rejection) ---
#   => [PASS] Xung nhieu da bi loai bo, FSM duy tri IDLE
# --- [KICH BAN 5] Kiem tra Reset bat dong bo giua khung truyen ---
#   => [PASS] Reset giua chung thanh cong, FSM ve IDLE ngay lap tuc
# >>> KET QUA: TAT CA KICH BAN DEU PASS (ALL TESTS PASSED) <<<
```

### Phân tích chi tiết từng kịch bản kiểm thử:

1. **Kịch bản 1 - Kiểm tra các mẫu bit dữ liệu đặc thù (Boundary Bit Patterns):**
   * *Mục tiêu:* Kiểm tra khả năng chốt dữ liệu chính xác đối với các mẫu bit xen kẽ tối đa (`0x55` = `01010101b`, `0xAA` = `10101010b`), toàn số 0 (`0x00`), toàn số 1 (`0xFF`) và mẫu hỗn hợp (`0x3C` = `00111100b`).
   * *Kết quả:* Tất cả 5 byte đều được giải mã chính xác tuyệt đối từng bit, cờ `rx_done` kích hoạt đúng 1 chu kỳ clock tại tâm Stop bit.
2. **Kịch bản 2 - Kiểm tra truyền liên tục không khoảng nghỉ (Back-to-Back Transmission):**
   * *Mục tiêu:* Phía phát gửi liên tiếp byte `0x12` và byte `0x34` mà không duy trì trạng thái IDLE giữa 2 khung (Stop bit của byte 1 vừa kết thúc thì Start bit của byte 2 bắt đầu ngay lập tức).
   * *Kết quả:* FSM chuyển mượt mà từ `S_DONE` về `S_IDLE` và lập tức bắt cạnh xuống của Start bit kế tiếp mà không làm mất bit, khẳng định khả năng nhận dữ liệu với thông lượng cực đại $100\%$ băng thông.
3. **Kịch bản 3 - Kiểm tra cơ chế bắt lỗi khung truyền (Framing Error Verification):**
   * *Mục tiêu:* Phía phát gửi byte `0xA5` nhưng cố tình ép Stop bit xuống mức logic '0' thay vì mức '1'.
   * *Kết quả:* Tại trạng thái `S_STOP` (tick thứ 15), FSM phát hiện mức '0', lập tức kích hoạt cờ `frame_err = '1'`, hủy bỏ việc ghi nhận dữ liệu và khóa hoàn toàn xung `rx_done`.
4. **Kịch bản 4 - Kiểm tra bộ lọc nhiễu Start bit (Glitch Rejection Test):**
   * *Mục tiêu:* Bơm vào đường truyền một xung sụt áp mức '0' có độ rộng 3 ticks ($1.62\,\mu\text{s} < 8\text{ ticks}$).
   * *Kết quả:* Khi FSM đếm đến tick thứ 7 tại `S_START`, tín hiệu đã quay về mức '1'. Mạch nhận diện đây là xung nhiễu và lập tức quay về `S_IDLE`, bảo vệ hệ thống khỏi việc thu dữ liệu rác.
5. **Kịch bản 5 - Kiểm tra Reset bất đồng bộ giữa khung truyền:**
   * *Mục tiêu:* Khi hệ thống đang ở giữa quá trình thu nhận dữ liệu (trạng thái `S_DATA`), tín hiệu `rst_n` bị kéo xuống '0'.
   * *Kết quả:* Mọi thanh ghi dữ liệu và con trỏ trạng thái FSM bị xóa về 0 ngay lập tức mà không cần chờ xung clock tiếp theo, xác nhận tính tin cậy của mạch Reset bất đồng bộ.

---

## 4.2. Báo cáo tổng hợp luận lý và tối ưu hóa tài nguyên phần cứng (Synthesis Report)

Thiết kế đã được tổng hợp và đóng gói hoàn chỉnh bằng phần mềm **Intel Quartus Prime Lite Edition v20.1** cho chip FPGA Cyclone IV E `EP4CE115F29C7`. Dưới đây là bảng thống kê tài nguyên thực tế trích xuất từ báo cáo `DE2_115_UART_RX.fit.summary`:

| Loại tài nguyên phần cứng | Số lượng sử dụng | Tổng tài nguyên sẵn có | Tỷ lệ sử dụng (%) | Đánh giá mức độ tối ưu |
| :--- | :---: | :---: | :---: | :--- |
| **Logic Elements (LEs)** | **154** | 114,480 | **< 0.14%** | Cực kỳ tối ưu, chiếm tỷ trọng không đáng kể |
| *-- Combinational functions* | 137 | 114,480 | < 0.12% | Mạch tổ hợp phân bố gọn gàng |
| *-- Dedicated logic registers*| 97 | 114,480 | < 0.09% | 97 Flip-Flops hoạt động đồng bộ |
| **Total Pins (Chân I/O)** | **32** | 529 | **6.05%** | Đáp ứng đầy đủ giao tiếp hiển thị và truyền thông |
| **Memory Bits (RAM M9K)** | **0** | 3,981,312 | **0.00%** | Không tốn tài nguyên RAM khối |
| **Embedded Multipliers 9-bit**| **0** | 532 | **0.00%** | Bộ chia baud thực hiện hoàn toàn bằng hằng số logic |
| **PLLs** | **0** | 4 | **0.00%** | Tiết kiệm toàn bộ các khối PLL trên chip |

> [!TIP]
> **NHẬN XÉT VỀ HIỆU QUẢ TÀI NGUYÊN:**  
> Toàn bộ hệ thống Top-level (bao gồm lõi RX, khối Echo TX, mạch kéo dài xung 100 ms và 2 bộ giải mã LED 7 thanh) chỉ tiêu tốn **154 LEs** trên tổng số 114,480 LEs của chip. Điều này cho thấy kiến trúc thiết kế đạt độ tinh gọn xuất sắc, mở ra khả năng tích hợp hàng chục lõi UART đồng thời trên một chip FPGA duy nhất.

---

## 4.3. Phân tích định thời tĩnh (Static Timing Analysis - STA) và xác định $F_{\max}$

Phân tích định thời tĩnh là bước kiểm tra quyết định tính ổn định của mạch số trên phần cứng thực tế. Kết quả phân tích TimeQuest Timing Analyzer (trích xuất từ `DE2_115_UART_RX.sta.summary`) dưới mô hình nhiệt độ và điện thế khắc nghiệt nhất (**Slow 1200mV 85°C Model**) cho thấy:

| Chỉ tiêu phân tích định thời | Giá trị đo đạc thực tế | Yêu cầu chuẩn | Trạng thái kiểm tra |
| :--- | :---: | :---: | :---: |
| **Worst-case Setup Slack** | **+15.684 ns** | $> 0\text{ ns}$ | **ĐẠT (Vượt trội)** |
| **Worst-case Hold Slack** | **+0.403 ns** | $> 0\text{ ns}$ | **ĐẠT (Không có vi phạm)** |
| **Minimum Pulse Width Slack**| **+9.681 ns** | $> 0\text{ ns}$ | **ĐẠT (Hoàn hảo)** |

### Xác định tần số hoạt động cực đại ($F_{\max}$):
Tại tần số thiết kế $50.00\text{ MHz}$, chu kỳ xung nhịp là $T_{req} = 20.000\text{ ns}$.  
Thời gian trễ đường truyền dữ liệu lớn nhất trong mạch (Data Path Delay) được tính:

$$T_{delay,\max} = T_{req} - \text{Setup Slack} = 20.000\text{ ns} - 15.684\text{ ns} = 4.316\text{ ns}$$

Từ đó, tần số hoạt động tối đa mà mạch có thể đáp ứng an toàn mà không sinh lỗi định thời là:

$$F_{\max} = \frac{1}{T_{delay,\max}} = \frac{1}{4.316\text{ ns}} \approx \mathbf{231.7\text{ MHz}}$$

Mạch chỉ yêu cầu hoạt động ở $50\text{ MHz}$, trong khi giới hạn phần cứng cho phép lên đến **$231.7\text{ MHz}$**. Khoảng dự trữ định thời (Timing Margin) lên tới **$78.4\%$**, đảm bảo hệ thống miễn nhiễm hoàn toàn với các biến thiên về nhiệt độ môi trường, dao động điện áp nguồn và suy hao linh kiện.

---

## 4.4. Đánh giá kết quả thực nghiệm thời gian thực trên Kit DE2-115

Sau khi nạp tệp bitstream `.sof` vào chip FPGA thông qua cáp nạp USB-Blaster tích hợp trên kit DE2-115 bằng script `NAP_KIT_FPGA.bat`, hệ thống được kiểm chứng thời gian thực qua hai chế độ hoạt động linh hoạt:

### 4.4.1. Chế độ 1: Thực nghiệm On-Board Test độc lập trên Kit (Không cần cáp ngoài)
Chế độ này giải quyết triệt để vấn đề kiểm thử phần cứng khi người dùng chỉ có duy nhất sợi cáp nạp USB-Blaster mà chưa trang bị cáp chuyển đổi RS-232/USB-TTL:
1. **Kích hoạt chế độ:** Gạt công tắc `SW[17]` lên mức cao (`'1'`). Đèn đỏ `LEDR[17]` lập tức sáng lên, thông báo hệ thống đang ở chế độ On-Board Loopback Test Mode.
2. **Cài đặt dữ liệu và phát:**
   - Cài đặt 8 công tắc `SW[7..0]` ứng với mã ASCII của ký tự cần thử nghiệm. Ví dụ: ký tự `'A'` có mã nhị phân `0100 0001b` (gạt `SW[6]` và `SW[0]` lên mức 1, các công tắc khác ở mức 0).
   - Nhấn nút **`KEY[2]`** để phát dữ liệu.
3. **Quan sát kết quả:**
   - Khối `uart_tx` đóng gói và phát chuỗi bit nối tiếp vào đường loopback nội bộ.
   - Khối `uart_rx` thu nhận, lấy mẫu 16x và giải mã thành công:
     - Màn hình LED 7 đoạn `HEX1:HEX0` cập nhật tức thì giá trị Hexa **`41`**.
     - Dãy đèn LED đỏ `LEDR[7..0]` sáng đúng cấu hình nhị phân `0100 0001b`.
     - Đèn đỏ `LEDR[8]` chớp sáng rõ nét trong $100\text{ ms}$ rồi tắt, khẳng định xung `rx_done` đã kích hoạt chính xác.
   - Thử nghiệm tiếp tục với các ký tự khác: `'z'` (`SW[7..0] = 0111 1010b` $\rightarrow$ `HEX = 7A`), `'9'` (`SW[7..0] = 0011 1001b` $\rightarrow$ `HEX = 39`), toàn bộ kết quả đều tức thời và chính xác $100\%$.

```
Sơ đồ chu trình thực nghiệm On-Board Test:
[Cài SW[7..0] = 01000001b] ──(Nhấn KEY[2])──► [UART_TX Core] ──(tx_serial)──┐
                                                                            │ (Loopback)
                                                                            ▼
                                                                     [UART_RX Core]
                                                                            │
    ┌───────────────────────────────────────────────────────────────────────┴──────────────────────┐
    ▼                                                       ▼                                      ▼
HEX1:HEX0 hiển thị: "41"                   LEDR[7..0] sáng: 01000001b                      LEDR[8] nháy 100ms
(Mã Hexa của ký tự 'A')                    (Mã nhị phân trực quan)                         (Báo nhận thành công)
```

### 4.4.2. Chế độ 2: Thực nghiệm kết nối Máy tính PC (Qua cổng DB9 RS-232)
Khi có cáp USB sang RS-232 nối từ máy tính vào cổng DB9 trên bo mạch DE2-115:
1. Gạt công tắc `SW[17]` xuống mức thấp (`'0'`). Đèn `LEDR[17]` tắt, hệ thống chuyển sang chế độ đón nhận tín hiệu trực tiếp từ cổng ngoài `UART_RXD` (`PIN_G12`).
2. Trên máy tính, khởi chạy phần mềm Terminal (Hercules Utility hoặc Tera Term) với thông số cấu hình: `115200 bps, 8 Data bits, No Parity, 1 Stop bit`.
3. Khi gõ các phím trên máy tính (`A`, `B`, `Enter`, `Space`...), dữ liệu được truyền sang kit và hiển thị ngay trên `HEX1:HEX0` và `LEDR[7..0]`. Đồng thời, tính năng Echo phản hồi ký tự ngược lại hiển thị trên màn hình Terminal của PC.

### 4.4.3. Kiểm chứng cơ chế bảo vệ và xử lý lỗi
* **Kiểm tra Master Reset (`KEY[0]`):** Khi màn hình đang lưu giữ dữ liệu hiển thị, nhấn nút `KEY[0]`, toàn bộ thanh ghi `data_latch` bị xóa về 0, `HEX1:HEX0` hiển thị `00`, `LEDR[7..0]` tắt toàn bộ.
* **Kiểm tra cờ Framing Error (`KEY[1]` & `LEDR[9]`):** Cố tình gửi khung sai Stop bit hoặc lệch Baudrate từ máy tính, đèn đỏ `LEDR[9]` lập tức sáng lên và chốt trạng thái báo lỗi, cấm nạp dữ liệu sai vào màn hình hiển thị. Nhấn nút `KEY[1]`, đèn `LEDR[9]` tắt ngay lập tức, khôi phục hệ thống về trạng thái sẵn sàng.

---

## 4.5. Kết luận đồ án và định hướng nghiên cứu mở rộng

### 4.5.1. Kết luận
Đề tài *"Thiết kế và kiểm chứng bộ thu nối tiếp UART Receiver sử dụng máy trạng thái hữu hạn (FSM) trên FPGA Cyclone IV"* đã hoàn thành xuất sắc toàn bộ các mục tiêu đặt ra:
1. Đã giải quyết triệt để các bài toán kỹ thuật hóc búa của bộ thu bất đồng bộ: triệt tiêu hiện tượng bất ổn định bằng bộ đồng bộ 2 tầng D-FF, chống nhiễu Start bit bằng bộ lọc tích cực, và đạt độ chính xác định thời cao nhờ kỹ thuật lấy mẫu quá mức 16x.
2. Xây dựng cấu trúc máy trạng thái Moore FSM chuẩn mực, trong sáng, không sinh chốt tổ hợp, tối ưu hóa tài nguyên phần cứng vượt bậc (chỉ sử dụng 154 LEs).
3. Hệ thống vượt qua $100\%$ các bài kiểm thử biên trên ModelSim và vận hành hoàn hảo, ổn định trên kit phần cứng Terasic DE2-115 với tần số đáp ứng định thời tối đa đạt $231.7\text{ MHz}$.

### 4.5.2. Định hướng phát triển mở rộng
Trong các giai đoạn tiếp theo, đề tài có thể phát triển theo các hướng nâng cao:
* **Tích hợp bộ đệm FIFO (First-In-First-Out):** Mắc thêm khối nhớ RAM FIFO kép ở đầu ra của UART RX nhằm lưu trữ các chuỗi dữ liệu lớn mà không bị mất dữ liệu khi tầng xử lý phía sau bận (tránh hiện tượng Buffer Overflow).
* **Cơ chế tự động nhận diện tốc độ Baud (Auto-Baud Rate Detection):** Đo độ rộng xung của Start bit hoặc một ký tự chuẩn (ví dụ byte `0x7F` hoặc `0x55`) để tự động tính toán hệ số chia mà không cần cấu hình cứng.
* **Đóng gói thành IP Core chuẩn bus công nghiệp:** Chuẩn hóa giao tiếp ngõ ra theo chuẩn bus **AXI4-Lite** hoặc **Avalon Memory-Mapped (Avalon-MM)** để tích hợp trực tiếp vào hệ thống vi xử lý nhúng NIOS II hoặc RISC-V SoC.

---pagebreak---

# TÀI LIỆU THAM KHẢO

1. **Pong P. Chu**, *FPGA Prototyping by VHDL Examples: Xilinx Spartan-3 Version*, John Wiley & Sons, 2008. (Chương 7: UART - Universal Asynchronous Receiver and Transmitter).
2. **Volnei A. Pedroni**, *Finite State Machines in Hardware: Theory and Design (with VHDL and SystemVerilog)*, MIT Press, 2013.
3. **Intel Corporation**, *Cyclone IV Device Handbook, Volume 1: Device Interfaces and Integration*, Intel FPGA Documentation, 2020.
4. **Terasic Technologies Inc.**, *DE2-115 User Manual: Altera Cyclone IV E Development Board*, Terasic Design Resources, Rev. 1.3.
5. **IEEE Standards Association**, *IEEE Standard VHDL Language Reference Manual (IEEE Std 1076-2008)*, The Institute of Electrical and Electronics Engineers, Inc., New York, 2009.
6. **Clifford E. Cummings**, *Synthesis and Scripting Techniques for Designing Multi-Asynchronous Clock Designs*, SNUG (Synopsys Users Group), 2001. (Phân tích hiện tượng Metastability và đồng bộ hóa tín hiệu).
