@echo off
chcp 65001 >nul
title Khởi chạy mô phỏng ModelSim UART Receiver Waveform
echo ===============================================================================
echo     Đang mở ModelSim và tự động vẽ dạng sóng...
echo ===============================================================================

set "MODELSIM_BIN=C:\intelFPGA_lite\20.1\modelsim_ase\win32aloem\vsim.exe"

if exist "%MODELSIM_BIN%" (
    start "" "%MODELSIM_BIN%" -gui -do "run.do"
) else (
    start "" vsim -gui -do "run.do"
)

exit
