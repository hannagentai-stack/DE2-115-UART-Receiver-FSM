# HƯỚNG DẪN CHI TIẾT CÀI ĐẶT VÀ SỬ DỤNG PHẦN MỀM HERCULES KẾT NỐI LAPTOP VỚI KIT FPGA DE2-115

Tài liệu này hướng dẫn từng bước từ khâu cài đặt, kết nối cáp phần cứng, cấu hình thông số cổng COM cho đến kịch bản biểu diễn (Demo) truyền nhận dữ liệu **UART (115200 bps, 8N1)** giữa **Laptop** và **Kit Altera DE2-115** bằng phần mềm **Hercules SETUP utility**.

---

## PHẦN I. CHUẨN BỊ CÁP KẾT NỐI VÀ KIỂM TRA CỔNG COM TRÊN LAPTOP

Để kết nối Laptop với cổng **RS-232 (DB9)** trên Kit DE2-115, bạn cần chuẩn bị:
1. **Cáp nguồn 12V DC** và **Cáp nạp USB-Blaster** (cắm vào cổng `BLASTER` trên Kit để nạp file `.sof`).
2. **Cáp chuyển đổi USB-to-RS232 (đầu DB9)** cắm từ cổng USB của Laptop vào cổng **`RS-232`** (cổng DB9 ở góc trên bên phải của Kit DE2-115).

### Bước 1: Kiểm tra Driver và xác định tên cổng `COM` trên Windows
1. Cắm cáp **USB-to-RS232** vào cổng USB của Laptop.
2. Nhấn tổ hợp phím **`Windows + X`** trên bàn phím $\rightarrow$ chọn **Device Manager** (Trình quản lý thiết bị).
3. Tìm và nhấp mở rộng mục **Ports (COM & LPT)**:
   - Bạn sẽ thấy một dòng tên thiết bị dạng:
     - `USB-SERIAL CH340 (COM3)` hoặc
     - `Prolific USB-to-Serial Comm Port (COM4)` hoặc
     - `USB Serial Port (COM5)`
   - **Ghi nhớ số cổng `COM` này** (ví dụ: `COM3` hoặc `COM4`) để chọn trong phần mềm Hercules.
   - *(Lưu ý: Nếu thiết bị hiện dấu chấm than màu vàng $\triangle$, nghĩa là Laptop chưa có driver cho cáp chuyển đổi. Bạn chỉ cần bấm chuột phải vào thiết bị đó chọn **Update driver -> Search automatically for drivers**, hoặc tải driver **CH340 / PL2303** tương ứng với loại cáp đang dùng).*

---

## PHẦN II. CÁCH TẢI VÀ KHỞI ĐỘNG PHẦN MỀM HERCULES SETUP UTILITY

**Hercules SETUP utility** là phần mềm kiểm thử giao tiếp nối tiếp (Serial COM, TCP/IP, UDP) miễn phí của hãng **HW group**. Ưu điểm lớn nhất là **chạy trực tiếp (Portable)** chỉ với 1 file `.exe` duy nhất, không cần qua các bước cài đặt phức tạp.

### Bước 1: Tải phần mềm
- **Trang chủ chính thức:** [https://www.hw-group.com/software/hercules-setup-utility](https://www.hw-group.com/software/hercules-setup-utility)
- Kéo xuống mục **Download** và tải file **`hercules_3-2-8.exe`** (dung lượng chỉ khoảng ~600 KB).

### Bước 2: Mở phần mềm và chọn chế độ giao tiếp Serial
1. Nhấp đúp chuột vào file **`hercules_3-2-8.exe`** vừa tải về để mở giao diện chính.
2. Nhìn lên thanh menu phía trên cùng của cửa sổ, nhấp chọn tab thứ 2 từ trái sang: **`Serial`** (nằm cạnh tab `UDP Setup`).

```text
+-------------------------------------------------------------------------+
| [UDP Setup] | [ >>> Serial <<< ] | [TCP Client] | [TCP Server] | ...    |
+-------------------------------------------------------------------------+
|  Received/Sent data (Màn hình hiển thị dữ liệu)   |  Serial (Cấu hình)  |
|                                                   |  Name:      [COM3 ] |
|                                                   |  Baud:      [115200]|
|                                                   |  Data size: [8    ] |
|                                                   |  Parity:    [none ] |
|                                                   |  Handshake: [OFF  ] |
|                                                   |  Mode:      [Free ] |
|                                                   |  [   Open / Close ] |
+---------------------------------------------------+---------------------+
|  Send (Khung gửi chuỗi/mã Hex):                                         |
|  [ 41                                       ] [x] HEX   [ Send ]        |
+-------------------------------------------------------------------------+
```

---

## PHẦN III. CẤU HÌNH THÔNG SỐ CHUẨN UART (115200 - 8N1)

Trong tab **`Serial`** của phần mềm Hercules, nhìn sang cột **Serial** nằm ở **bên phải màn hình** và thiết lập chính xác 6 thông số sau để khớp với thiết kế phần cứng VHDL (`uart_rx.vhd`) trên FPGA:

| Mục trên Hercules | Giá trị cần chọn | Giải thích kỹ thuật |
| :--- | :---: | :--- |
| **Name** | **`COM3`** *(hoặc cổng COM máy bạn)* | Cổng giao tiếp của cáp USB-to-RS232 đã xem trong Device Manager. |
| **Baud** | **`115200`** | Tốc độ truyền 115.200 bit/giây (khớp bộ chia `DIVISOR = 27` của xung `50 MHz`). |
| **Data size** | **`8`** | Khung truyền gồm 8 bit dữ liệu (`D0..D7`, truyền từ LSB đến MSB). |
| **Parity** | **`none`** | Không sử dụng bit kiểm tra chẵn lẻ (Chuẩn **8N1**). |
| **Handshake** | **`OFF`** | Tắt bắt tay phần cứng (`RTS/CTS`), chỉ truyền/nhận thuần qua 2 dây `TXD/RXD`. |
| **Mode** | **`Free`** | Chế độ truyền/nhận tự do tức thời theo từng byte. |

### Mở cổng kết nối (Open Port)
1. Sau khi chỉnh đúng các thông số trên, nhấn nút **`Open`** (nằm ngay dưới mục `Mode`).
2. Kiểm tra trên màn hình chính `Received/Sent data`:
   - Nếu hiện dòng chữ màu xanh lá hoặc hồng: **`Serial port COMx opened`** và nút `Open` đổi tên thành **`Close`** $\rightarrow$ **Kết nối giữa Laptop và cáp RS-232 đã thành công!**
3. **Mẹo hiển thị trực quan:** Nhấp **chuột phải** vào vùng trắng giữa màn hình `Received/Sent data`, bạn có thể tích chọn:
   - **`Special Chars`** hoặc **`HEX Enable`**: Giúp hiển thị song song cả ký tự chữ (ASCII) và mã thập lục phân (Hexa) trên màn hình Laptop để dễ đối chiếu với đèn LED 7 đoạn `HEX1:HEX0` trên Kit!

---

## PHẦN IV. KỊCH BẢN THỰC HÀNH & BIỂU DIỄN (DEMO) VỚI KIT DE2-115

### Bước chuẩn bị trên Kit FPGA DE2-115
1. Đảm bảo đã chạy file [`NAP_KIT_FPGA.bat`](../NAP_KIT_FPGA.bat) để nạp mạch vào Kit.
2. **Gạt công tắc `SW[17]` xuống mức `0`** (gạt về phía dưới).
   - **Kiểm tra:** Đèn đỏ `LEDR[17]` phải **TẮT**. Lúc này bộ chọn kênh (MUX) trong [`uart_rx_top.vhd`](../rtl/uart_rx_top.vhd) đã ngắt bộ phát nội bộ và nối thẳng đầu vào bộ thu vào chân vật lý **`UART_RXD` (Pin `G12`)** nhận tín hiệu từ Laptop.
3. Nhấn nút **`KEY[0]`** (nút ngoài cùng bên phải) 1 lần để Reset toàn bộ thanh ghi về `00`.

---

### Kịch bản 1: Gõ phím trực tiếp trên bàn phím Laptop (Truyền ASCII & Nhận Echo)

1. **Thao tác trên Laptop:**
   - Nhấp chuột trái vào vùng trống giữa màn hình **`Received/Sent data`** của Hercules.
   - Bấm phím chữ hoa **`A`** trên bàn phím Laptop (`Shift + a`).
2. **Hiện tượng quan sát trên Kit DE2-115:**
   - **LED 7 đoạn `HEX1:HEX0`:** Lập tức hiển thị số **`41`** (mã ASCII hệ Hex của chữ `'A'` là `0x41`).
   - **Dãy LED đỏ `LEDR[7..0]`:** Sáng đúng mã nhị phân `0100 0001` (`LEDR[6]` và `LEDR[0]` sáng, các đèn còn lại tắt).
   - **Đèn báo nhận `LEDR[8]`:** Chớp sáng rõ ràng trong **100 ms** (nhờ mạch kéo giãn xung [`pulse_stretcher.vhd`](../rtl/pulse_stretcher.vhd)) rồi tắt.
3. **Hiện tượng quan sát trên màn hình Hercules (Laptop):**
   - Ngay khi mạch FPGA nhận xong chữ `'A'` (`rx_done_tick = '1'`), khối `uart_tx` trên FPGA được kích hoạt tự động **Echo (phản hồi ngược)** byte `0x41` qua chân `UART_TXD` (Pin `G9`) trả về Laptop.
   - Trên màn hình Hercules xuất hiện ký tự **`A`** (hoặc `{41}` nếu bật chế độ xem Hex).

**Bảng các phím gõ thử nhanh từ bàn phím Laptop:**

| Phím gõ trên Laptop | Hiển thị trên `HEX1:HEX0` | Trạng thái đèn `LEDR[7..0]` (`LEDR7 .. LEDR0`) | Các đèn `LEDR` sáng |
| :---: | :---: | :---: | :--- |
| Phím **`A`** | **`41`** | `0 1 0 0   0 0 0 1` | `LEDR[6]`, `LEDR[0]` |
| Phím **`5`** | **`35`** | `0 0 1 1   0 1 0 1` | `LEDR[5]`, `LEDR[4]`, `LEDR[2]`, `LEDR[0]` |
| Phím **`z`** | **`7A`** | `0 1 1 1   1 0 1 0` | `LEDR[6]`, `LEDR[5]`, `LEDR[4]`, `LEDR[3]`, `LEDR[1]` |
| Phím **`U`** | **`55`** | `0 1 0 1   0 1 0 1` | Sáng xen kẽ chẵn/lẻ: `LEDR[6, 4, 2, 0]` |
| Phím **`0`** | **`30`** | `0 0 1 1   0 0 0 0` | `LEDR[5]`, `LEDR[4]` |
| Phím **`Space`** (Cách) | **`20`** | `0 0 1 0   0 0 0 0` | Chỉ sáng `LEDR[5]` |

---

### Kịch bản 2: Gửi mã Hexa đặc biệt (`0xFF`, `0x00`, `0xAA`) từ khung Send

Một số giá trị biên như `0xFF` (`1111 1111b` — tất cả các bit bằng 1) hoặc `0x00` (`0000 0000b` — tất cả các bit bằng 0) không thể gõ trực tiếp bằng phím chữ thông thường trên bàn phím. Hercules hỗ trợ gửi trực tiếp mã Hexa ở phần **Send** dưới đáy cửa sổ:

1. Nhìn xuống mục **`Send`** ở dưới cùng của cửa sổ Hercules (có 3 dòng nhập liệu).
2. **Tích chọn vào ô vuông `HEX`** nằm ngay bên phải ô nhập liệu đầu tiên.
3. **Thử gửi `0xFF` (Kiểm tra sáng toàn bộ 8 bit):**
   - Nhập **`FF`** vào ô trống $\rightarrow$ nhấn nút **`Send`** bên cạnh.
   - **Kết quả trên Kit:** `HEX1:HEX0` hiện **`FF`**, toàn bộ 8 đèn đỏ **`LEDR[7..0]` đều sáng rực**, đèn `LEDR[8]` chớp 100 ms.
4. **Thử gửi `0xAA` (Bit xen kẽ `1010 1010`):**
   - Nhập **`AA`** vào ô trống (vẫn giữ tích chọn `HEX`) $\rightarrow$ nhấn **`Send`**.
   - **Kết quả trên Kit:** `HEX1:HEX0` hiện **`AA`**, các đèn lẻ `LEDR[7, 5, 3, 1]` sáng.
5. **Thử gửi `0x00` (Kiểm tra xóa toàn bộ 8 bit):**
   - Nhập **`00`** vào ô trống (giữ tích chọn `HEX`) $\rightarrow$ nhấn **`Send`**.
   - **Kết quả trên Kit:** `HEX1:HEX0` nhảy về **`00`**, toàn bộ `LEDR[7..0]` tắt hết, nhưng đèn báo nhận thành công **`LEDR[8]` vẫn chớp sáng 100 ms** (chứng tỏ mạch vừa nhận thành công một khung dữ liệu mang giá trị `0x00` chứ không phải trạng thái nghỉ!).

---

### Kịch bản 3: Biểu diễn tính năng Phát hiện Lỗi Khung Truyền (Framing Error Detection)

Đây là phần biểu diễn ăn điểm cao nhất khi bảo vệ đồ án để chứng minh trạng thái `STOP` của FSM hoạt động đúng thiết kế:

1. **Cách tạo lỗi từ Laptop:**
   - Trên phần mềm Hercules, nhấn nút **`Close`** để tạm đóng cổng COM.
   - Tại ô **`Baud`**, đổi tốc độ từ `115200` xuống **`9600`**.
   - Nhấn nút **`Open`** để mở lại cổng COM ở tốc độ sai lệch (`9600 bps`).
   - Tại ô `Send` phía dưới (đang tích chọn `HEX`), nhập **`00`** (hoặc gõ phím bất kỳ trên bàn phím) rồi nhấn **`Send`**.
2. **Hiện tượng quan sát trên Kit DE2-115:**
   - Đèn đỏ **`LEDR[9]` (Framing Error Flag)** lập tức **BẬT SÁNG** và giữ nguyên trạng thái sáng (nhờ mạch chốt cờ lỗi `err_latch_reg` trong [`uart_rx_top.vhd`](../rtl/uart_rx_top.vhd)).
   - Đồng thời, dữ liệu bị lỗi sẽ **không** được phép ghi đè vào thanh ghi hiển thị `HEX1:HEX0` (bảo toàn dữ liệu hợp lệ trước đó).
3. **Giải thích nguyên lý (Dùng khi trả lời câu hỏi của giảng viên):**
   - Bộ thu FPGA đang lấy mẫu ở tốc độ `115200 bps` (chu kỳ mỗi bit là $8.68\ \mu\text{s}$).
   - Khi Laptop cố tình phát ở tốc độ `9600 bps` (chu kỳ mỗi bit dài tới $104.17\ \mu\text{s}$, gấp 12 lần), toàn bộ khung 10 bit của bộ thu FPGA diễn ra khi Laptop vẫn đang giữ đường truyền ở mức thấp `'0'` của bit Start/Data đầu tiên.
   - Do đó, khi FSM trên FPGA chuyển sang trạng thái **`STOP`** và lấy mẫu ở điểm giữa (`sample_cnt = 15`), tín hiệu thu được là `'0'` thay vì mức cao `'1'` chuẩn của Stop bit $\rightarrow$ Cờ `rx_frame_err` bật lên mức `'1'` và chốt đèn đỏ **`LEDR[9]`**.
4. **Khôi phục lại trạng thái bình thường:**
   - Nhấn nút **`KEY[1]`** trên Kit DE2-115 $\rightarrow$ Đèn đỏ báo lỗi **`LEDR[9]` tắt ngay lập tức**.
   - Trên Hercules: Bấm **`Close`** $\rightarrow$ chỉnh **`Baud`** về lại **`115200`** $\rightarrow$ bấm **`Open`**. Hệ thống lại truyền nhận bình thường.

---

## PHẦN V. XỬ LÝ CÁC SỰ CỐ THƯỜNG GẶP (TROUBLESHOOTING)

| Hiện tượng gặp phải | Nguyên nhân | Cách khắc phục nhanh |
| :--- | :--- | :--- |
| **Bấm `Open` báo lỗi `Access denied` hoặc `Error opening serial port`** | Cổng COM đang bị một phần mềm khác (như PuTTY, Arduino IDE, hoặc một cửa sổ Hercules khác) chiếm giữ, hoặc chọn sai số cổng COM. | Đóng các phần mềm Serial khác đang mở; kiểm tra lại đúng số `COMx` trong **Device Manager**. |
| **Gõ phím trên Hercules nhưng `HEX1:HEX0` trên Kit không thay đổi** | 1. Công tắc `SW[17]` vẫn đang gạt lên `1` (chế độ On-Board Test).<br>2. Cáp RS-232 nối giữa PC và Kit DE2-115 bị lỏng hoặc ngược chân TX/RX. | 1. Gạt **`SW[17]` xuống `0`** (đảm bảo đèn `LEDR[17]` đã tắt).<br>2. Kiểm tra lại đầu cắm DB9 trên Kit DE2-115. |
| **Gõ 1 phím trên Hercules nhưng `HEX1:HEX0` nhảy số lạ và đèn `LEDR[9]` bật sáng đỏ** | Tốc độ `Baud` trên Hercules chưa chỉnh về `115200` (mặc định của Hercules khi mới mở là `9600`). | Bấm `Close`, đổi **Baud** thành **`115200`**, bấm `Open` lại, sau đó nhấn `KEY[1]` trên Kit để xóa đèn lỗi `LEDR[9]`. |
