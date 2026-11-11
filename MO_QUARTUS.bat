@echo off
chcp 65001 >nul
title Mở dự án Quartus Prime DE2-115 UART Receiver
echo ===============================================================================
echo     Đang khởi động Intel Quartus Prime với dự án DE2_115_UART_RX...
echo ===============================================================================

set "QUARTUS_BIN=C:\intelFPGA_lite\20.1\quartus\bin64\quartus.exe"

if exist "%QUARTUS_BIN%" (
    echo [*] Tìm thấy Quartus Prime tại: %QUARTUS_BIN%
    start "" "%QUARTUS_BIN%" "%~dp0DE2_115_UART_RX.qpf"
) else (
    echo [*] Đang thử mở quartus từ biến môi trường PATH...
    start "" quartus "%~dp0DE2_115_UART_RX.qpf"
)

echo [OK] Đã mở Quartus Prime!
timeout /t 3 >nul
exit
