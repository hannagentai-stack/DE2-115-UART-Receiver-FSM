# HƯỚNG DẪN CHI TIẾT THỰC HÀNH TEST MẠCH UART RECEIVER TRÊN KIT DE2-115

Tài liệu này hướng dẫn chi tiết từng bước kiểm thử phần cứng thực tế mạch **UART Receiver** trên kit **Terasic DE2-115 (FPGA Altera Cyclone IV E)**.

Thiết kế đã được tích hợp sẵn **2 chế độ hoạt động**:
1. **Chế độ 1: On-Board Test độc lập (Khuyên dùng ngay)** — Tự kiểm tra trực tiếp trên kit bằng công tắc (`SW`) và nút bấm (`KEY`), **không cần thêm bất kỳ dây cáp ngoài nào** (chỉ dùng duy nhất sợi cáp nạp USB-Blaster đang có).
2. **Chế độ 2: Kết nối Máy tính PC qua cổng RS-232 DB9** — Gõ phím từ bàn phím máy tính qua phần mềm Terminal (Hercules / Tera Term) và nhận Echo phản hồi.

---

## I. BẢNG TRA CỨU NHANH NGOẠI VI TRÊN KIT DE2-115

### 1. Nút bấm (`KEY`) — Tích cực mức thấp (Nhấn = `0`, Nhả = `1`)
| Nút bấm | Vị trí trên kit | Chức năng trong mạch |
| :--- | :---: | :--- |
| **`KEY[0]`** | Nút ngoài cùng bên phải | **Master Reset hệ thống:** Đưa FSM về `IDLE`, xóa toàn bộ thanh ghi dữ liệu và cờ lỗi. |
| **`KEY[1]`** | Nút thứ 2 từ phải sang | **Xóa cờ lỗi khung (Clear Framing Error):** Tắt đèn đỏ `LEDR[9]` khi có lỗi Stop bit. |
| **`KEY[2]`** | Nút thứ 3 từ phải sang | **Nút Phát dữ liệu On-board (Send Data):** Nhấn để phát byte dữ liệu cài đặt từ `SW[7..0]`. |

### 2. Công tắc gạt (`SW`) — Gạt lên = `1`, Gạt xuống = `0`
| Công tắc | Vị trí | Chức năng trong mạch |
| :--- | :---: | :--- |
| **`SW[17]`** | Công tắc ngoài cùng bên trái | **Chọn chế độ hoạt động:**<br>• Gạt lên (`1`): **Bật chế độ On-Board Test** (Đèn `LEDR[17]` sáng).<br>• Gạt xuống (`0`): **Chế độ kết nối PC ngoài qua cổng DB9**. |
| **`SW[7..0]`** | 8 công tắc góc dưới bên phải | **Cài đặt 8 bit dữ liệu phát:** `SW[0]` là LSB (bit 0), `SW[7]` là MSB (bit 7). |

### 3. Dãy LED đỏ (`LEDR`) & LED 7 đoạn (`HEX1:HEX0`)
| Đèn LED | Ý nghĩa quan sát |
| :--- | :--- |
| **`HEX1 : HEX0`** | Hiển thị mã **Hexa** của byte nhận được (`HEX1` là nibble cao, `HEX0` là nibble thấp). |
| **`LEDR[7..0]`** | Hiển thị **8 bit nhị phân** của byte nhận được (`LEDR[0]` là bit 0, `LEDR[7]` là bit 7). |
| **`LEDR[8]`** | **Đèn báo nhận thành công:** Chớp sáng rõ trong **100 ms** mỗi khi nhận xong 1 byte. |
| **`LEDR[9]`** | **Cờ báo lỗi khung (Framing Error):** Bật sáng khi Stop bit bị sai mức logic '1'. |
| **`LEDR[12..10]`** | Mã hóa 3-bit trạng thái FSM Moore: `000` = IDLE, `001` = START, `010` = DATA, `100` = STOP, `101` = DONE. |
| **`LEDR[16]`** | Báo khối phát UART TX đang bận (`tx_busy`). |
| **`LEDR[17]`** | Báo hệ thống đang ở **Chế độ On-Board Test Mode** (`SW[17] = 1`). |

---

## II. BƯỚC NẠP BITSTREAM VÀO KIT DE2-115

1. Cấp nguồn adapter 12V DC cho kit DE2-115 và bật công tắc đỏ `POWER`.
2. Cắm cáp nạp **USB-Blaster** từ kit sang cổng USB máy tính.
3. Trong thư mục dự án, nhấp đúp chuột chạy file:
   👉 **`NAP_KIT_FPGA.bat`**
4. Khi cửa sổ dòng lệnh báo `[THÀNH CÔNG] ĐÃ NẠP XONG 100% VÀO KIT DE2-115!`, kit đã sẵn sàng hoạt động!

---

## III. HƯỚNG DẪN TEST CHẾ ĐỘ 1: ON-BOARD TEST (KHÔNG CẦN CÁP NGOÀI)

### Quy tắc chung:
* Luôn đảm bảo công tắc **`SW[17]` gạt lên `1`** $\rightarrow$ Đèn đỏ **`LEDR[17]` sáng**.
* Cài đặt giá trị nhị phân trên **`SW[7..0]`**.
* Bấm nút **`KEY[2]`** một lần rồi nhả ra.
* Quan sát `HEX1:HEX0` và `LEDR[7..0]`, `LEDR[8]`.

---

### Ví dụ 1: Phát ký tự chữ hoa `'A'` (Mã ASCII: `0x41` = `0100 0001b`)

1. **Gạt Switch:**
   - `SW[17]` = **Gạt lên `1`** (Đèn `LEDR[17]` sáng).
   - `SW[7..0]` gạt như sau:
     - `SW[0]` = **1** (Gạt lên)
     - `SW[1]` đến `SW[5]` = **0** (Gạt xuống)
     - `SW[6]` = **1** (Gạt lên)
     - `SW[7]` = **0** (Gạt xuống)
     *(Nhìn từ trái sang phải: `SW[7..0]` = `0 1 0 0 0 0 0 1`)*
2. **Thao tác:** Nhấn nút **`KEY[2]`** 1 lần rồi nhả tay.
3. **Kết quả quan sát trên Kit:**
   - **`HEX1:HEX0`:** Nhảy ngay số **`41`** (`HEX1` = `4`, `HEX0` = `1`).
   - **`LEDR[7..0]`:** Sáng đúng 2 đèn: `LEDR[6]` và `LEDR[0]`.
   - **`LEDR[8]`:** Chớp sáng rõ trong 100 ms rồi tắt.

---

### Ví dụ 2: Phát ký tự chữ thường `'z'` (Mã ASCII: `0x7A` = `0111 1010b`)

1. **Gạt Switch:**
   - Giữ nguyên `SW[17]` = **1**.
   - Cài đặt `SW[7..0]`:
     - `SW[0]` = **0** (Xuống)
     - `SW[1]` = **1** (Lên)
     - `SW[2]` = **0** (Xuống)
     - `SW[3]` = **1** (Lên)
     - `SW[4]` = **1** (Lên)
     - `SW[5]` = **1** (Lên)
     - `SW[6]` = **1** (Lên)
     - `SW[7]` = **0** (Xuống)
     *(Nhị phân: `0111 1010`)*
2. **Thao tác:** Nhấn nút **`KEY[2]`**.
3. **Kết quả quan sát trên Kit:**
   - **`HEX1:HEX0`:** Hiển thị tức thì chữ **`7A`** (`HEX1` = `7`, `HEX0` = `A`).
   - **`LEDR[7..0]`:** Sáng các đèn `LEDR[6, 5, 4, 3, 1]`.
   - **`LEDR[8]`:** Chớp sáng 100 ms.

---

### Ví dụ 3: Phát ký tự chữ số `'5'` (Mã ASCII: `0x35` = `0011 0101b`)

1. **Gạt Switch:**
   - `SW[7..0]` = `0011 0101`:
     - Gạt lên (`1`): `SW[0]`, `SW[2]`, `SW[4]`, `SW[5]`.
     - Gạt xuống (`0`): `SW[1]`, `SW[3]`, `SW[6]`, `SW[7]`.
2. **Thao tác:** Nhấn nút **`KEY[2]`**.
3. **Kết quả quan sát trên Kit:**
   - **`HEX1:HEX0`:** Hiển thị số **`35`**.
   - **`LEDR[7..0]`:** Sáng đúng các vị trí tương ứng.

---

### Ví dụ 4: Kiểm tra nút Master Reset (`KEY[0]`)

1. Sau khi đã phát ra số `35` hoặc `41` (LED 7 đoạn đang giữ giá trị cũ).
2. Nhấn nút **`KEY[0]`** (nút ngoài cùng bên phải).
3. **Kết quả:**
   - Màn hình `HEX1:HEX0` lập tức reset về **`00`**.
   - Dãy đèn `LEDR[7..0]` tắt sạch toàn bộ.
   - Khi nhả nút `KEY[0]` và bấm lại `KEY[2]`, mạch thu phát tiếp tục hoạt động bình thường.

---

## IV. BẢNG TRA CỨU MẪU CÁC KÝ TỰ PHỔ BIẾN ĐỂ THỰC HÀNH

| Ký tự | Mã ASCII (Hex) | Trạng thái công tắc `SW[7..0]` (`SW7 SW6 SW5 SW4 SW3 SW2 SW1 SW0`) | Hiển thị `HEX1:HEX0` |
| :---: | :---: | :---: | :---: |
| **`0`** | `0x30` | `0 0 1 1   0 0 0 0` | `30` |
| **`1`** | `0x31` | `0 0 1 1   0 0 0 1` | `31` |
| **`9`** | `0x39` | `0 0 1 1   1 0 0 1` | `39` |
| **`A`** | `0x41` | `0 1 0 0   0 0 0 1` | `41` |
| **`B`** | `0x42` | `0 1 0 0   0 0 1 0` | `42` |
| **`C`** | `0x43` | `0 1 0 0   0 0 1 1` | `43` |
| **`H`** | `0x48` | `0 1 0 0   1 0 0 0` | `48` |
| **`U`** | `0x55` | `0 1 0 1   0 1 0 1` (Bit xen kẽ kiểm tra biên) | `55` |
| **`a`** | `0x61` | `0 1 1 0   0 0 0 1` | `61` |
| **`z`** | `0x7A` | `0 1 1 1   1 0 1 0` | `7A` |
| **`Space`** | `0x20` | `0 0 1 0   0 0 0 0` | `20` |
| **`Enter`** | `0x0D` | `0 0 0 0   1 1 0 1` | `0D` |

---

## V. HƯỚNG DẪN TEST CHẾ ĐỘ 2: KẾT NỐI MÁY TÍNH PC (KHI CÓ CÁP DB9)

Khi bạn có cáp chuyển đổi **USB-to-RS232 (Cổng DB9 đực)** cắm từ PC vào cổng DB9 của kit:

1. **Chuyển chế độ:** Gạt công tắc **`SW[17]` xuống mức `0`** $\rightarrow$ Đèn `LEDR[17]` tắt.
2. **Cấu hình trên PC:**
   - Mở phần mềm **Hercules Setup utility** $\rightarrow$ chọn tab **Serial**.
   - Chọn đúng cổng **Name** (ví dụ `COM3` hoặc `COM4`).
   - Thiết lập: **Baud:** `115200`, **Data size:** `8`, **Parity:** `none`, **Handshake:** `OFF`.
   - Nhấn nút **Open** (nút chuyển sang trạng thái Close chữ xanh lá là thành công).
3. **Thực nghiệm truyền nhận & Echo:**
   - Gõ phím `A` trên bàn phím máy tính $\rightarrow$ `HEX1:HEX0` hiện `41`, `LEDR[8]` chớp 100 ms, và ký tự `A` xuất hiện trên màn hình Hercules (Echo).
4. **Kiểm tra phát hiện lỗi khung (Framing Error):**
   - Trên Hercules, ngắt kết nối (Close), đổi Baudrate sang `9600` rồi Open lại và gõ 1 phím bất kỳ.
   - Do lệch tốc độ Baud, Stop bit không phải mức 1 $\rightarrow$ Đèn đỏ **`LEDR[9]` lập tức bật sáng** và chốt cờ lỗi!
   - Nhấn nút **`KEY[1]`** trên kit $\rightarrow$ Đèn đỏ `LEDR[9]` tắt ngay lập tức!
