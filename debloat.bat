REM DISCLAIMER: This tool is provided as-is, without warranties.
REM You accept all risks. The author(s) are not responsible for any damage,
REM data loss, boot issues, or consequences. Not affiliated with Xiaomi/POCO/Redmi.

@echo off
setlocal ENABLEDELAYEDEXPANSION

REM Universal HyperOS debloat for Windows (ADB required in PATH).
REM Usage:
REM   debloat.bat safe
REM   debloat.bat optional
REM   debloat.bat all
REM   debloat.bat revert
REM   debloat.bat dryrun

set PROFILE=%1
if "%PROFILE%"=="" set PROFILE=safe

set LIST_DIR=device-profiles
set LOGFILE=debloat-%DATE:~10,4%-%DATE:~4,2%-%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%.log
set LOGFILE=%LOGFILE: =0%

echo Logging to %LOGFILE%
echo Creating package backup...
adb shell "pm list packages -f" > packages-backup-%DATE:~10,4%-%DATE:~4,2%-%DATE:~7,2%.txt

if /I "%PROFILE%"=="safe" (
  set FILES=%LIST_DIR%\hyperos-safe.txt
) else if /I "%PROFILE%"=="optional" (
  set FILES=%LIST_DIR%\hyperos-optional.txt
) else if /I "%PROFILE%"=="all" (
  set FILES=%LIST_DIR%\hyperos-safe.txt %LIST_DIR%\hyperos-optional.txt
) else if /I "%PROFILE%"=="revert" (
  set REVERT=1
  set FILES=%LIST_DIR%\hyperos-safe.txt %LIST_DIR%\hyperos-optional.txt
) else if /I "%PROFILE%"=="dryrun" (
  set DRYRUN=1
  set FILES=%LIST_DIR%\hyperos-safe.txt
) else (
  echo Unknown profile: %PROFILE%
  exit /b 1
)

REM Process files
for %%F in (%FILES%) do (
  if not exist "%%F" (
    echo Profile file missing: %%F >> "%LOGFILE%"
  ) else (
    for /f "usebackq delims=" %%P in ("%%F") do (
      set PKG=%%P
      if "!PKG!"=="" goto :continue
      echo !PKG! | findstr /R "^\s*#">nul && goto :continue

      if defined DRYRUN (
        echo -> !PKG! ... would change >> "%LOGFILE%"
        echo -> !PKG! ... would change
        goto :continue
      )

      if defined REVERT (
        echo <- !PKG! ... >> "%LOGFILE%"
        adb shell pm enable --user 0 !PKG! >> "%LOGFILE%" 2>&1
        adb shell cmd package install-existing --user 0 !PKG! >> "%LOGFILE%" 2>&1
        goto :continue
      )

      echo -> !PKG! ... >> "%LOGFILE%"
      adb shell pm disable-user --user 0 !PKG! >> "%LOGFILE%" 2>&1
      if errorlevel 1 (
        adb shell pm uninstall -k --user 0 !PKG! >> "%LOGFILE%" 2>&1
      )
      :continue
    )
  )
)

echo Done. A reboot is recommended.
endlocal
