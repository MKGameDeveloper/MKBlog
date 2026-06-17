@echo off
REM SkulLike game launcher - just double-click this file to play.
REM It serves the already-built  build\web  bundle and does NOT rebuild.
REM If you changed the source code, run the build batch first to rebuild,
REM then run this file again.
setlocal

REM Port 8000 is taken by Incredibuild Manager, so we use 8777.
set "PORT=8777"
set "URL=http://127.0.0.1:%PORT%"

cd /d "%~dp0build\web"
if not exist index.html (
  echo [ERROR] build\web\index.html not found - the game has not been built yet.
  echo         Run the build batch file once to build it, then re-run this file.
  echo.
  pause
  exit /b 1
)

REM Find a WORKING Python. Prefer the 'py -3' launcher: the bare 'python' is
REM sometimes the broken Microsoft Store stub that exits without serving.
set "PYCMD="
py -3 --version >nul 2>nul && set "PYCMD=py -3"
if not defined PYCMD ( python --version >nul 2>nul && set "PYCMD=python" )
if not defined PYCMD (
  echo [ERROR] Python not found. Install it from https://www.python.org
  echo.
  pause
  exit /b 1
)
echo [INFO] Using Python launcher: %PYCMD%

echo ============================================
echo  SkulLike running...  %URL%
echo  To stop: press Ctrl+C or close this window.
echo ============================================

REM Open the browser, then start the server bound to 127.0.0.1
start "" %URL%
%PYCMD% -m http.server %PORT% --bind 127.0.0.1

echo.
echo [INFO] Server stopped. (If it stopped instantly, port %PORT% may be in use.)
pause
