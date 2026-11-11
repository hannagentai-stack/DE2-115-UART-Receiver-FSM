@echo off
chcp 65001 >nul
title Khởi chạy mô phỏng ModelSim UART Receiver Waveform
echo ===============================================================================
echo     ĐỒ ÁN: THIẾT KẾ UART RECEIVER SỬ DỤNG FSM - KIT DE2-115
echo     Đang khởi chạy ModelSim, tự động nạp tín hiệu và vẽ dạng sóng (Waveform)...
echo ===============================================================================

cd /d "%~dp0sim"

set "MODELSIM_BIN=C:\intelFPGA_lite\20.1\modelsim_ase\win32aloem\vsim.exe"

if exist "%MODELSIM_BIN%" (
    echo [*] Tìm thấy ModelSim tại: %MODELSIM_BIN%
    echo [*] Đang mở giao diện ModelSim Waveform...
    start "" "%MODELSIM_BIN%" -gui -do "run.do"
) else (
    echo [*] Đang thử gọi vsim từ biến môi trường PATH...
    start "" vsim -gui -do "run.do"
)

echo [OK] Đã kích hoạt ModelSim thành công!
timeout /t 3 >nul
exit
