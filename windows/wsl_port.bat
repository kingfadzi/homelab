@echo off
setlocal enabledelayedexpansion

REM Check for the correct number of parameters
if "%~3"=="" (
    echo Usage: %~nx0 ^<DistroName^> ^<ExportPath.tar^> ^<ImportPath^> [username]
    echo.
    echo Example: %~nx0 Ubuntu-22.04 C:\Backups\wsl_clean.tar C:\WSL\Ubuntu-22.04 fadzi
    echo.
    echo If username is not provided, will attempt to auto-detect current default user.
    exit /b 1
)

set DISTRO=%1
set EXPORT_PATH=%2
set IMPORT_PATH=%3
set DEFAULT_USER=%4

REM Auto-detect default user if not provided
if "%DEFAULT_USER%"=="" (
    echo Detecting default user for %DISTRO%...
    for /f "tokens=*" %%i in ('wsl.exe -d %DISTRO% whoami 2^>nul') do set DEFAULT_USER=%%i
    if "!DEFAULT_USER!"=="" (
        echo Warning: Could not detect default user. Will default to root after import.
        echo You can manually set it later with: wsl --set-default-user %DISTRO% ^<username^>
        set DEFAULT_USER=root
    ) else (
        echo Detected user: !DEFAULT_USER!
    )
)

REM Check if distro exists
wsl.exe -l -q | findstr /i "%DISTRO%" >nul 2>&1
if errorlevel 1 (
    echo Error: Distribution '%DISTRO%' not found.
    echo Available distributions:
    wsl.exe -l -q
    pause
    exit /b 1
)

REM Check if export path directory exists
for %%i in ("%EXPORT_PATH%") do set EXPORT_DIR=%%~dpi
if not exist "%EXPORT_DIR%" (
    echo Error: Export directory '%EXPORT_DIR%' does not exist.
    pause
    exit /b 1
)

REM Check if import path already exists
if exist "%IMPORT_PATH%" (
    echo Warning: Import path '%IMPORT_PATH%' already exists.
    set /p OVERWRITE="Do you want to overwrite it? (yes/no): "
    if /i not "!OVERWRITE!"=="yes" (
        echo Operation cancelled.
        pause
        exit /b 0
    )
)

REM Get original size
echo.
echo Getting current distro size...
for /f "tokens=3" %%a in ('wsl.exe -d %DISTRO% du -sh / 2^>nul ^| findstr "/"') do set ORIGINAL_SIZE=%%a

echo.
echo ========================================
echo WSL Distro Port Operation
echo ========================================
echo Distro:       %DISTRO%
echo Export to:    %EXPORT_PATH%
echo Import to:    %IMPORT_PATH%
echo Default user: %DEFAULT_USER%
echo Current size: %ORIGINAL_SIZE%
echo ========================================
echo.
echo WARNING: This will UNREGISTER the current distro after export.
echo Make sure you have run cleanup script first for maximum space savings.
echo.
set /p CONFIRM="Type 'yes' to continue: "
if /i not "%CONFIRM%"=="yes" (
    echo Operation cancelled.
    pause
    exit /b 0
)

echo.
echo Exporting %DISTRO% to %EXPORT_PATH%...
wsl.exe --export %DISTRO% %EXPORT_PATH%
if errorlevel 1 (
    echo Error exporting %DISTRO%. Exiting.
    pause
    exit /b 1
)

REM Verify export file exists and has size > 0
if not exist "%EXPORT_PATH%" (
    echo Error: Export file was not created at %EXPORT_PATH%
    pause
    exit /b 1
)

for %%A in ("%EXPORT_PATH%") do set EXPORT_SIZE=%%~zA
if "%EXPORT_SIZE%"=="0" (
    echo Error: Export file is empty (0 bytes^). Export may have failed.
    pause
    exit /b 1
)

echo Export successful. File size: %EXPORT_SIZE% bytes
echo Verifying tar file integrity...
tar -tzf "%EXPORT_PATH%" >nul 2>&1
if errorlevel 1 (
    echo Warning: Tar file may be corrupted. Verification failed.
    set /p CONTINUE="Continue anyway? (yes/no): "
    if /i not "!CONTINUE!"=="yes" (
        echo Operation cancelled. Export file preserved at: %EXPORT_PATH%
        pause
        exit /b 1
    )
) else (
    echo Tar file integrity verified.
)

echo.
echo Unregistering %DISTRO%...
wsl.exe --unregister %DISTRO%
if errorlevel 1 (
    echo Error unregistering %DISTRO%.
    echo Your data is safe in: %EXPORT_PATH%
    pause
    exit /b 1
)
echo Unregister successful.

echo.
echo Importing %DISTRO% from %EXPORT_PATH% to %IMPORT_PATH%...
wsl.exe --import %DISTRO% %IMPORT_PATH% %EXPORT_PATH%
if errorlevel 1 (
    echo Error importing %DISTRO%.
    echo CRITICAL: Your distro was unregistered but import failed!
    echo You can manually re-import using:
    echo   wsl --import %DISTRO% %IMPORT_PATH% %EXPORT_PATH%
    pause
    exit /b 1
)
echo Import successful.

REM Set default user (skip if root)
if /i not "%DEFAULT_USER%"=="root" (
    echo.
    echo Setting default user to %DEFAULT_USER%...
    wsl.exe -d %DISTRO% -u root /bin/bash -c "id -u %DEFAULT_USER%" >nul 2>&1
    if errorlevel 1 (
        echo Warning: User '%DEFAULT_USER%' does not exist in the imported distro.
        echo Skipping default user configuration. You will login as root.
    ) else (
        REM Create or update /etc/wsl.conf
        wsl.exe -d %DISTRO% -u root /bin/bash -c "echo '[user]' > /etc/wsl.conf && echo 'default=%DEFAULT_USER%' >> /etc/wsl.conf"
        echo Default user set to %DEFAULT_USER%
        echo Restarting distro to apply changes...
        wsl.exe --terminate %DISTRO%
        timeout /t 2 >nul
    )
)

REM Get new size
echo.
echo Getting new distro size...
for /f "tokens=3" %%a in ('wsl.exe -d %DISTRO% du -sh / 2^>nul ^| findstr "/"') do set NEW_SIZE=%%a

echo.
echo ========================================
echo Operation Complete!
echo ========================================
echo Distro:        %DISTRO%
echo Location:      %IMPORT_PATH%
echo Default user:  %DEFAULT_USER%
echo Original size: %ORIGINAL_SIZE%
echo New size:      %NEW_SIZE%
echo Export file:   %EXPORT_PATH% (%EXPORT_SIZE% bytes)
echo ========================================
echo.

REM Ask about cleanup
set /p CLEANUP="Delete the export tar file to save space? (yes/no): "
if /i "%CLEANUP%"=="yes" (
    del "%EXPORT_PATH%"
    if exist "%EXPORT_PATH%" (
        echo Warning: Could not delete %EXPORT_PATH%
    ) else (
        echo Export file deleted successfully.
    )
) else (
    echo Export file preserved at: %EXPORT_PATH%
    echo You can delete it manually later to free up space.
)

echo.
echo Your WSL distro has been successfully ported!
pause