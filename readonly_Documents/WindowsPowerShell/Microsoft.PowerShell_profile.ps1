# --- Keyboard Speed Heartbeat ---
# Windows often resets this on wake or updates. 
# This ensures it's always set to your preferred values.


function f {
    param([string]$Option = "")

    # 1. Check if the user typed 'f all'
    if ($Option -eq "all") {
        # Omni-search: Scan absolute root of both C: and D:
        $target = fd --type d . "C:\" "D:\" 2> $null | fzf
    } else {
        # Default fast search: Scan only your User folder on C: and the entire D: drive
        $target = fd --type d . $HOME "D:\" 2> $null | fzf
    }
    
    # 2. Execute the jump if a selection was made
    if ($target) {
        # File-safety check just in case a file extension tricks fd
        if (Test-Path -Path $target -PathType Leaf) {
            $target = Split-Path -Parent $target
        }
        
        cd $target
    }
}


Invoke-Expression (mise activate pwsh | Out-String)
