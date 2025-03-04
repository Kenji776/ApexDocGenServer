@echo off
echo Setting up ApexDocGenServer...

:: Ensure Node.js is installed
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo Node.js is not installed. Please install Node.js first.
    exit /b 1
)

:: Install dependencies from package.json
echo Installing dependencies...
call npm install

npm i -g @cparra/apexdocs

:: Start the documentation generator
echo Starting documentation generator...
start node server.js

:: Wait for the process to start (adjust timeout if needed)
timeout /t 3 /nobreak >nul

:: Open the generated documentation in the default web browser
echo Opening documentation...
start start "" http://localhost:3500

echo Setup complete.
pause
