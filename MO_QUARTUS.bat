@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
title Mở dự án Quartus Prime DE2-115 UART Receiver

echo ===============================================================================
echo     Đang khởi động Intel Quartus Prime với dự án DE2_115_UART_RX...
echo ===============================================================================

set "QPF_FILE=%~dp0DE2_115_UART_RX.qpf"
set "QUARTUS_BIN="

:: 1. Dò tìm qua biến môi trường QUARTUS_ROOTDIR
if defined QUARTUS_ROOTDIR (
    for %%P in (
        "%QUARTUS_ROOTDIR%\bin64\quartus.exe"
        "%QUARTUS_ROOTDIR%\bin\quartus.exe"
        "%QUARTUS_ROOTDIR%\quartus\bin64\quartus.exe"
        "%QUARTUS_ROOTDIR%\quartus\bin\quartus.exe"
    ) do (
        if not defined QUARTUS_BIN if exist "%%~fP" set "QUARTUS_BIN=%%~fP"
    )
)

:: 2. Dò tìm lệnh quartus trong biến môi trường PATH
if not defined QUARTUS_BIN (
    for /f "delims=" %%I in ('where quartus 2^>nul') do (
        if not defined QUARTUS_BIN set "QUARTUS_BIN=%%I"
    )
)

:: 3. Kiểm tra đường dẫn mặc định phổ biến 20.1
if not defined QUARTUS_BIN (
    if exist "C:\intelFPGA_lite\20.1\quartus\bin64\quartus.exe" (
        set "QUARTUS_BIN=C:\intelFPGA_lite\20.1\quartus\bin64\quartus.exe"
    ) else if exist "C:\intelFPGA_lite\20.1\quartus\bin\quartus.exe" (
        set "QUARTUS_BIN=C:\intelFPGA_lite\20.1\quartus\bin\quartus.exe"
    )
)

:: 4. Quét tự động các ổ đĩa C:, D:, E: với mọi phiên bản Quartus
if not defined QUARTUS_BIN (
    for %%D in (C D E) do (
        for %%F in (intelFPGA_lite intelFPGA altera altera_lite) do (
            if exist "%%D:\%%F\" (
                for /d %%V in ("%%D:\%%F\*") do (
                    if not defined QUARTUS_BIN if exist "%%~fV\quartus\bin64\quartus.exe" set "QUARTUS_BIN=%%~fV\quartus\bin64\quartus.exe"
                    if not defined QUARTUS_BIN if exist "%%~fV\quartus\bin\quartus.exe" set "QUARTUS_BIN=%%~fV\quartus\bin\quartus.exe"
                )
            )
        )
    )
)

if defined QUARTUS_BIN (
    echo [*] Tìm thấy Quartus Prime tại: "!QUARTUS_BIN!"
    start "" "!QUARTUS_BIN!" "%QPF_FILE%"
    echo [OK] Đã mở Quartus Prime!
) else (
    echo [*] Không tìm thấy quartus.exe ở đường dẫn cố định, đang mở dự án bằng ứng dụng mặc định của Windows...
    start "" "%QPF_FILE%"
)

timeout /t 3 >nul
exit /b 0
