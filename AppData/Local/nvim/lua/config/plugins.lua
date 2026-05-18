-- lua/config/plugins.lua

-- 1. Define the default data path
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- 2. Clone the manager from Github if it isn't already installed
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", 
    lazypath,
  })
end

-- 3. Add lazy to the Neovim runtime path
vim.opt.rtp:prepend(lazypath)

-- 4. Initialize lazy
require("lazy").setup({
    -- We will put our plugins in here next!
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    dependencies = { 'nvim-lua/plenary.nvim' }
    
})
