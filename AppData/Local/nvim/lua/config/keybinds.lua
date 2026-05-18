g = vim.g
keymap = vim.keymap

g.mapleader = " "
g.maplocalleader = " "

-- Exlorer Jump Instructions
---- Explorer Opening Shortcut
keymap.set('n', '<leader>ee', ':30vs.<CR>', { noremap = true, silent = true })

-------- Explorer to Config Folder
keymap.set('n', '<leader>ec', ':EditConfig<CR>', { noremap = true, silent = true })

-------- Explorer to disk D
keymap.set('n', '<leader>ed', ':Cdd<CR>', { noremap = true, silent = true })


-- Quit and Save Shortcuts
---- Quit Regardless
keymap.set('n', '<leader>qq' , ':q!<CR>' , { noremap = true, silent = true})

---- Write With no Quit
keymap.set('n', '<leader>ww' , ':w<CR>' , { noremap = true, silent = true})

-------- Write and Quite
keymap.set('n', '<leader>wq' , ':wq<CR>' , { noremap = true, silent = true})

-------- Quit All Regardless
keymap.set('n', '<leader>Q' , ':qa!<CR>' , { noremap = true, silent = true})


-- Buffer Management Shortcuts
keymap.set('n', '<leader>j', '<C-w>j', { noremap = true, silent = true })
keymap.set('n', '<leader>k', '<C-w>k', { noremap = true, silent = true })
keymap.set('n', '<leader>h', '<C-w>h', { noremap = true, silent = true })
keymap.set('n', '<leader>l', '<C-w>l', { noremap = true, silent = true })

---- Buffer Close All, Except Current Shortcut
keymap.set('n', '<leader>o', '<C-w>o', { noremap = true, silent = true })



local builtin = require('telescope.builtin')

-- <leader>ff : Find Files (Searches file names)
vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
-- <leader>fg : Live Grep (Searches for text/code INSIDE your files)
vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
-- <leader>fb : Buffers (Searches through the files you currently have open)
vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
