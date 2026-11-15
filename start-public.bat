@echo off
title EARTHSONIC - Public Online Server
cd /d "%~dp0"
cls
echo ===================================================================
echo             EARTHSONIC - 24/7 PUBLIC ONLINE SERVER
echo ===================================================================
echo.
echo [1/3] Starting Next.js Local Server on port 3100...
start "EARTHSONIC Dev Server" /min cmd /c "npm run dev"

echo [2/3] Waiting for server to initialize...
timeout /t 5 /nobreak >nul

echo [3/3] Launching Public HTTPS Cloudflare Tunnel...
del /f /q cloudflared.log 2>nul
echo.
echo ===================================================================
echo  Your Public HTTPS link will appear below in 5 seconds.
echo  Share this link with anyone on mobile or computer!
echo.
echo  KEEP THIS WINDOW OPEN to keep the link online.
echo ===================================================================
echo.
.\.cache\cloudflared.exe tunnel --url http://localhost:3100
pause
