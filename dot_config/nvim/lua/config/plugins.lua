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
    {
        -- TELESCOPE
        'nvim-telescope/telescope.nvim',
        tag = '0.1.8',
        dependencies = { 'nvim-lua/plenary.nvim' },
	keys = {
            -- 1. Find Files: Always search from the .git root (if it exists)
            { "<leader>ff", function()
                local builtin = require('telescope.builtin')
                -- Find the nearest .git folder upwards. If not in a git repo, fallback to current dir.
                local root = vim.fs.root(0, ".git") or vim.fn.getcwd()
                builtin.find_files({ cwd = root })
            end, desc = "Find Files (Project Root)" },

            -- 2. Live Grep: Always search from the .git root
            { "<leader>fg", function()
                local builtin = require('telescope.builtin')
                local root = vim.fs.root(0, ".git") or vim.fn.getcwd()
                builtin.live_grep({ cwd = root })
            end, desc = "Live Grep (Project Root)" },

            -- 3. Find Buffers: Already global to Neovim, so no root logic needed
            { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Find Buffers" },
            
            -- 4. Help Tags: Searches Neovim documentation
            { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help Tags" },
        }
	},
    {
        -- OIL
        'stevearc/oil.nvim',
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("oil").setup({
                -- 1. Hijack the default explorer
                default_file_explorer = true,

                -- 2. What data to show next to the file names
                columns = {
                    "icon",
                    -- "permissions",
                    -- "size",
                    -- "mtime",
                },

                -- 3. Buffer-local keymaps specifically while inside an Oil buffer
                keymaps = {
                    ["g?"] = "actions.show_help",
		    ["x"] = "actions.select",
                    ["<CR>"] = "actions.select",
                    ["<C-s>"] = "actions.select_vsplit",
                    ["<C-h>"] = "actions.select_split",
                    ["<C-p>"] = "actions.preview",
                    ["<C-c>"] = "actions.close",
                    ["-"] = "actions.parent",
                    ["_"] = "actions.open_cwd",
                    ["`"] = "actions.cd",
                    ["~"] = "actions.tcd",
                    ["gs"] = "actions.change_sort",
                    ["gx"] = "actions.open_external",
                    ["g."] = "actions.toggle_hidden",
                    ["g\\"] = "actions.toggle_trash",
                },

                -- 4. Set to true to watch the filesystem for external changes
                watch_for_changes = false,

                -- 5. Safe deletion
                delete_to_trash = true,
                
                -- 6. Float window options (if you prefer it to pop over your code instead of replacing it)
                float = {
                    padding = 2,
                    max_width = 80,
                    max_height = 20,
                    border = "rounded",
                    win_options = {
                        winblend = 0,
                    },
                },
            })
            
            -- Global keybind to open Oil in the current file's directory
            vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
        end,
    },
    {   -- SMART SPLITS
        'mrjones2014/smart-splits.nvim',
	lazy = false,
        keys = {
            -- Alt + hjkl for Navigation
            { "<M-h>", function() require("smart-splits").move_cursor_left() end, desc = "Move Left" },
            { "<M-j>", function() require("smart-splits").move_cursor_down() end, desc = "Move Down" },
            { "<M-k>", function() require("smart-splits").move_cursor_up() end, desc = "Move Up" },
            { "<M-l>", function() require("smart-splits").move_cursor_right() end, desc = "Move Right" },
        },
        config = function()
            require('smart-splits').setup({
                ignored_filetypes = { 'nofile', 'quickfix', 'qf', 'prompt' },
                ignored_buftypes = { 'nofile' },
		multiplexer_integration = 'wezterm',
            })
        end
    },
})
