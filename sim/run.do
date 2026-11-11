# ==============================================================================
# ModelSim DO Script: run.do
# Project  : UART Receiver using FSM on Terasic DE2-115
# Author   : FPGA Design Engineer
# ==============================================================================

# 1. Tao thu vien va anh xa thu vien work
if [file exists work] {
    vdel -lib work -all
}
vlib work
vmap work work

# 2. Bien dich cac file thiet ke VHDL chuẩn 2008
puts ">>> Dang bien dich cac file RTL..."
vcom -2008 -work work ../rtl/uart_rx.vhd
vcom -2008 -work work tb_uart_rx.vhd

# 3. Khoi tao mo phong
puts ">>> Khoi chay mo phong DUT tb_uart_rx..."
vsim -t 1ps -lib work tb_uart_rx

# 4. Thiet lap cua so song Waveform voi Radix truc quan
quietly wave cursor active 1

add wave -divider "HE THONG CLOCK & RESET"
add wave -color "Yellow" -label "CLK_50MHz"       sim:/tb_uart_rx/clk
add wave -color "Red"    -label "RST_N"           sim:/tb_uart_rx/rst_n

add wave -divider "DUONG TRUYEN NOI TIEP UART"
add wave -color "Cyan"   -label "RX_SERIAL"       sim:/tb_uart_rx/rx
add wave -color "Orange" -label "RX_SYNC"         sim:/tb_uart_rx/dut/rx_sync
add wave -color "White"  -label "FALLING_EDGE"    sim:/tb_uart_rx/dut/rx_falling_edge

add wave -divider "BO CHIA BAUD OVERSAMPLING 16X"
add wave -color "Magenta" -label "BAUD_TICK_16X"  sim:/tb_uart_rx/dut/baud_tick_16x
add wave -radix unsigned -label "BAUD_DIV_CNT"    sim:/tb_uart_rx/dut/baud_counter
add wave -radix unsigned -label "TICK_CNT"        sim:/tb_uart_rx/dut/tick_cnt_reg

add wave -divider "FSM RECEIVER MOORE"
add wave -color "Green"  -radix ASCII -label "FSM_STATE" sim:/tb_uart_rx/dut/state_reg
add wave -radix binary   -label "FSM_DBG_LEDR"   sim:/tb_uart_rx/fsm_state_dbg
add wave -radix unsigned -label "BIT_CNT"         sim:/tb_uart_rx/dut/bit_cnt_reg
add wave -radix hex      -label "SHIFT_REG"       sim:/tb_uart_rx/dut/data_reg

add wave -divider "DAU RA DULIEU VA CO TRANG THAI"
add wave -color "Green"  -label "RX_DONE_PULSE"   sim:/tb_uart_rx/rx_done
add wave -color "Yellow" -radix hex -label "RX_DATA" sim:/tb_uart_rx/rx_data
add wave -color "Red"    -label "FRAME_ERR"       sim:/tb_uart_rx/frame_err
add wave -color "Red"    -label "PARITY_ERR"      sim:/tb_uart_rx/parity_err

# 5. Cau hinh giao dien Wave
configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

# 6. Chay toan bo cac kich ban
puts ">>> Dang chay toan bo cac kich ban kiem thu..."
run -all

# 7. Tu dong zoom vua toan man hinh dang song
wave zoom full
puts ">>> Mo phong hoan tat! Quan sat dang song tren cua so Wave."
