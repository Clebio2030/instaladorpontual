@echo off
setlocal EnableExtensions

:: =====================[ ELEVAÇÃO UAC ]=====================
fltmc >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$p=[System.IO.Path]::GetFullPath('%~f0');$wd=Split-Path -Parent $p;Start-Process -FilePath $p -ArgumentList '/PROD' -WorkingDirectory $wd -Verb RunAs"
  exit /b
)
if /i "%~1"=="/PROD" shift

:: =====================[ CONFIG PRODUÇÃO ]=====================
set "URL=https://download.splashtop.com/sos/SplashtopSOS.exe?_gl=1*1nb0362*_gcl_au*MjU4OTU0NjgyLjE3NTE2MzAwMDc.*_ga*MTk5NDA0Nzc3Ni4xNzUxNjMwMDEw*_ga_GKBXSKZ3NW*czE3NTI1MTY2NDMkbzMkZzAkdDE3NTI1MTY2NDMkajYwJGwwJGgxNTc3ODk0OTU."
set "TARGET_DESKTOP=Desktop"   :: ou CommonDesktopDirectory (para todos os usuários)
set "RUN_AFTER_DOWNLOAD=1"
set "CREATE_URL_FALLBACK=1"
set "EXPECTED_SHA256="         :: opcional: 64 hex chars para validar o arquivo

set "LOGDIR=%ProgramData%\Suporte\logs"
if not exist "%LOGDIR%" md "%LOGDIR%" >nul 2>&1
for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) do set "NOW=%%T"
set "LOGFILE=%LOGDIR%\rbuilder_%NOW%.log"
call :log "== INICIO =="

:: =====================[ PARTE 1 - MANTER COMO ESTÁ ]=====================
copy "C:\Administracao\RBuilder.ini" "C:\Windows\System32\" /Y >nul 2>&1
copy "C:\Administracao\RBuilder.ini" "C:\Windows\SysWOW64\" /Y >nul 2>&1
icacls "C:\Windows\System32\rbuilder.ini" /grant:r Todos:(F) /c >nul 2>&1
icacls "C:\Windows\SysWOW64\rbuilder.ini" /grant:r Todos:(F) /c >nul 2>&1
echo RBuilder.ini Concluído
call :log "Parte 1 concluida"

:: =====================[ PARTE 2 - DOWNLOAD + ATALHOS ]=====================
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('%TARGET_DESKTOP%')"`) do set "DESKTOP=%%D"
if not exist "%DESKTOP%" md "%DESKTOP%" >nul 2>&1
set "DOWNLOAD=%DESKTOP%\SplashtopSOS.exe"
set "SHORTCUT_LNK=%DESKTOP%\Splashtop SOS.lnk"
set "SHORTCUT_URL=%DESKTOP%\Splashtop SOS (baixar).url"
call :log "Destino: %DOWNLOAD%"

set "DL_OK=0"

:: T1: PowerShell (TLS + proxy do Windows)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;[System.Net.WebRequest]::DefaultWebProxy.Credentials=[System.Net.CredentialCache]::DefaultCredentials;Invoke-WebRequest -Uri '%URL%' -OutFile '%DOWNLOAD%' -UseBasicParsing -TimeoutSec 120" ^
  && set "DL_OK=1"

:: T2: curl
if "%DL_OK%"=="0" (
  curl.exe -L -o "%DOWNLOAD%" "%URL%" >nul 2>&1 && set "DL_OK=1"
)

:: T3: BITS
if "%DL_OK%"=="0" (
  bitsadmin /transfer splashtop /download /priority FOREGROUND "%URL%" "%DOWNLOAD%" >nul 2>&1
  if exist "%DOWNLOAD%" set "DL_OK=1"
)

:: T4: certutil
if "%DL_OK%"=="0" (
  certutil -urlcache -split -f "%URL%" "%DOWNLOAD%" >nul 2>&1 && set "DL_OK=1"
)

:: Verifica tamanho > 0
set "SZ=0"
if exist "%DOWNLOAD%" for %%A in ("%DOWNLOAD%") do set "SZ=%%~zA"
if "%DL_OK%"=="1" if "%SZ%"=="0" set "DL_OK=0"

if "%DL_OK%"=="1" (
  call :log "Download OK (%SZ% bytes)"

  :: Hash (log e validação opcional)
  for /f "usebackq delims=" %%H in (`powershell -NoProfile -Command "(Get-FileHash -Algorithm SHA256 -LiteralPath '%DOWNLOAD%').Hash"`) do set "SHA256=%%H"
  call :log "SHA256=%SHA256%"
  if defined EXPECTED_SHA256 (
    if /I not "%SHA256%"=="%EXPECTED_SHA256%" (
      call :log "ERRO: hash divergente. Esperado=%EXPECTED_SHA256%"
      del /f /q "%DOWNLOAD%" >nul 2>&1
      exit /b 3
    )
  )

  if "%RUN_AFTER_DOWNLOAD%"=="1" start "" "%DOWNLOAD%"
) else (
  call :log "Falha no download"
  if "%CREATE_URL_FALLBACK%"=="1" (
    > "%SHORTCUT_URL%" (
      echo [InternetShortcut]
      echo URL=%URL%
      echo IconFile=%SystemRoot%\System32\shell32.dll
      echo IconIndex=13
    )
    call :log "Criado atalho de internet: %SHORTCUT_URL%"
  )
)

:: Cria atalho .LNK (se o EXE existir, usa icone do proprio arquivo)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$lnk='%SHORTCUT_LNK%';$target='%DOWNLOAD%';$icon=(Test-Path $target)?($target+',0'):'%SystemRoot%\System32\shell32.dll,13';$s=(New-Object -ComObject WScript.Shell).CreateShortcut($lnk);$s.TargetPath=$target;$s.IconLocation=$icon;$s.WorkingDirectory='%DESKTOP%';$s.Save()" >nul 2>&1

call :log "== FIM =="
exit /b 0

:log
>>"%LOGFILE%" echo [%DATE% %TIME%] %~1
exit /b
