@echo off
setlocal EnableExtensions

:: ===== Elevação UAC (relança a própria BAT) =====
fltmc >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$p=[System.IO.Path]::GetFullPath('%~f0');$wd=Split-Path -Parent $p;Start-Process -FilePath $p -ArgumentList '/PROD' -WorkingDirectory $wd -Verb RunAs"
  exit /b
)
if /i "%~1"=="/PROD" shift

:: ===== Config =====
set "TARGET_DESKTOP=Desktop"   :: use 'CommonDesktopDirectory' para Desktop de todos
set "LOCAL_EXE=C:\Administracao\SplashtopSOSPontual.exe"
set "LOCAL_WD=C:\Administracao"
set "SHORTCUT_NAME=Splashtop SOS Pontual.lnk"

:: ===== PARTE 1 (sem mudar) =====
copy "C:\Administracao\RBuilder.ini" "C:\Windows\System32\" /Y >nul 2>&1
copy "C:\Administracao\RBuilder.ini" "C:\Windows\SysWOW64\" /Y >nul 2>&1
icacls "C:\Windows\System32\rbuilder.ini" /grant:r Todos:(F) /c >nul 2>&1
icacls "C:\Windows\SysWOW64\rbuilder.ini" /grant:r Todos:(F) /c >nul 2>&1
echo RBuilder.ini

:: ===== PARTE 2 (sem download; usa executável local e cria atalho .LNK) =====

:: Resolve o caminho do Desktop alvo
for /f "usebackq delims=" %%D in (`
  powershell -NoProfile -Command "[Environment]::GetFolderPath('%TARGET_DESKTOP%')"
`) do set "DESKTOP=%%D"

if not exist "%DESKTOP%" md "%DESKTOP%" >nul 2>&1

set "SHORTCUT_LNK=%DESKTOP%\%SHORTCUT_NAME%"

:: Valida se o executável local existe
if not exist "%LOCAL_EXE%" (
  echo [ERRO] Nao foi encontrado: "%LOCAL_EXE%"
  echo Verifique o caminho/arquivo e execute novamente.
  exit /b 3
)

:: Cria atalho .LNK apontando para o executável local (ícone do próprio exe)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$WScriptShell=New-Object -ComObject WScript.Shell;" ^
  "$s=$WScriptShell.CreateShortcut('%SHORTCUT_LNK%');" ^
  "$s.TargetPath='%LOCAL_EXE%';" ^
  "$s.WorkingDirectory='%LOCAL_WD%';" ^
  "$s.IconLocation='%LOCAL_EXE%,0';" ^
  "$s.Save()" >nul 2>&1

:: Executa o aplicativo
start "" "%LOCAL_EXE%"

exit /b 0