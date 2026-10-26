@echo off
setlocal EnableDelayedExpansion

REM ============================================================
REM  CONFIG_BDE.BAT
REM  Baixa e aplica a configuracao padrao do BDE (IDAPI32.CFG) e
REM  prepara a pasta de controle de rede do Paradox (NET DIR).
REM
REM  COMO USAR:
REM   1) Numa maquina de referencia, altere o NET DIR no BDE
REM      Administrator para C:\Administracao e salve.
REM   2) Publique o IDAPI32.CFG dessa maquina numa URL de DOWNLOAD
REM      DIRETO (nao link de compartilhamento) e de preferencia
REM      com autenticacao. Ajuste CFG_URL abaixo.
REM   3) Gere o hash NA MAQUINA DE ORIGEM e cole em HASH_ESPERADO:
REM         certutil -hashfile "C:\Program Files (x86)\Borland\Common Files\BDE\IDAPI32.CFG" SHA256
REM   4) Rode este .bat como Administrador nas demais maquinas.
REM ============================================================

REM ---------- PARAMETROS (ajuste aqui) ------------------------
set "NETDIR=C:\Administracao"
set "CFG_URL=https://raw.githubusercontent.com/Clebio2030/instaladorpontual/master/IDAPI32.CFG"
REM Hash SHA256 do arquivo publicado. Deixe vazio para pular a
REM verificacao (NAO recomendado).
set "HASH_ESPERADO=6808cf9daa5c990e8277ee45812a9df4b9c7d78c742a0d49ab500ae3d4f5fb3d"
set "BACKUPDIR=C:\BDE_Backup"
REM Processos que precisam estar fechados (separados por espaco)
set "PROCESSOS=Automec.exe Climb.exe bdeadmin.exe"
REM Fallback local caso a maquina esteja sem internet (opcional)
set "CFG_FALLBACK="
REM ------------------------------------------------------------

set "TEMPCFG=%TEMP%\IDAPI32.download.cfg"

echo.
echo === Configuracao do BDE ===
echo.

REM ---------- 1. Verifica elevacao ----------------------------
net session >nul 2>&1
if errorlevel 1 (
    echo [ERRO] Este script precisa ser executado como Administrador.
    echo        Clique com o botao direito e escolha "Executar como administrador".
    echo.
    pause
    exit /b 1
)
echo [OK] Executando com privilegios de administrador.

REM ---------- 2. Verifica se ha processos abertos --------------
set "EMUSO="
for %%P in (%PROCESSOS%) do (
    tasklist /FI "IMAGENAME eq %%P" 2>nul | find /I "%%P" >nul
    if not errorlevel 1 (
        echo [ERRO] O processo %%P esta em execucao.
        set "EMUSO=1"
    )
)
if defined EMUSO (
    echo.
    echo Feche o sistema em TODAS as estacoes antes de continuar.
    pause
    exit /b 1
)
echo [OK] Nenhum processo do sistema em execucao.

REM ---------- 3. Baixa o arquivo mestre ------------------------
del /F /Q "%TEMPCFG%" >nul 2>&1
echo [..] Baixando configuracao de %CFG_URL%

where curl >nul 2>&1
if not errorlevel 1 (
    curl -fsSL --retry 2 --connect-timeout 15 -o "%TEMPCFG%" "%CFG_URL%"
) else (
    certutil -urlcache -split -f "%CFG_URL%" "%TEMPCFG%" >nul 2>&1
    certutil -urlcache "%CFG_URL%" delete >nul 2>&1
)

if not exist "%TEMPCFG%" (
    echo [AVISO] Download falhou. Tentando fallback local...
    if exist "%CFG_FALLBACK%" (
        copy /Y "%CFG_FALLBACK%" "%TEMPCFG%" >nul
        echo [OK] Arquivo obtido do fallback local.
    ) else (
        echo [ERRO] Sem download e sem fallback disponivel. Abortando.
        pause
        exit /b 1
    )
) else (
    echo [OK] Download concluido.
)

REM ---------- 4. Valida o arquivo baixado ----------------------
REM 4a. Tamanho minimo: pagina de erro HTML costuma ser pequena
set "TAM=0"
for %%A in ("%TEMPCFG%") do set "TAM=%%~zA"
if !TAM! LSS 1024 (
    echo [ERRO] Arquivo baixado tem apenas !TAM! bytes.
    echo        A URL provavelmente devolveu uma pagina de erro,
    echo        nao o IDAPI32.CFG. Verifique se e download direto.
    del /F /Q "%TEMPCFG%" >nul 2>&1
    pause
    exit /b 1
)

REM 4b. Rejeita conteudo HTML
find /I "<html" "%TEMPCFG%" >nul 2>&1
if not errorlevel 1 (
    echo [ERRO] O arquivo baixado e uma pagina HTML, nao o CFG.
    echo        Use um link de download direto.
    del /F /Q "%TEMPCFG%" >nul 2>&1
    pause
    exit /b 1
)

REM 4c. Confere o hash SHA256
if defined HASH_ESPERADO (
    set "HASH="
    for /f "skip=1 delims=" %%H in ('certutil -hashfile "%TEMPCFG%" SHA256 ^| find /I /V "certutil"') do (
        if not defined HASH set "HASH=%%H"
    )
    set "HASH=!HASH: =!"
    if /I not "!HASH!"=="%HASH_ESPERADO%" (
        echo [ERRO] Hash nao confere. Arquivo corrompido ou adulterado.
        echo        Esperado: %HASH_ESPERADO%
        echo        Obtido:   !HASH!
        del /F /Q "%TEMPCFG%" >nul 2>&1
        pause
        exit /b 1
    )
    echo [OK] Integridade verificada ^(SHA256^).
) else (
    echo [AVISO] HASH_ESPERADO vazio - integridade nao verificada.
)

REM 4d. Se nao ha hash, confere o NET DIR pelo conteudo
if not defined HASH_ESPERADO (
    echo $s=[Text.Encoding]::ASCII.GetString^([IO.File]::ReadAllBytes^($args[0]^)^) > "%TEMP%\chk_bde.ps1"
    echo if^($s -match [regex]::Escape^($args[1]^)^){"SIM"}else{"NAO"} >> "%TEMP%\chk_bde.ps1"
    set "ACHOU="
    for /f "delims=" %%R in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\chk_bde.ps1" "%TEMPCFG%" "%NETDIR%" 2^>nul') do set "ACHOU=%%R"
    del /F /Q "%TEMP%\chk_bde.ps1" >nul 2>&1
    if /I "!ACHOU!"=="NAO" (
        echo [AVISO] Nao encontrei "%NETDIR%" dentro do arquivo baixado.
        echo.
        choice /C SN /M "Aplicar mesmo assim"
        if errorlevel 2 (
            del /F /Q "%TEMPCFG%" >nul 2>&1
            exit /b 1
        )
    )
)

REM ---------- 5. Localiza o IDAPI32.CFG pelo registro ----------
set "CFG="
for /f "tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Borland\Database Engine" /v CONFIGFILE01 2^>nul ^| find "CONFIGFILE01"') do set "CFG=%%b"
if not defined CFG (
    for /f "tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\Borland\Database Engine" /v CONFIGFILE01 2^>nul ^| find "CONFIGFILE01"') do set "CFG=%%b"
)
if not defined CFG (
    echo [AVISO] Nao encontrei CONFIGFILE01 no registro. Usando caminho padrao.
    set "CFG=%ProgramFiles(x86)%\Borland\Common Files\BDE\IDAPI32.CFG"
)
echo [OK] Arquivo de configuracao: !CFG!

REM ---------- 6. Cria a pasta do NET DIR -----------------------
if not exist "%NETDIR%" (
    mkdir "%NETDIR%" 2>nul
    if errorlevel 1 (
        echo [ERRO] Nao foi possivel criar a pasta %NETDIR%.
        pause
        exit /b 1
    )
    echo [OK] Pasta %NETDIR% criada.
) else (
    echo [OK] Pasta %NETDIR% ja existe.
)

REM ---------- 7. Permissoes de leitura/escrita -----------------
echo [..] Ajustando permissoes da pasta...
icacls "%NETDIR%" /grant "*S-1-5-32-545":(OI)(CI)M >nul 2>&1
if errorlevel 1 (
    echo [AVISO] Nao consegui ajustar as permissoes. Verifique manualmente.
) else (
    echo [OK] Permissoes de modificacao concedidas aos usuarios.
)

REM ---------- 8. Backup do CFG atual ---------------------------
if not exist "%BACKUPDIR%" mkdir "%BACKUPDIR%" >nul 2>&1
if exist "!CFG!" (
    set "STAMP=%DATE:/=-%_%TIME::=-%"
    set "STAMP=!STAMP: =0!"
    set "STAMP=!STAMP:,=.!"
    copy /Y "!CFG!" "%BACKUPDIR%\IDAPI32_!STAMP!.cfg" >nul
    if errorlevel 1 (
        echo [ERRO] Falha ao criar o backup. Abortando por seguranca.
        pause
        exit /b 1
    )
    echo [OK] Backup salvo em %BACKUPDIR%.
) else (
    echo [AVISO] Nenhum IDAPI32.CFG existente encontrado para backup.
)

REM ---------- 9. Aplica a configuracao -------------------------
copy /Y "%TEMPCFG%" "!CFG!" >nul
if errorlevel 1 (
    echo [ERRO] Falha ao gravar o IDAPI32.CFG. Configuracao nao alterada.
    pause
    exit /b 1
)
del /F /Q "%TEMPCFG%" >nul 2>&1
echo [OK] IDAPI32.CFG atualizado.

REM ---------- 10. Limpa arquivos de controle antigos -----------
if exist "C:\PDOXUSRS.NET" (
    del /F /Q "C:\PDOXUSRS.NET" >nul 2>&1
    if errorlevel 1 (
        echo [AVISO] Nao consegui remover C:\PDOXUSRS.NET ^(pode estar em uso^).
    ) else (
        echo [OK] PDOXUSRS.NET antigo removido de C:\.
    )
)
del /F /Q "%NETDIR%\PDOXUSRS.NET" >nul 2>&1
del /F /Q "%NETDIR%\PARADOX.LCK" >nul 2>&1
del /F /Q "%NETDIR%\PDOXUSRS.LCK" >nul 2>&1

echo.
echo === Concluido ===
echo NET DIR configurado para: %NETDIR%
echo Abra o sistema e confirme que o PDOXUSRS.NET e criado nessa pasta.
echo.
pause
endlocal