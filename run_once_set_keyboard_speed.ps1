# run_once_set_keyboard_speed.ps1

Write-Host "Setting fast keyboard repeat rate and short delay..."

# 0 is the shortest delay before repeating starts
Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardDelay" -Value "0"

# 31 is the maximum repeat speed
Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardSpeed" -Value "31"

Write-Host "Keyboard speed optimized. (Requires a Windows logout/restart to fully apply)."
