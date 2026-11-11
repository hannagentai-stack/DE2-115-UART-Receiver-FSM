@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
title Khởi chạy mô phỏng ModelSim UART Receiver Waveform

echo ===============================================================================
echo     ĐỒ ÁN: THIẾT KẾ UART RECEIVER SỬ DỤNG FSM - KIT DE2-115
echo     Đang khởi chạy ModelSim, tự động nạp tín hiệu và vẽ dạng sóng ^(Waveform^)...
echo ===============================================================================

if not exist "%~dp0sim\run.do" (
    echo [ERROR] Không tìm thấy kịch bản mô phỏng: "%~dp0sim\run.do"
    pause
    exit /b 1
)

cd /d "%~dp0sim"

set "MODELSIM_BIN="

:: 1. Dò tìm qua biến môi trường QUARTUS_ROOTDIR (tự động tạo khi cài Quartus)
if defined QUARTUS_ROOTDIR (
    for %%P in (
        "%QUARTUS_ROOTDIR%\..\modelsim_ase\win32aloem\vsim.exe"
        "%QUARTUS_ROOTDIR%\..\modelsim_ae\win32aloem\vsim.exe"
        "%QUARTUS_ROOTDIR%\modelsim_ase\win32aloem\vsim.exe"
        "%QUARTUS_ROOTDIR%\modelsim_ae\win32aloem\vsim.exe"
    ) do (
        if not defined MODELSIM_BIN if exist "%%~fP" set "MODELSIM_BIN=%%~fP"
    )
)

:: 2. Dò tìm lệnh vsim trong biến môi trường PATH
if not defined MODELSIM_BIN (
    for /f "delims=" %%I in ('where vsim 2^>nul') do (
        if not defined MODELSIM_BIN set "MODELSIM_BIN=%%I"
    )
)

:: 3. Kiểm tra đường dẫn mặc định phổ biến (20.1)
if not defined MODELSIM_BIN (
    if exist "C:\intelFPGA_lite\20.1\modelsim_ase\win32aloem\vsim.exe" (
        set "MODELSIM_BIN=C:\intelFPGA_lite\20.1\modelsim_ase\win32aloem\vsim.exe"
    ) else if exist "C:\intelFPGA_lite\20.1\modelsim_ae\win32aloem\vsim.exe" (
        set "MODELSIM_BIN=C:\intelFPGA_lite\20.1\modelsim_ae\win32aloem\vsim.exe"
    )
)

:: 4. Quét tự động các ổ đĩa C:, D:, E: với mọi phiên bản Quartus/ModelSim
if not defined MODELSIM_BIN (
    for %%D in (C D E) do (
        for %%F in (intelFPGA_lite intelFPGA altera altera_lite) do (
            if exist "%%D:\%%F\" (
                for /d %%V in ("%%D:\%%F\*") do (
                    if not defined MODELSIM_BIN if exist "%%~fV\modelsim_ase\win32aloem\vsim.exe" set "MODELSIM_BIN=%%~fV\modelsim_ase\win32aloem\vsim.exe"
                    if not defined MODELSIM_BIN if exist "%%~fV\modelsim_ae\win32aloem\vsim.exe" set "MODELSIM_BIN=%%~fV\modelsim_ae\win32aloem\vsim.exe"
                    if not defined MODELSIM_BIN if exist "%%~fV\modelsim_ase\win32\vsim.exe" set "MODELSIM_BIN=%%~fV\modelsim_ase\win32\vsim.exe"
                    if not defined MODELSIM_BIN if exist "%%~fV\modelsim_ae\win32\vsim.exe" set "MODELSIM_BIN=%%~fV\modelsim_ae\win32\vsim.exe"
                )
            )
        )
    )
)

if defined MODELSIM_BIN (
    echo [*] Tìm thấy ModelSim tại: "!MODELSIM_BIN!"
    echo [*] Đang mở giao diện ModelSim Waveform...
    start "" "!MODELSIM_BIN!" -gui -do "run.do"
    echo [OK] Đã kích hoạt ModelSim thành công!
) else (
    echo [CẢNH BÁO] Không tìm thấy đường dẫn cài đặt ModelSim ^(vsim.exe^) trên máy.
    echo [*] Đang thử gọi trực tiếp vsim từ hệ thống...
    start "" vsim -gui -do "run.do"
)

timeout /t 3 >nul
exit /b 0
