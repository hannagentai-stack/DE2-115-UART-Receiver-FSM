@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
title Nạp file SOF vào Kit DE2-115

echo ===============================================================================
echo     ĐỒ ÁN: UART RECEIVER FSM - NẠP BITSTREAM VÀO KIT DE2-115
echo ===============================================================================

set "SOF_FILE=%~dp0output_files\DE2_115_UART_RX.sof"
set "PGM_EXE="
set "QUARTUS_BIN="

if not exist "%SOF_FILE%" (
    echo [ERROR] Không tìm thấy file: "%SOF_FILE%"
    echo Hãy mở Quartus để biên dịch trước khi nạp!
    pause
    exit /b 1
)

:: 1. Dò tìm qua biến môi trường QUARTUS_ROOTDIR
if defined QUARTUS_ROOTDIR (
    for %%P in (
        "%QUARTUS_ROOTDIR%\bin64\quartus_pgm.exe"
        "%QUARTUS_ROOTDIR%\bin\quartus_pgm.exe"
        "%QUARTUS_ROOTDIR%\quartus\bin64\quartus_pgm.exe"
        "%QUARTUS_ROOTDIR%\quartus\bin\quartus_pgm.exe"
    ) do (
        if not defined PGM_EXE if exist "%%~fP" set "PGM_EXE=%%~fP"
    )
    for %%P in (
        "%QUARTUS_ROOTDIR%\bin64\quartus.exe"
        "%QUARTUS_ROOTDIR%\bin\quartus.exe"
        "%QUARTUS_ROOTDIR%\quartus\bin64\quartus.exe"
        "%QUARTUS_ROOTDIR%\quartus\bin\quartus.exe"
    ) do (
        if not defined QUARTUS_BIN if exist "%%~fP" set "QUARTUS_BIN=%%~fP"
    )
)

:: 2. Dò tìm trong biến môi trường PATH
if not defined PGM_EXE (
    for /f "delims=" %%I in ('where quartus_pgm 2^>nul') do (
        if not defined PGM_EXE set "PGM_EXE=%%I"
    )
)
if not defined QUARTUS_BIN (
    for /f "delims=" %%I in ('where quartus 2^>nul') do (
        if not defined QUARTUS_BIN set "QUARTUS_BIN=%%I"
    )
)

:: 3. Kiểm tra đường dẫn mặc định phổ biến 20.1
if not defined PGM_EXE (
    if exist "C:\intelFPGA_lite\20.1\quartus\bin64\quartus_pgm.exe" (
        set "PGM_EXE=C:\intelFPGA_lite\20.1\quartus\bin64\quartus_pgm.exe"
    ) else if exist "C:\intelFPGA_lite\20.1\quartus\bin\quartus_pgm.exe" (
        set "PGM_EXE=C:\intelFPGA_lite\20.1\quartus\bin\quartus_pgm.exe"
    )
)
if not defined QUARTUS_BIN (
    if exist "C:\intelFPGA_lite\20.1\quartus\bin64\quartus.exe" (
        set "QUARTUS_BIN=C:\intelFPGA_lite\20.1\quartus\bin64\quartus.exe"
    ) else if exist "C:\intelFPGA_lite\20.1\quartus\bin\quartus.exe" (
        set "QUARTUS_BIN=C:\intelFPGA_lite\20.1\quartus\bin\quartus.exe"
    )
)

:: 4. Quét tự động các ổ đĩa C:, D:, E: với mọi phiên bản Quartus
if not defined PGM_EXE (
    for %%D in (C D E) do (
        for %%F in (intelFPGA_lite intelFPGA altera altera_lite) do (
            if exist "%%D:\%%F\" (
                for /d %%V in ("%%D:\%%F\*") do (
                    if not defined PGM_EXE if exist "%%~fV\quartus\bin64\quartus_pgm.exe" set "PGM_EXE=%%~fV\quartus\bin64\quartus_pgm.exe"
                    if not defined PGM_EXE if exist "%%~fV\quartus\bin\quartus_pgm.exe" set "PGM_EXE=%%~fV\quartus\bin\quartus_pgm.exe"
                )
            )
        )
    )
)
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

echo [*] File nạp: "%SOF_FILE%"
echo [*] Đang kiểm tra cáp USB-Blaster kết nối với máy tính...

if defined PGM_EXE (
    echo [*] Sử dụng công cụ nạp: "!PGM_EXE!"
    "!PGM_EXE!" -l
    echo [*] Bắt đầu nạp file "%SOF_FILE%" qua giao tiếp JTAG...
    "!PGM_EXE!" -m JTAG -o "p;%SOF_FILE%"
    if !ERRORLEVEL! EQU 0 goto :PGM_SUCCESS
)

echo.
echo [THÔNG BÁO] Không thể nạp trực tiếp qua dòng lệnh, hãy kiểm tra cáp USB-Blaster và nguồn 12V.
if defined QUARTUS_BIN (
    echo Đang mở giao diện đồ họa Quartus Programmer: "!QUARTUS_BIN!"
    start "" "!QUARTUS_BIN!" --pgm
) else (
    echo [CẢNH BÁO] Không tìm thấy Quartus trên máy tính. Vui lòng kiểm tra lại cài đặt Quartus Prime!
)
pause
exit /b 1

:PGM_SUCCESS
echo.
echo ===============================================================================
echo [THÀNH CÔNG] ĐÃ NẠP XONG 100%% VÀO KIT DE2-115!
echo - Chế độ On-Board Test: Gạt SW[17] lên '1', chỉnh SW[7..0], nhấn KEY[2] để test.
echo - Chế độ PC ngoài: Gạt SW[17] xuống '0', kết nối cáp DB9 tốc độ 115200 8N1.
echo ===============================================================================
pause
exit /b 0
