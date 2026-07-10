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

		view_options = {
		    show_hidden = true,
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
        keys = {
            -- Alt + hjkl for Navigation
            { "<M-h>", function() require("smart-splits").move_cursor_left() end, desc = "Move Left" },
            { "<M-j>", function() require("smart-splits").move_cursor_down() end, desc = "Move Down" },
            { "<M-k>", function() require("smart-splits").move_cursor_up() end, desc = "Move Up" },
            { "<M-l>", function() require("smart-splits").move_cursor_right() end, desc = "Move Right" },
        },
        config = function()
            -- Counter makes every payload unique; WezTerm's user-var-changed
            -- event is not guaranteed to fire when the value is unchanged
            -- (e.g. hitting Alt+h at the left edge twice in a row).
            local edge_nav_counter = 0

            require('smart-splits').setup({
                ignored_filetypes = { 'nofile', 'quickfix', 'qf', 'prompt' },
                ignored_buftypes = { 'nofile' },

                -- NOT 'wezterm': the CLI integration spawns wezterm.exe per
                -- keypress (blocking, 20-1000ms on Windows). Pane handoff is
                -- done via the NVIM_EDGE_NAV user var below instead; the
                -- matching listener lives in wezterm.lua (user-var-changed).
                multiplexer_integration = false,

                -- Called when moving past the outermost Neovim split: hand
                -- the navigation over to WezTerm via an escape sequence
                -- (instant, no process spawn).
                at_edge = function(ctx)
                    edge_nav_counter = edge_nav_counter + 1
                    local payload = ctx.direction .. ':' .. edge_nav_counter
                    local esc = string.format(
                        '\027]1337;SetUserVar=%s=%s\007',
                        'NVIM_EDGE_NAV',
                        vim.base64.encode(payload)
                    )
                    vim.fn.chansend(vim.v.stderr, esc)
                end,
            })
        end
    },

-- ==========================================
    -- SYNTAX HIGHLIGHTING (Tree-sitter)
    -- ==========================================
    {
        "nvim-treesitter/nvim-treesitter",
	branch = 'master',
        build = ":TSUpdate",
        -- Highlighting only matters once a real file is in a buffer; skips
        -- loading it for bare `nvim` / Oil-only sessions.
        event = { 'BufReadPost', 'BufNewFile' },
        config = function()

	    require('nvim-treesitter.install').compilers = { "zig" }

            require("nvim-treesitter.configs").setup({
                -- The parsers you want installed automatically
                ensure_installed = { "python", "javascript", "typescript", "json", "lua", "vim", "markdown" },
                highlight = { 
                    enable = true,
                    -- Disable traditional regex highlighting for better performance
                    additional_vim_regex_highlighting = false,
                },
                indent = { enable = true },
            })
        end
    },

    -- ==========================================
    -- LANGUAGE SERVERS (LSP)
    -- ==========================================
    {
        "neovim/nvim-lspconfig",
        -- LSP (and Mason's registry checks) only make sense with a file open;
        -- BufReadPre fires before the first real buffer loads, so servers
        -- still attach to it as usual.
        event = { 'BufReadPre', 'BufNewFile' },
        dependencies = {
            -- Mason manages the external server binaries so you don't have to use npm/pip
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
        },
        config = function()
            -- 1. Initialize Mason
            require("mason").setup()

            -- 2. Tell Mason to ensure our Python and Node servers are installed
            require("mason-lspconfig").setup({
                ensure_installed = { 
                    "pyright", -- The standard Microsoft Python LSP
                    "ts_ls",   -- The standard Node/TypeScript/JavaScript LSP
                },
            })

	    local capabilities = require('blink.cmp').get_lsp_capabilities()

            -- 3. Wire the installed servers up to Neovim
            vim.lsp.config('pyright', { capabilities = capabilities })
            vim.lsp.enable('pyright')

            vim.lsp.config('ts_ls', { capabilities = capabilities })
            vim.lsp.enable('ts_ls')

	    vim.diagnostic.config({
                virtual_text = {
                    prefix = '■ ', 
                    spacing = 4,
                },
                signs = true,      
                underline = true,  
                update_in_insert = false, 
                severity_sort = true,
            })
            
            local signs = { Error = "✘", Warn = "▲", Hint = "⚑", Info = "»" }
            for type, icon in pairs(signs) do
                local hl = "DiagnosticSign" .. type
                vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
            end




            -- 4. Set up the universal LSP keybinds (Only active when an LSP is attached to a file)
            vim.api.nvim_create_autocmd('LspAttach', {
                callback = function(event)
                    local opts = { buffer = event.buf }
                    
                    vim.keymap.set('n', 'K', vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover Documentation" }))
                    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Go to Definition" }))
                    vim.keymap.set('n', 'gr', require('telescope.builtin').lsp_references, vim.tbl_extend("force", opts, { desc = "Find References" }))
                    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Rename Variable" }))
                    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "Code Actions" }))
                    
                    -- Diagnostics (Error viewing)
                    vim.keymap.set('n', 'gl', vim.diagnostic.open_float, vim.tbl_extend("force", opts, { desc = "Show Line Diagnostics" }))
                    vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, vim.tbl_extend("force", opts, { desc = "Previous Error" }))
                    vim.keymap.set('n', ']d', vim.diagnostic.goto_next, vim.tbl_extend("force", opts, { desc = "Next Error" }))
                end,
            })
        end
    },

{ --     BLINK AUTOCOMPLETION
        'saghen/blink.cmp',
        version = '*', -- Use release tags to avoid breaking changes
        -- Completion is only needed once you start typing; keeps it off the
        -- startup path (~25ms measured).
        event = 'InsertEnter',
        opts = {
            -- 'default' maps <C-space> to open, <C-n>/<C-p> to navigate, and <CR> to select
            keymap = { preset = 'default' }, 
            
            appearance = {
                use_nvim_cmp_as_default = true,
                nerd_font_variant = 'mono'
            },
            
            -- Where to pull the typing suggestions from
            sources = {
                default = { 'lsp', 'path', 'snippets', 'buffer' },
            },
            
            -- Shows a documentation popup for function parameters as you type them
            signature = { enabled = true } 
        }
    },

    {   --  COLOR THEME
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000, -- Forces this to load first
        opts = {
            transparent = true, 
            styles = {
                sidebars = "transparent",
                floats = "transparent",
            },
        },
        config = function(_, opts)
            require("tokyonight").setup(opts)
            vim.cmd[[colorscheme tokyonight]]
        end
    },
})
