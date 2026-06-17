@echo off
REM SkulLike build-and-run launcher - double-click after changing source code.
REM Runs  flutter build web  first, then serves build\web and opens the browser.
setlocal

REM Port 8000 is taken by Incredibuild Manager, so we use 8777.
set "PORT=8777"
set "URL=http://127.0.0.1:%PORT%"

cd /d "%~dp0"

REM --- Step 1: build the web app ----------------------------------------
where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Flutter not found in PATH. Install it or add it to PATH.
  pause
  exit /b 1
)

echo ============================================
echo  Building web app...  ^(flutter build web^)
echo ============================================
REM --pwa-strategy=none disables the service worker so the browser never serves
REM a stale cached build after you change the source.
call flutter build web --pwa-strategy=none
if errorlevel 1 (
  echo.
  echo [ERROR] flutter build web failed. See the messages above.
  pause
  exit /b 1
)

if not exist "build\web\index.html" (
  echo [ERROR] build\web\index.html not found after build.
  pause
  exit /b 1
)

REM --- Step 2: serve and open the browser ------------------------------
cd /d "%~dp0build\web"

REM Find a Python launcher (python, then py -3)
set "PYCMD="
where python >nul 2>nul && set "PYCMD=python"
if not defined PYCMD ( where py >nul 2>nul && set "PYCMD=py -3" )
if not defined PYCMD (
  echo [ERROR] Python not found. Install it from https://www.python.org
  pause
  exit /b 1
)

echo ============================================
echo  SkulLike running...  %URL%
echo  To stop: press Ctrl+C or close this window.
echo ============================================

REM Open the browser, then start the server bound to 127.0.0.1
start "" %URL%
%PYCMD% -m http.server %PORT% --bind 127.0.0.1

echo.
echo [INFO] Server stopped. (Check above for any port-conflict errors.)
pause
