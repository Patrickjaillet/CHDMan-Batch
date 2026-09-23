@echo off
title CHDMAN Tool
color 0A
setlocal EnableDelayedExpansion
chcp 65001 >nul

REM ============================================================
REM  CHDMAN TOOL - Interface complete pour chdman.exe
REM  Compression / Extraction / Verification de fichiers CHD
REM  Formats supportes en entree : CUE, GDI, ISO (CD et DVD)
REM  Internationalisation : i18n\*.lang (EN/FR/DE/ES/JA/ZH)
REM ============================================================

set "SCRIPT_DIR=%~dp0"
set "CHDMAN=%SCRIPT_DIR%chdman.exe"
set "I18N_DIR=%SCRIPT_DIR%i18n\"
set "CONFIG_FILE=%SCRIPT_DIR%chdman-tool.local.cfg"
set "DEFAULT_LANG=en"

REM ============================================================
REM  Journal d'execution : un fichier par lancement du script,
REM  horodate dans son nom, cree a cote du script (portable).
REM  PowerShell (present par defaut sur Windows 10 et 11) fournit
REM  un horodatage au format fixe AAAAMMJJ_hhmmss, independant
REM  des parametres regionaux de l'utilisateur (contrairement a
REM  %DATE%/%TIME%, dont le format varie selon la locale Windows
REM  active). "wmic", plus ancien, est deconseille depuis
REM  Windows 10 21H1 et retire par defaut sur les builds
REM  recentes de Windows 11.
REM ============================================================
set "LOGSTAMP="
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd_HHmmss'" 2^>nul`) do (
    if not defined LOGSTAMP set "LOGSTAMP=%%a"
)
if not defined LOGSTAMP set "LOGSTAMP=unknown"
set "LOG_FILE=%SCRIPT_DIR%chdman-tool_%LOGSTAMP%.log"

REM ============================================================
REM  Verifie que chdman.exe est present a cote du script
REM  (message affiche en anglais : aucun fichier de langue
REM  n'est encore garanti charge a ce stade)
REM ============================================================
if not exist "%CHDMAN%" (
    color 0C
    echo.
    echo  [ERROR] chdman.exe was not found in this folder:
    echo  %SCRIPT_DIR%
    echo.
    echo  Place CHDMAN_Tool.bat in the same folder as chdman.exe
    echo.
    pause
    exit /b 1
)

REM ============================================================
REM  Determination de la langue active
REM  Ordre de priorite :
REM   1) Langue memorisee dans le fichier de configuration local
REM   2) Langue detectee depuis les parametres regionaux systeme
REM   3) Anglais par defaut
REM ============================================================
set "ACTIVE_LANG="

if exist "%CONFIG_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%A in ("%CONFIG_FILE%") do (
        if /i "%%A"=="LANG" set "ACTIVE_LANG=%%B"
    )
)

if not defined ACTIVE_LANG (
    call :DETECT_SYSTEM_LANG
)

if not defined ACTIVE_LANG set "ACTIVE_LANG=%DEFAULT_LANG%"
if not exist "%I18N_DIR%%ACTIVE_LANG%.lang" set "ACTIVE_LANG=%DEFAULT_LANG%"

call :LOAD_LANG "%ACTIVE_LANG%"

REM Si aucun fichier de configuration n'existe encore (premier lancement),
REM proposer explicitement le choix de langue avant d'entrer dans le menu.
if not exist "%CONFIG_FILE%" call :LANGUAGE_MENU

goto MENU

REM ============================================================
REM  DETECT_SYSTEM_LANG - detection de la langue systeme Windows
REM  Utilise la variable d'environnement %LANG% si presente
REM  (WSL / environnements POSIX embarques), sinon interroge
REM  les parametres regionaux via la commande "reg query".
REM ============================================================
:DETECT_SYSTEM_LANG
set "SYS_LOCALE="

if defined LANG (
    set "SYS_LOCALE=%LANG%"
) else (
    for /f "tokens=3" %%L in ('reg query "HKCU\Control Panel\Desktop" /v PreferredUILanguages 2^>nul ^| findstr /i PreferredUILanguages') do set "SYS_LOCALE=%%L"
    if not defined SYS_LOCALE (
        for /f "skip=2 tokens=3" %%L in ('reg query "HKCU\Control Panel\International" /v LocaleName 2^>nul') do set "SYS_LOCALE=%%L"
    )
)

if not defined SYS_LOCALE (
    set "ACTIVE_LANG="
    exit /b 0
)

set "SYS_LOCALE_LC=%SYS_LOCALE%"
REM Normalisation grossiere : ne garder que les deux premiers caracteres
set "SYS_PREFIX=%SYS_LOCALE_LC:~0,2%"

if /i "%SYS_PREFIX%"=="fr" set "ACTIVE_LANG=fr"
if /i "%SYS_PREFIX%"=="de" set "ACTIVE_LANG=de"
if /i "%SYS_PREFIX%"=="es" set "ACTIVE_LANG=es"
if /i "%SYS_PREFIX%"=="ja" set "ACTIVE_LANG=ja"
if /i "%SYS_PREFIX%"=="zh" set "ACTIVE_LANG=zh"
if /i "%SYS_PREFIX%"=="en" set "ACTIVE_LANG=en"

exit /b 0

REM ============================================================
REM  LOAD_LANG - charge le fichier %1.lang dans des variables
REM  d'environnement (une variable par cle=valeur)
REM ============================================================
:LOAD_LANG
set "LANG_FILE=%I18N_DIR%%~1.lang"
if not exist "%LANG_FILE%" set "LANG_FILE=%I18N_DIR%%DEFAULT_LANG%.lang"

for /f "usebackq eol=; tokens=1,* delims==" %%K in ("%LANG_FILE%") do (
    if not "%%K"=="" set "%%K=%%L"
)
set "ACTIVE_LANG=%~1"
exit /b 0

REM ============================================================
REM  SAVE_LANG - memorise la langue choisie dans le fichier
REM  de configuration local (portable, a cote du script)
REM ============================================================
:SAVE_LANG
> "%CONFIG_FILE%" (
    echo LANG=%ACTIVE_LANG%
)
exit /b 0

REM ============================================================
REM  LANGUAGE_MENU - selecteur de langue interactif
REM ============================================================
:LANGUAGE_MENU
cls
echo ============================================================
echo   %LANGSEL_TITLE%
echo ============================================================
echo.
echo %LANGSEL_PROMPT%
echo.
echo   %LANGSEL_1%
echo   %LANGSEL_2%
echo   %LANGSEL_3%
echo   %LANGSEL_4%
echo   %LANGSEL_5%
echo   %LANGSEL_6%
echo.
echo ============================================================
set /p "LCHOICE=%LANGSEL_CHOICE% "

if "%LCHOICE%"=="1" (call :LOAD_LANG "en") else (
if "%LCHOICE%"=="2" (call :LOAD_LANG "fr") else (
if "%LCHOICE%"=="3" (call :LOAD_LANG "de") else (
if "%LCHOICE%"=="4" (call :LOAD_LANG "es") else (
if "%LCHOICE%"=="5" (call :LOAD_LANG "ja") else (
if "%LCHOICE%"=="6" (call :LOAD_LANG "zh") else (
    echo.
    echo %LANGSEL_INVALID%
    pause
    goto LANGUAGE_MENU
))))))

call :SAVE_LANG
exit /b 0

REM ============================================================
REM  CONFIRM_OVERWRITE - si le fichier passe en %1 existe deja,
REM  demande une confirmation interactive (o/N, reponse par
REM  defaut = non) avant de poursuivre. Positionne CONFIRM_RESULT
REM  a 1 pour continuer (fichier absent, ou confirmation positive)
REM  ou 0 pour annuler. Remplace l'usage systematique de "--force"
REM  sans confirmation (ROADMAP.md, Phase 3).
REM ============================================================
:CONFIRM_OVERWRITE
set "CONFIRM_RESULT=1"
if not exist "%~1" exit /b 0
echo.
echo %OVERWRITE_PROMPT%
echo   %~1
set "OWANSWER="
set /p "OWANSWER=%OVERWRITE_CONFIRM% "
if /i "%OWANSWER%"=="y" exit /b 0
if /i "%OWANSWER%"=="o" exit /b 0
if /i "%OWANSWER%"=="s" exit /b 0
if /i "%OWANSWER%"=="j" exit /b 0
set "CONFIRM_RESULT=0"
echo.
echo %OVERWRITE_CANCELLED%
pause
exit /b 0

REM ============================================================
REM  LOG_COMMAND - consigne une commande chdman executee et son
REM  resultat dans le journal d'execution (%LOG_FILE%). Le
REM  fichier n'est cree qu'au premier appel (aucun fichier
REM  residuel si le script est lance puis quitte sans effectuer
REM  d'operation). Arguments :
REM   %1 sous-commande chdman (createcd, verify, ...)
REM   %2 chemin d'entree
REM   %3 chemin de sortie (peut etre "" pour verify/info)
REM   %4 resultat ("OK" ou "FAILED")
REM ============================================================
:LOG_COMMAND
if not exist "%LOG_FILE%" (
    echo CHDman Batch - Execution log> "%LOG_FILE%"
    echo Started: %DATE% %TIME%>> "%LOG_FILE%"
    echo ============================================================>> "%LOG_FILE%"
)
if "%~3"=="" (
    echo [%DATE% %TIME%] %~4  %~1  input="%~2">> "%LOG_FILE%"
) else (
    echo [%DATE% %TIME%] %~4  %~1  input="%~2" output="%~3">> "%LOG_FILE%"
)
exit /b 0

REM ============================================================
:MENU
cls
echo ============================================================
echo                     %MENU_TITLE%
echo ============================================================
echo.
echo   %MENU_LANG_LABEL% : %LANG_NAME%
echo.
echo   %MENU_1%
echo   %MENU_2%
echo   %MENU_3%
echo   %MENU_4%
echo   %MENU_5%
echo   %MENU_6%
echo   %MENU_7%
echo   %MENU_8%
echo   %MENU_9%
echo.
echo ============================================================
set /p "CHOICE=%MENU_CHOICE% "

if "%CHOICE%"=="1" goto CREATE_SINGLE
if "%CHOICE%"=="2" goto CREATE_BATCH
if "%CHOICE%"=="3" goto EXTRACT_SINGLE
if "%CHOICE%"=="4" goto EXTRACT_BATCH
if "%CHOICE%"=="5" goto VERIFY_CHD
if "%CHOICE%"=="6" goto INFO_CHD
if "%CHOICE%"=="7" goto CREATE_HD
if "%CHOICE%"=="8" goto CHANGE_LANG
if "%CHOICE%"=="9" goto END
echo %MENU_INVALID%
pause
goto MENU

REM ============================================================
REM 8) CHANGER DE LANGUE
REM ============================================================
:CHANGE_LANG
call :LANGUAGE_MENU
goto MENU

REM ============================================================
REM 1) CREATION - UN SEUL FICHIER
REM ============================================================
:CREATE_SINGLE
cls
echo ============================================================
echo   %CREATE_SINGLE_TITLE%
echo ============================================================
echo.
echo %PROMPT_DROP_FILE_CUE%
echo %PROMPT_THEN_ENTER%
echo.
set "SRC="
set /p "SRC=%PROMPT_SOURCE_FILE% "
set SRC=%SRC:"=%

if not exist "%SRC%" (
    echo.
    echo %ERR_FILE_NOT_FOUND% %SRC%
    pause
    goto MENU
)

for %%F in ("%SRC%") do (
    set "SRC_DIR=%%~dpF"
    set "SRC_NAME=%%~nF"
    set "SRC_EXT=%%~xF"
)

echo.
echo %DISK_TYPE_PROMPT%
echo   %DISK_TYPE_CD%
echo   %DISK_TYPE_DVD%
set /p "DTYPE=%DISK_TYPE_CHOICE% "

set "OUT=!SRC_DIR!!SRC_NAME!.chd"

if "%DTYPE%"=="2" (
    set "SUBCMD=createdvd"
) else (
    set "SUBCMD=createcd"
)

call :CONFIRM_OVERWRITE "!OUT!"
if "%CONFIRM_RESULT%"=="0" goto MENU

echo.
echo ------------------------------------------------------------
echo  %COMMAND_LABEL% "%CHDMAN%" !SUBCMD! --force --input "%SRC%" --output "!OUT!"
echo ------------------------------------------------------------
echo.

"%CHDMAN%" !SUBCMD! --force --input "%SRC%" --output "!OUT!"

echo.
if exist "!OUT!" (
    echo %CREATE_OK% !OUT!
    call :LOG_COMMAND "!SUBCMD!" "%SRC%" "!OUT!" "OK"
) else (
    echo %CREATE_FAILED%
    call :LOG_COMMAND "!SUBCMD!" "%SRC%" "!OUT!" "FAILED"
)
echo.
pause
goto MENU

REM ============================================================
REM 2) CREATION - EN LOT (dossier + sous-dossiers)
REM ============================================================
:CREATE_BATCH
cls
echo ============================================================
echo   %CREATE_BATCH_TITLE%
echo ============================================================
echo.
echo %PROMPT_DROP_FOLDER%
echo %PROMPT_THEN_ENTER%
echo.
set "SRC_ROOT="
set /p "SRC_ROOT=%PROMPT_SOURCE_FOLDER% "
set SRC_ROOT=%SRC_ROOT:"=%

if not exist "%SRC_ROOT%\" (
    echo.
    echo %ERR_FOLDER_NOT_FOUND% %SRC_ROOT%
    pause
    goto MENU
)

echo.
echo %BATCH_TYPE_PROMPT%
echo   %BATCH_TYPE_CD%
echo   %BATCH_TYPE_DVD%
echo   %BATCH_TYPE_BOTH%
set /p "BTYPE=%BATCH_TYPE_CHOICE% "

REM Compte, sans rien executer, le nombre de fichiers ".chd" de
REM sortie qui existent deja et seraient ecrases par ce lot, pour
REM demander une confirmation groupee unique plutot qu'une
REM confirmation par fichier (impraticable sur un lot).
set "EXIST_COUNT=0"
pushd "%SRC_ROOT%"
if "%BTYPE%"=="1" call :COUNT_EXISTING_CD
if "%BTYPE%"=="2" call :COUNT_EXISTING_DVD
if "%BTYPE%"=="3" (call :COUNT_EXISTING_CD & call :COUNT_EXISTING_DVD)
popd

if not "%EXIST_COUNT%"=="0" (
    echo.
    echo !EXIST_COUNT! %BATCH_OVERWRITE_PROMPT%
    set "BOWANSWER="
    set /p "BOWANSWER=%BATCH_OVERWRITE_CONFIRM% "
    set "BOWPROCEED=0"
    if /i "!BOWANSWER!"=="y" set "BOWPROCEED=1"
    if /i "!BOWANSWER!"=="o" set "BOWPROCEED=1"
    if /i "!BOWANSWER!"=="s" set "BOWPROCEED=1"
    if /i "!BOWANSWER!"=="j" set "BOWPROCEED=1"
    if "!BOWPROCEED!"=="0" (
        echo.
        echo %OVERWRITE_CANCELLED%
        pause
        goto MENU
    )
)

set "COUNT=0"
set "FAIL=0"

pushd "%SRC_ROOT%"

if "%BTYPE%"=="1" goto :BATCH_CD_ONLY
if "%BTYPE%"=="2" goto :BATCH_DVD_ONLY
if "%BTYPE%"=="3" goto :BATCH_BOTH
goto :BATCH_END

:BATCH_CD_ONLY
for /R %%i in (*.cue *.gdi) do call :DO_CREATE_CD "%%i"
goto :BATCH_END

:BATCH_DVD_ONLY
for /R %%i in (*.iso) do call :DO_CREATE_DVD "%%i"
goto :BATCH_END

:BATCH_BOTH
for /R %%i in (*.cue *.gdi) do call :DO_CREATE_CD "%%i"
for /R %%i in (*.iso) do call :DO_CREATE_DVD "%%i"
goto :BATCH_END

:BATCH_END
popd

echo.
echo ============================================================
echo  %BATCH_DONE% !COUNT!   %BATCH_FAILURES% !FAIL!
echo ============================================================
pause
goto MENU

:COUNT_EXISTING_CD
for /R %%i in (*.cue *.gdi) do call :DO_COUNT_EXISTING "%%i"
exit /b

:COUNT_EXISTING_DVD
for /R %%i in (*.iso) do call :DO_COUNT_EXISTING "%%i"
exit /b

:DO_COUNT_EXISTING
if exist "%~dp1%~n1.chd" set /a EXIST_COUNT+=1
exit /b

:DO_CREATE_CD
set "F=%~1"
set "FDIR=%~dp1"
set "FNAME=%~n1"
pushd "%FDIR%"
echo.
echo %BATCH_CD_LABEL% %F%
"%CHDMAN%" createcd --force --input "%F%" --output "%FDIR%%FNAME%.chd"
if exist "%FDIR%%FNAME%.chd" (
    set /a COUNT+=1
    call :LOG_COMMAND "createcd" "%F%" "%FDIR%%FNAME%.chd" "OK"
) else (
    set /a FAIL+=1
    call :LOG_COMMAND "createcd" "%F%" "%FDIR%%FNAME%.chd" "FAILED"
)
popd
exit /b

:DO_CREATE_DVD
set "F=%~1"
set "FDIR=%~dp1"
set "FNAME=%~n1"
pushd "%FDIR%"
echo.
echo %BATCH_DVD_LABEL% %F%
"%CHDMAN%" createdvd --force --input "%F%" --output "%FDIR%%FNAME%.chd"
if exist "%FDIR%%FNAME%.chd" (
    set /a COUNT+=1
    call :LOG_COMMAND "createdvd" "%F%" "%FDIR%%FNAME%.chd" "OK"
) else (
    set /a FAIL+=1
    call :LOG_COMMAND "createdvd" "%F%" "%FDIR%%FNAME%.chd" "FAILED"
)
popd
exit /b

REM ============================================================
REM 3) EXTRACTION - UN SEUL FICHIER
REM ============================================================
:EXTRACT_SINGLE
cls
echo ============================================================
echo   %EXTRACT_SINGLE_TITLE%
echo ============================================================
echo.
echo %PROMPT_DROP_FILE_CHD%
echo %PROMPT_THEN_ENTER%
echo.
set "SRC="
set /p "SRC=%PROMPT_CHD_FILE% "
set SRC=%SRC:"=%

if not exist "%SRC%" (
    echo.
    echo %ERR_FILE_NOT_FOUND% %SRC%
    pause
    goto MENU
)

for %%F in ("%SRC%") do (
    set "SRC_DIR=%%~dpF"
    set "SRC_NAME=%%~nF"
)

echo.
echo %OUTPUT_FORMAT_PROMPT%
echo   %OUTPUT_FORMAT_CUEBIN%
echo   %OUTPUT_FORMAT_GDI%
echo   %OUTPUT_FORMAT_ISO%
set /p "ETYPE=%OUTPUT_FORMAT_CHOICE% "

if "%ETYPE%"=="1" (
    set "SUBCMD=extractcd"
    set "OUT=!SRC_DIR!!SRC_NAME!.cue"
)
if "%ETYPE%"=="2" (
    set "SUBCMD=extractcd"
    set "OUT=!SRC_DIR!!SRC_NAME!.gdi"
)
if "%ETYPE%"=="3" (
    set "SUBCMD=extractdvd"
    set "OUT=!SRC_DIR!!SRC_NAME!.iso"
)

call :CONFIRM_OVERWRITE "!OUT!"
if "%CONFIRM_RESULT%"=="0" goto MENU

echo.
echo ------------------------------------------------------------
echo  %COMMAND_LABEL% "%CHDMAN%" !SUBCMD! --force --input "%SRC%" --output "!OUT!"
echo ------------------------------------------------------------
echo.

"%CHDMAN%" !SUBCMD! --force --input "%SRC%" --output "!OUT!"

echo.
if exist "!OUT!" (
    echo %EXTRACT_OK% !OUT!
    call :LOG_COMMAND "!SUBCMD!" "%SRC%" "!OUT!" "OK"
) else (
    echo %EXTRACT_FAILED%
    call :LOG_COMMAND "!SUBCMD!" "%SRC%" "!OUT!" "FAILED"
)
echo.
pause
goto MENU

REM ============================================================
REM 4) EXTRACTION - EN LOT
REM ============================================================
:EXTRACT_BATCH
cls
echo ============================================================
echo   %EXTRACT_BATCH_TITLE%
echo ============================================================
echo.
echo %PROMPT_DROP_FOLDER%
echo %PROMPT_THEN_ENTER%
echo.
set "SRC_ROOT="
set /p "SRC_ROOT=%PROMPT_SOURCE_FOLDER% "
set SRC_ROOT=%SRC_ROOT:"=%

if not exist "%SRC_ROOT%\" (
    echo.
    echo %ERR_FOLDER_NOT_FOUND% %SRC_ROOT%
    pause
    goto MENU
)

echo.
echo %BATCH_OUTPUT_FORMAT_PROMPT%
echo   %OUTPUT_FORMAT_CUEBIN%
echo   %OUTPUT_FORMAT_GDI%
echo   %OUTPUT_FORMAT_ISO%
set /p "ETYPE=%OUTPUT_FORMAT_CHOICE% "

REM Compte, sans rien executer, le nombre de fichiers de sortie qui
REM existent deja et seraient ecrases (meme logique que dans
REM CREATE_BATCH ci-dessus). OUTEXT est reinitialise avant chaque
REM test pour ne jamais reutiliser une valeur laissee par un appel
REM precedent de ce menu (choix invalide -> repli sur "cue", comme
REM le fait DO_EXTRACT pour le sous-titre "extractcd").
set "OUTEXT=cue"
if "%ETYPE%"=="2" set "OUTEXT=gdi"
if "%ETYPE%"=="3" set "OUTEXT=iso"

set "EXIST_COUNT=0"
pushd "%SRC_ROOT%"
for /R %%i in (*.chd) do call :DO_COUNT_EXISTING_EXTRACT "%%i" "%OUTEXT%"
popd

if not "%EXIST_COUNT%"=="0" (
    echo.
    echo !EXIST_COUNT! %BATCH_OVERWRITE_PROMPT%
    set "BOWANSWER="
    set /p "BOWANSWER=%BATCH_OVERWRITE_CONFIRM% "
    set "BOWPROCEED=0"
    if /i "!BOWANSWER!"=="y" set "BOWPROCEED=1"
    if /i "!BOWANSWER!"=="o" set "BOWPROCEED=1"
    if /i "!BOWANSWER!"=="s" set "BOWPROCEED=1"
    if /i "!BOWANSWER!"=="j" set "BOWPROCEED=1"
    if "!BOWPROCEED!"=="0" (
        echo.
        echo %OVERWRITE_CANCELLED%
        pause
        goto MENU
    )
)

set "COUNT=0"
set "FAIL=0"

pushd "%SRC_ROOT%"
for /R %%i in (*.chd) do call :DO_EXTRACT "%%i" "%ETYPE%"
popd

echo.
echo ============================================================
echo  %BATCH_DONE_EXTRACT% !COUNT!   %BATCH_FAILURES% !FAIL!
echo ============================================================
pause
goto MENU

:DO_COUNT_EXISTING_EXTRACT
if exist "%~dp1%~n1.%~2" set /a EXIST_COUNT+=1
exit /b

:DO_EXTRACT
set "F=%~1"
set "ETYPE2=%~2"
set "FDIR=%~dp1"
set "FNAME=%~n1"
pushd "%FDIR%"

if "%ETYPE2%"=="1" (
    set "SUBCMD=extractcd"
    set "OUT=%FDIR%%FNAME%.cue"
)
if "%ETYPE2%"=="2" (
    set "SUBCMD=extractcd"
    set "OUT=%FDIR%%FNAME%.gdi"
)
if "%ETYPE2%"=="3" (
    set "SUBCMD=extractdvd"
    set "OUT=%FDIR%%FNAME%.iso"
)

echo.
echo %BATCH_EXTRACT_LABEL% %F%
"%CHDMAN%" !SUBCMD! --force --input "%F%" --output "!OUT!"
if exist "!OUT!" (
    set /a COUNT+=1
    call :LOG_COMMAND "!SUBCMD!" "%F%" "!OUT!" "OK"
) else (
    set /a FAIL+=1
    call :LOG_COMMAND "!SUBCMD!" "%F%" "!OUT!" "FAILED"
)
popd
exit /b

REM ============================================================
REM 5) VERIFICATION
REM ============================================================
:VERIFY_CHD
cls
echo ============================================================
echo   %VERIFY_TITLE%
echo ============================================================
echo.
echo %PROMPT_DROP_FILE_CHD%
echo %PROMPT_THEN_ENTER%
echo.
set "SRC="
set /p "SRC=%PROMPT_CHD_FILE% "
set SRC=%SRC:"=%

if not exist "%SRC%" (
    echo.
    echo %ERR_FILE_NOT_FOUND% %SRC%
    pause
    goto MENU
)

echo.
"%CHDMAN%" verify --input "%SRC%"
if %ERRORLEVEL%==0 (
    call :LOG_COMMAND "verify" "%SRC%" "" "OK"
) else (
    call :LOG_COMMAND "verify" "%SRC%" "" "FAILED"
)
echo.
pause
goto MENU

REM ============================================================
REM 6) INFOS
REM ============================================================
:INFO_CHD
cls
echo ============================================================
echo   %INFO_TITLE%
echo ============================================================
echo.
echo %PROMPT_DROP_FILE_CHD%
echo %PROMPT_THEN_ENTER%
echo.
set "SRC="
set /p "SRC=%PROMPT_CHD_FILE% "
set SRC=%SRC:"=%

if not exist "%SRC%" (
    echo.
    echo %ERR_FILE_NOT_FOUND% %SRC%
    pause
    goto MENU
)

echo.
"%CHDMAN%" info --input "%SRC%" --verbose
if %ERRORLEVEL%==0 (
    call :LOG_COMMAND "info" "%SRC%" "" "OK"
) else (
    call :LOG_COMMAND "info" "%SRC%" "" "FAILED"
)
echo.
pause
goto MENU

REM ============================================================
REM 7) DISQUE DUR (createhd / createraw)
REM ============================================================
:CREATE_HD
cls
echo ============================================================
echo   %CREATE_HD_TITLE%
echo ============================================================
echo.
echo %PROMPT_DROP_FILE_HD%
echo %PROMPT_THEN_ENTER%
echo.
set "SRC="
set /p "SRC=%PROMPT_SOURCE_FILE% "
set SRC=%SRC:"=%

if not exist "%SRC%" (
    echo.
    echo %ERR_FILE_NOT_FOUND% %SRC%
    pause
    goto MENU
)

for %%F in ("%SRC%") do (
    set "SRC_DIR=%%~dpF"
    set "SRC_NAME=%%~nF"
)

set "OUT=!SRC_DIR!!SRC_NAME!.chd"

call :CONFIRM_OVERWRITE "!OUT!"
if "%CONFIRM_RESULT%"=="0" goto MENU

echo.
echo ------------------------------------------------------------
echo  %COMMAND_LABEL% "%CHDMAN%" createhd --force --input "%SRC%" --output "!OUT!"
echo ------------------------------------------------------------
echo.

"%CHDMAN%" createhd --force --input "%SRC%" --output "!OUT!"

echo.
if exist "!OUT!" (
    echo %CREATE_OK% !OUT!
    call :LOG_COMMAND "createhd" "%SRC%" "!OUT!" "OK"
) else (
    echo %CREATE_FAILED%
    call :LOG_COMMAND "createhd" "%SRC%" "!OUT!" "FAILED"
)
echo.
pause
goto MENU

REM ============================================================
:END
echo.
echo %GOODBYE%
timeout /t 2 >nul
endlocal
exit /b 0
