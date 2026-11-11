# Thiết kế Bộ Thu UART (UART Receiver) sử dụng Máy Trạng Thái Hữu Hạn (FSM) trên FPGA Altera DE2-115

Dự án thiết kế phần cứng số mức RTL bằng ngôn ngữ **VHDL** cho bộ thu **UART Receiver (115200 bps, khung truyền 8N1)** sử dụng phương pháp lấy mẫu quá mức **16x Oversampling** và **Máy trạng thái hữu hạn (FSM)**, triển khai thực tế trên Kit **Altera DE2-115 (Cyclone IV E - `EP4CE115F29C7N`)**.

---

## Tính năng nổi bật

- **Lấy mẫu quá mức 16x (16x Oversampling):** Bộ chia tần số tạo xung lấy mẫu `tick_16x` ($115200 \times 16 \approx 1.8432\text{ MHz}$) từ xung nhịp hệ thống $50\text{ MHz}$ (`CLOCK_50`, chia 27 chu kỳ, sai số chỉ $+0.47\%$).
- **Đồng bộ hóa chống siêu ổn định (2-FF Synchronizer):** Bảo vệ tín hiệu bất đồng bộ `rx_serial_in` trước khi đưa vào FSM.
- **Chống nhiễu gai xung (Start-bit Glitch Filter):** Kiểm tra lại mức logic tại chính giữa bit Start (`sample_cnt = 7`) để loại bỏ xung nhiễu ngắn.
- **Chế độ Tự kiểm tra trên mạch (On-Board Loopback Test):** Tích hợp bộ phát `uart_tx` nội bộ giúp kiểm thử trực tiếp bằng các công tắc gạt `SW[7:0]` và nút nhấn `KEY[2]` ngay trên kit DE2-115 mà không cần cáp RS-232 ngoài.
- **Hiển thị trực quan:**
  - Hiển thị mã Hexa của byte thu được trên 2 LED 7 đoạn `HEX1`, `HEX0`.
  - Hiển thị mã nhị phân 8-bit trên `LEDR[7:0]`.
  - Hiển thị bộ đếm tổng số byte thu thành công trên `HEX3`, `HEX2`.
  - Kéo giãn xung báo nhận thành công (`LEDG[0]`) và lỗi khung truyền (`LEDG[1]`) lên $100\text{ ms}$ nhờ module `pulse_stretcher` để mắt người quan sát rõ.

---

## Cấu trúc thư mục

```text
UART/
├── rtl/                                      # Mã nguồn RTL (VHDL chuẩn tổng hợp)
│   ├── uart_rx.vhd                           # Lõi bộ thu UART Receiver (FSM + 16x Oversampling)
│   ├── uart_tx.vhd                           # Bộ phát UART Transmitter (phục vụ On-Board Loopback)
│   ├── hex_to_7seg.vhd                       # Giải mã Hex 4-bit sang LED 7 đoạn (Active-Low)
│   ├── pulse_stretcher.vhd                   # Kéo giãn xung 1 chu kỳ (20 ns) thành 100 ms
│   └── uart_rx_top.vhd                       # Thực thể mức đỉnh (Top-level Entity) cho Kit DE2-115
├── sim/                                      # Môi trường mô phỏng kiểm chứng (ModelSim)
│   ├── tb_uart_rx.vhd                        # Testbench tự động kiểm tra 5 kịch bản (Self-checking)
│   ├── run.do                                # Script tự động biên dịch và cấu hình cửa sổ Waveform
│   └── CHAY_MO_PHONG_WAVE.bat                # Script khởi chạy nhanh mô phỏng dạng sóng
├── output_files/                             # Kết quả tổng hợp & Bitstream nạp Kit (.sof, .rpt)
│   └── DE2_115_UART_RX.sof                   # File cấu hình FPGA sẵn sàng nạp vào Kit DE2-115
├── DE2_115_UART_RX.qpf                       # File Project Intel Quartus Prime 20.1
├── DE2_115_UART_RX.qsf                       # File cấu hình chân (Pin Assignments) cho DE2-115
├── DE2_115_UART_RX.sdc                       # Ràng buộc định thời (Synopsys Design Constraints - 50 MHz)
├── CHAY_MO_PHONG_WAVE.bat                    # Chạy nhanh mô phỏng ModelSim từ thư mục gốc
├── MO_QUARTUS.bat                            # Mở nhanh dự án trên Intel Quartus Prime
├── NAP_KIT_FPGA.bat                          # Nạp tự động file .sof xuống Kit DE2-115 qua USB-Blaster
├── BAO_CAO_DO_AN_UART_RECEIVER.md            # Báo cáo đồ án chi tiết (Markdown)
├── BAO_CAO_DO_AN_UART_RECEIVER.docx          # Báo cáo đồ án chi tiết (Word)
├── NGUYEN_LY_HOAT_DONG_VA_SO_DO_UART_RX.md   # Tài liệu nguyên lý hoạt động & sơ đồ khối/FSM
├── GIAI_THICH_CHI_TIET_TUNG_DONG_CODE.md     # Giải thích chi tiết từng dòng mã VHDL
└── HUONG_DAN_TEST_KIT_CHI_TIET.md            # Hướng dẫn vận hành và kiểm thử thực tế trên Kit
```

---

## Hướng dẫn sử dụng nhanh

### 1. Chạy mô phỏng dạng sóng (ModelSim 20.1)
Nhấp đúp vào file [`CHAY_MO_PHONG_WAVE.bat`](CHAY_MO_PHONG_WAVE.bat). Script sẽ tự động gọi ModelSim, biên dịch toàn bộ RTL + Testbench và mở cửa sổ Waveform với 5 kịch bản kiểm thử:
1. Nhận ký tự `'A'` (`0x41`)
2. Nhận ký tự `'5'` (`0x35`)
3. Nhận giá trị biên `0xFF` và `0x00`
4. Lọc nhiễu gai xung đường truyền (Start-bit Glitch Rejection)
5. Phát hiện lỗi mất bit dừng (Framing Error Detection)

### 2. Tổng hợp và Nạp xuống Kit FPGA DE2-115
- **Mở dự án Quartus:** Chạy [`MO_QUARTUS.bat`](MO_QUARTUS.bat).
- **Nạp nhanh Bitstream (`.sof`):** Kết nối cáp USB-Blaster vào cổng `BLASTER` trên Kit DE2-115, bật nguồn và chạy [`NAP_KIT_FPGA.bat`](NAP_KIT_FPGA.bat).

### 3. Kiểm thử trên Kit DE2-115
- **Chế độ 1 — Tự kiểm tra nội bộ (On-Board Loopback):**
  1. Gạt `SW[17]` lên mức `1` (`LEDR[17]` sáng).
  2. Nhấn `KEY[0]` để Reset hệ thống (`HEX3..HEX0` hiển thị `0000`).
  3. Đặt mã nhị phân 8-bit bất kỳ trên `SW[7:0]` (ví dụ `01000001` = `0x41`).
  4. Nhấn `KEY[2]` để phát khung UART nội bộ -> Quan sát `HEX1..0` hiển thị `41`, `LEDG[0]` nháy sáng xanh, và bộ đếm `HEX3..2` tăng thêm 1.
- **Chế độ 2 — Nhận dữ liệu từ máy tính qua cổng RS-232 (`UART_RXD` - Pin `G12`):**
  1. Gạt `SW[17]` xuống mức `0`.
  2. Kết nối cáp USB-to-RS232 vào cổng DB9 trên Kit DE2-115.
  3. Mở phần mềm Terminal (PuTTY / Hercules / RealTerm) với cấu hình **115200 bps, 8 Data bits, No Parity, 1 Stop bit, Flow Control: None** và gõ phím để truyền ký tự xuống FPGA.
