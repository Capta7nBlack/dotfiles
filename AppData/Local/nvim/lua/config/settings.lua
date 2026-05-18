-- opt as a variable for simplicity and readibility
local opt = vim.opt

-- sets the line counter
opt.number = true 

-- sets the current directory to neovim, instead of terminal 
opt.autochdir = true

-- swapfile error disregardment 
opt.swapfile = false

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

