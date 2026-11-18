@echo off
chcp 65001 >nul
title ToDesk 虚拟鼠标手感调试沙盒
echo ========================================================
echo   正在启动 ToDesk 风格虚拟鼠标交互调试环境...
echo ========================================================

set "TEMP=C:\Users\陈hh\AppData\Local\Temp"
set "TMP=C:\Users\陈hh\AppData\Local\Temp"
set "HTTP_PROXY=http://127.0.0.1:7897"
set "HTTPS_PROXY=http://127.0.0.1:7897"
set "PATH=D:\flutter\bin;%PATH%"

cd /d "%~dp0"
echo 启动 Chrome Web 实时交互调试窗口...
call flutter run -d chrome -t lib/test_mouse_standalone.dart --web-port=8099
pause
