-- Global OS variables for use anywhere in the config
_G.IS_WINDOWS = vim.fn.has("win32") == 1
_G.IS_MAC = vim.fn.has("macunix") == 1
_G.IS_LINUX = vim.fn.has("unix") == 1 and not _G.IS_MAC


-- opt as a variable for simplicity and readibility
--
local opt = vim.opt

-- sets the line counter
opt.number = true 

-- sets the current directory to neovim, instead of terminal 
opt.autochdir = true

-- swapfile error disregardment 
opt.swapfile = false

-- === TIMING & DELAYS ===
-- Time in milliseconds to wait for a mapped sequence to complete (e.g., Leader keys)
vim.opt.timeoutlen = 300 

-- Time in milliseconds to wait for a key code sequence (fixes the Alt-key lag)
vim.opt.ttimeoutlen = 0

-- Transparent background
vim.cmd("highlight Normal guibg=NONE ctermbg=NONE")
vim.cmd("highlight NonText guibg=NONE ctermbg=NONE")
opt.termguicolors = true

-- Search settings
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = false
opt.wrap = true
opt.breakindent = true

-- Virtual line mark
opt.showbreak = ">>>"



if _G.IS_WINDOWS then
    -- Force Windows to use pwsh (PowerShell Core) safely
    vim.opt.shell = "cmd.exe"
    vim.opt.shellcmdflag = "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;"
    vim.opt.shellredir = "-RedirectStandardOutput %s -NoNewWindow -Wait"
    vim.opt.shellpipe = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode"
    vim.opt.shellquote = ""
    vim.opt.shellxquote = ""
else
    -- On Unix, Neovim safely defaults to your system shell (bash/zsh).
    -- You usually don't need to set anything here, but you can force it if desired:
    -- vim.opt.shell = "zsh"
end
