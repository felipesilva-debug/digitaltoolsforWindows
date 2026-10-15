@echo off
chcp 65001 >nul
mode con: cols=100 lines=35
title Ferramentas Digitais
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0FerramentasDigitais.ps1"
pause