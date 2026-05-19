g = vim.g
keymap = vim.keymap

g.mapleader = " "
g.maplocalleader = " "

-- Exlorer Jump Instructions
---- Explorer Opening Shortcut
keymap.set('n', '<leader>ee', ':30vs.<CR>', { noremap = true, silent = true })


-- Quit and Save Shortcuts
---- Quit Regardless
keymap.set('n', '<leader>q' , ':q<CR>' , { noremap = true, silent = true})


keymap.set('n', '<leader>Q' , ':q!<CR>' , { noremap = true, silent = true})

---- Write With no Quit
keymap.set('n', '<leader>w' , ':w<CR>' , { noremap = true, silent = true})




---- Buffer Close All, Except Current Shortcut
keymap.set('n', '<leader>o', '<C-w>o', { noremap = true, silent = true })



