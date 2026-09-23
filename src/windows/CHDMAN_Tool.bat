@echo off
title CHDMAN Tool - Menu Complet
color 0A
setlocal EnableDelayedExpansion

REM ============================================================
REM  CHDMAN TOOL - Interface complete pour chdman.exe
REM  Compression / Extraction / Verification de fichiers CHD
REM  Formats supportes en entree : CUE, GDI, ISO (CD et DVD)
REM ============================================================

REM Verifie que chdman.exe est present a cote du script
if not exist "%~dp0chdman.exe" (
    color 0C
    echo.
    echo  [ERREUR] chdman.exe est introuvable dans ce dossier :
    echo  %~dp0
    echo.
    echo  Placez CHDMAN_Tool.bat dans le meme dossier que chdman.exe
    echo.
    pause
    exit /b 1
)

set "CHDMAN=%~dp0chdman.exe"

:MENU
cls
echo ============================================================
echo                     CHDMAN TOOL - MENU
echo ============================================================
echo.
echo   [1] Creer un CHD depuis UN fichier (CUE / GDI / ISO)
echo   [2] Creer des CHD en LOT (tout un dossier + sous-dossiers)
echo   [3] Extraire un CHD (CUE+BIN, GDI ou ISO)
echo   [4] Extraire des CHD en LOT (tout un dossier)
echo   [5] Verifier l'integrite d'un CHD
echo   [6] Afficher les infos d'un CHD
echo   [7] Compresser un disque dur (createhd / createraw)
echo   [8] Quitter
echo.
echo ============================================================
set /p "CHOICE=Votre choix (1-8) : "

if "%CHOICE%"=="1" goto CREATE_SINGLE
if "%CHOICE%"=="2" goto CREATE_BATCH
if "%CHOICE%"=="3" goto EXTRACT_SINGLE
if "%CHOICE%"=="4" goto EXTRACT_BATCH
if "%CHOICE%"=="5" goto VERIFY_CHD
if "%CHOICE%"=="6" goto INFO_CHD
if "%CHOICE%"=="7" goto CREATE_HD
if "%CHOICE%"=="8" goto END
echo Choix invalide.
pause
goto MENU

REM ============================================================
REM 1) CREATION - UN SEUL FICHIER
REM ============================================================
:CREATE_SINGLE
cls
echo ============================================================
echo   CREER UN CHD - Fichier unique
echo ============================================================
echo.
echo Glissez-deposez votre fichier .cue, .gdi ou .iso ici,
echo puis appuyez sur Entree (ou tapez le chemin complet) :
echo.
set "SRC="
set /p "SRC=Fichier source : "
set SRC=%SRC:"=%

if not exist "%SRC%" (
    echo.
    echo [ERREUR] Fichier introuvable : %SRC%
    pause
    goto MENU
)

for %%F in ("%SRC%") do (
    set "SRC_DIR=%%~dpF"
    set "SRC_NAME=%%~nF"
    set "SRC_EXT=%%~xF"
)

echo.
echo Type de disque :
echo   [1] CD (CUE/GDI - PSX, Saturn, SegaCD, Dreamcast...)
echo   [2] DVD (ISO - GameCube, PS2, Xbox...)
set /p "DTYPE=Choix (1-2) : "

set "OUT=!SRC_DIR!!SRC_NAME!.chd"

if "%DTYPE%"=="2" (
    set "SUBCMD=createdvd"
) else (
    set "SUBCMD=createcd"
)

echo.
echo ------------------------------------------------------------
echo  Commande : "%CHDMAN%" !SUBCMD! --force --input "%SRC%" --output "!OUT!"
echo ------------------------------------------------------------
echo.

"%CHDMAN%" !SUBCMD! --force --input "%SRC%" --output "!OUT!"

echo.
if exist "!OUT!" (
    echo [OK] CHD cree : !OUT!
) else (
    echo [ATTENTION] La conversion semble avoir echoue.
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
echo   CREER DES CHD EN LOT
echo ============================================================
echo.
echo Glissez-deposez le DOSSIER racine a scanner ici,
echo puis appuyez sur Entree (ou tapez le chemin complet) :
echo.
set "SRC_ROOT="
set /p "SRC_ROOT=Dossier source : "
set SRC_ROOT=%SRC_ROOT:"=%

if not exist "%SRC_ROOT%\" (
    echo.
    echo [ERREUR] Dossier introuvable : %SRC_ROOT%
    pause
    goto MENU
)

echo.
echo Type de disques a traiter :
echo   [1] CD uniquement  (*.cue, *.gdi)          -^> createcd
echo   [2] DVD uniquement (*.iso)                 -^> createdvd
echo   [3] Les deux (CUE/GDI en CD, ISO en DVD)
set /p "BTYPE=Choix (1-3) : "

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
echo  Termine. Fichiers convertis : !COUNT!   Echecs : !FAIL!
echo ============================================================
pause
goto MENU

:DO_CREATE_CD
set "F=%~1"
set "FDIR=%~dp1"
set "FNAME=%~n1"
pushd "%FDIR%"
echo.
echo -^> CD  : %F%
"%CHDMAN%" createcd --force --input "%F%" --output "%FDIR%%FNAME%.chd"
if exist "%FDIR%%FNAME%.chd" (set /a COUNT+=1) else (set /a FAIL+=1)
popd
exit /b

:DO_CREATE_DVD
set "F=%~1"
set "FDIR=%~dp1"
set "FNAME=%~n1"
pushd "%FDIR%"
echo.
echo -^> DVD : %F%
"%CHDMAN%" createdvd --force --input "%F%" --output "%FDIR%%FNAME%.chd"
if exist "%FDIR%%FNAME%.chd" (set /a COUNT+=1) else (set /a FAIL+=1)
popd
exit /b

REM ============================================================
REM 3) EXTRACTION - UN SEUL FICHIER
REM ============================================================
:EXTRACT_SINGLE
cls
echo ============================================================
echo   EXTRAIRE UN CHD - Fichier unique
echo ============================================================
echo.
echo Glissez-deposez votre fichier .chd ici,
echo puis appuyez sur Entree (ou tapez le chemin complet) :
echo.
set "SRC="
set /p "SRC=Fichier .chd : "
set SRC=%SRC:"=%

if not exist "%SRC%" (
    echo.
    echo [ERREUR] Fichier introuvable : %SRC%
    pause
    goto MENU
)

for %%F in ("%SRC%") do (
    set "SRC_DIR=%%~dpF"
    set "SRC_NAME=%%~nF"
)

echo.
echo Format de sortie :
echo   [1] CUE + BIN  (CD - PSX, Saturn, SegaCD...)
echo   [2] GDI        (Dreamcast)
echo   [3] ISO        (DVD)
set /p "ETYPE=Choix (1-3) : "

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

echo.
echo ------------------------------------------------------------
echo  Commande : "%CHDMAN%" !SUBCMD! --force --input "%SRC%" --output "!OUT!"
echo ------------------------------------------------------------
echo.

"%CHDMAN%" !SUBCMD! --force --input "%SRC%" --output "!OUT!"

echo.
if exist "!OUT!" (
    echo [OK] Extraction terminee : !OUT!
) else (
    echo [ATTENTION] L'extraction semble avoir echoue.
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
echo   EXTRAIRE DES CHD EN LOT
echo ============================================================
echo.
echo Glissez-deposez le DOSSIER racine a scanner ici,
echo puis appuyez sur Entree (ou tapez le chemin complet) :
echo.
set "SRC_ROOT="
set /p "SRC_ROOT=Dossier source : "
set SRC_ROOT=%SRC_ROOT:"=%

if not exist "%SRC_ROOT%\" (
    echo.
    echo [ERREUR] Dossier introuvable : %SRC_ROOT%
    pause
    goto MENU
)

echo.
echo Format de sortie pour TOUS les CHD trouves :
echo   [1] CUE + BIN
echo   [2] GDI
echo   [3] ISO (DVD)
set /p "ETYPE=Choix (1-3) : "

set "COUNT=0"
set "FAIL=0"

pushd "%SRC_ROOT%"
for /R %%i in (*.chd) do call :DO_EXTRACT "%%i" "%ETYPE%"
popd

echo.
echo ============================================================
echo  Termine. Fichiers extraits : !COUNT!   Echecs : !FAIL!
echo ============================================================
pause
goto MENU

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
echo -^> %F%
"%CHDMAN%" !SUBCMD! --force --input "%F%" --output "!OUT!"
if exist "!OUT!" (set /a COUNT+=1) else (set /a FAIL+=1)
popd
exit /b

REM ============================================================
REM 5) VERIFICATION
REM ============================================================
:VERIFY_CHD
cls
echo ============================================================
echo   VERIFIER UN CHD
echo ============================================================
echo.
echo Glissez-deposez votre fichier .chd ici,
echo puis appuyez sur Entree (ou tapez le chemin complet) :
echo.
set "SRC="
set /p "SRC=Fichier .chd : "
set SRC=%SRC:"=%

if not exist "%SRC%" (
    echo.
    echo [ERREUR] Fichier introuvable : %SRC%
    pause
    goto MENU
)

echo.
"%CHDMAN%" verify --input "%SRC%"
echo.
pause
goto MENU

REM ============================================================
REM 6) INFOS
REM ============================================================
:INFO_CHD
cls
echo ============================================================
echo   INFOS D'UN CHD
echo ============================================================
echo.
echo Glissez-deposez votre fichier .chd ici,
echo puis appuyez sur Entree (ou tapez le chemin complet) :
echo.
set "SRC="
set /p "SRC=Fichier .chd : "
set SRC=%SRC:"=%

if not exist "%SRC%" (
    echo.
    echo [ERREUR] Fichier introuvable : %SRC%
    pause
    goto MENU
)

echo.
"%CHDMAN%" info --input "%SRC%" --verbose
echo.
pause
goto MENU

REM ============================================================
REM 7) DISQUE DUR (createhd / createraw)
REM ============================================================
:CREATE_HD
cls
echo ============================================================
echo   COMPRESSER UNE IMAGE DE DISQUE DUR
echo ============================================================
echo.
echo Glissez-deposez votre image (.img, .raw, .hdd...) ici,
echo puis appuyez sur Entree (ou tapez le chemin complet) :
echo.
set "SRC="
set /p "SRC=Fichier source : "
set SRC=%SRC:"=%

if not exist "%SRC%" (
    echo.
    echo [ERREUR] Fichier introuvable : %SRC%
    pause
    goto MENU
)

for %%F in ("%SRC%") do (
    set "SRC_DIR=%%~dpF"
    set "SRC_NAME=%%~nF"
)

set "OUT=!SRC_DIR!!SRC_NAME!.chd"

echo.
echo ------------------------------------------------------------
echo  Commande : "%CHDMAN%" createhd --force --input "%SRC%" --output "!OUT!"
echo ------------------------------------------------------------
echo.

"%CHDMAN%" createhd --force --input "%SRC%" --output "!OUT!"

echo.
if exist "!OUT!" (
    echo [OK] CHD cree : !OUT!
) else (
    echo [ATTENTION] La conversion semble avoir echoue.
)
echo.
pause
goto MENU

REM ============================================================
:END
echo.
echo Au revoir !
timeout /t 2 >nul
endlocal
exit /b 0
