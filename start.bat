@echo off
title Minecraft Server Manager
chcp 65001 >nul

powershell -NoProfile -ExecutionPolicy Bypass ^
    -Command "[Console]::InputEncoding=[System.Text.UTF8Encoding]::new(); [Console]::OutputEncoding=[System.Text.UTF8Encoding]::new(); & '%~dp0Main.ps1'"

pause