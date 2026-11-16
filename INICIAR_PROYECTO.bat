@echo off
title Lanzador Proyecto #3 - INFO1128 (Visor MP 2.5 um + Servidor TCP/IP SQLite)
echo ============================================================================
echo   INICIANDO PROYECTO #3 - INTERFACES GRAFICAS (INFO1128)
echo ============================================================================
echo.
echo [1/2] Iniciando Servidor TCP/IP Consola (SQLite Tabla Aire)...
start "Servidor TCP/IP - Tabla Aire" "%~dp0server_tcp\servidor_tcp_aire.exe"
timeout /t 1 /nobreak >nul
echo [2/2] Iniciando Visor Grafico MP 2.5 um (Lazarus Free Pascal)...
start "" "%~dp0visor_mp25\visor_mp25.exe"
echo.
echo Listo. Ambos programas estan en ejecucion.
