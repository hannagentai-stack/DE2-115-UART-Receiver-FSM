@echo off
chcp 65001 >nul
title Nạp file SOF vào Kit DE2-115
echo ===============================================================================
echo     ĐỒ ÁN: UART RECEIVER FSM - NẠP BITSTREAM VÀO KIT DE2-115
echo ===============================================================================

set "SOF_FILE=%~dp0output_files\DE2_115_UART_RX.sof"
if not exist "%SOF_FILE%" (
    set "SOF_FILE=%~dp0synth\output_files\DE2_115_UART_RX.sof"
)

set "PGM_EXE=C:\intelFPGA_lite\20.1\quartus\bin64\quartus_pgm.exe"

if not exist "%SOF_FILE%" (
    echo [ERROR] Không tìm thấy file: %SOF_FILE%
    echo Hãy mở Quartus để biên dịch trước khi nạp!
    pause
    exit /b 1
)

echo [*] File nạp: %SOF_FILE%
echo [*] Đang kiểm tra cáp USB-Blaster kết nối với máy tính...
if exist "%PGM_EXE%" (
    "%PGM_EXE%" -l
    echo [*] Bắt đầu nạp file %SOF_FILE% qua giao tiếp JTAG...
    "%PGM_EXE%" -m JTAG -o "p;%SOF_FILE%"
    if %ERRORLEVEL% EQU 0 (
        echo.
        echo ===============================================================================
        echo [THÀNH CÔNG] ĐÃ NẠP XONG 100%% VÀO KIT DE2-115!
        echo - Chế độ On-Board Test: Gạt SW[17] lên '1', chỉnh SW[7..0], nhấn KEY[2] để test.
        echo - Chế độ PC ngoài: Gạt SW[17] xuống '0', kết nối cáp DB9 (115200 8N1).
        echo ===============================================================================
        pause
        exit /b 0
    )
)

echo.
echo [THÔNG BÁO] Không thể nạp trực tiếp qua dòng lệnh (kiểm tra cáp USB-Blaster / nguồn 12V).
echo Đang mở giao diện đồ họa Quartus Programmer...
start "" "C:\intelFPGA_lite\20.1\quartus\bin64\quartus.exe" --pgm
pause
