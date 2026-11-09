@echo off
chcp 1252 > nul
set PGCLIENTENCODING=WIN1252
cd /d "%~dp0"

set PSQL=
for %%v in (18 17 16) do (
    if not defined PSQL if exist "C:\Program Files\PostgreSQL\%%v\bin\psql.exe" set "PSQL=C:\Program Files\PostgreSQL\%%v\bin\psql.exe"
)
if not defined PSQL (
    echo psql not found in C:\Program Files\PostgreSQL
    pause
    exit /b 1
)
echo Using psql: %PSQL%
echo The postgres password will be asked several times.
echo.

echo === 1. Creating database rail_db if needed ===
"%PSQL%" -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname = 'rail_db'" | findstr 1 > nul
if errorlevel 1 (
    "%PSQL%" -U postgres -c "CREATE DATABASE rail_db"
) else (
    echo Database rail_db already exists.
)

echo.
echo === 2. Schema ===
"%PSQL%" -U postgres -d rail_db -v ON_ERROR_STOP=1 -q -f schema.sql
if errorlevel 1 (
    echo Error while running schema.sql
    pause
    exit /b 1
)

echo.
pause
