@echo off
:: Run Neovim


:: Retrieve the saved directory from the temp file
for /f "tokens=*" %%i in ('type "%TEMP%\nvim_cwd.txt"') do set newDir=%%i

:: Change the directory to the saved one
if defined newDir (
    cd /d "%newDir%"
    echo Changed directory to: %newDir%
) else (
    echo Failed to retrieve directory from the temp file.
)
