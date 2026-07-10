-- lua/config/autocmds.lua

-- Tell WezTerm whether this pane is running Neovim. Read by is_vim() in
-- wezterm.lua to decide if Alt+hjkl should be forwarded into Neovim or
-- handled by WezTerm natively. smart-splits used to set this var, but its
-- CLI-based wezterm integration is disabled (slow on Windows), so we emit
-- it ourselves.
local function set_wezterm_user_var(name, value)
  local esc = string.format(
    "\027]1337;SetUserVar=%s=%s\007",
    name,
    vim.base64.encode(value)
  )
  -- v:stderr goes straight to the terminal, bypassing the UI layer
  vim.fn.chansend(vim.v.stderr, esc)
end

-- Emit immediately at config load (VimEnter alone would miss e.g. `nvim +q`,
-- and fires later than needed); VimResume re-emits after Ctrl+Z suspend.
set_wezterm_user_var("IS_NVIM", "true")
vim.api.nvim_create_autocmd({ "VimResume" }, {
  callback = function() set_wezterm_user_var("IS_NVIM", "true") end,
})
vim.api.nvim_create_autocmd({ "VimLeavePre", "VimSuspend" }, {
  callback = function() set_wezterm_user_var("IS_NVIM", "false") end,
})

-- Publish which directions Neovim can still move internally (another split
-- exists on that side) as the NVIM_CAN_MOVE user var, e.g. "hl" = splits to
-- the left and right. WezTerm's direction_keys() reads it to decide
-- instantly whether Alt+hjkl goes into Neovim or switches WezTerm panes
-- natively — leaving Neovim then costs zero terminal roundtrips.
local publish_scheduled = false
local last_can_move = nil

local function publish_can_move()
  publish_scheduled = false

  local can_move
  if vim.api.nvim_win_get_config(0).relative ~= "" then
    -- Floating window (Telescope, LSP hover, ...): window adjacency is
    -- meaningless here, so claim every direction — the key always goes to
    -- Neovim and smart-splits (+ NVIM_EDGE_NAV fallback) decides.
    can_move = "hjkl"
  else
    can_move = ""
    local cur = vim.fn.winnr()
    if vim.fn.winnr("1h") ~= cur then can_move = can_move .. "h" end
    if vim.fn.winnr("1j") ~= cur then can_move = can_move .. "j" end
    if vim.fn.winnr("1k") ~= cur then can_move = can_move .. "k" end
    if vim.fn.winnr("1l") ~= cur then can_move = can_move .. "l" end
  end

  if can_move ~= last_can_move then
    last_can_move = can_move
    set_wezterm_user_var("NVIM_CAN_MOVE", can_move)
  end
end

vim.api.nvim_create_autocmd(
  { "VimEnter", "WinEnter", "WinNew", "WinClosed", "WinResized", "TabEnter" },
  {
    callback = function()
      if publish_scheduled then return end
      publish_scheduled = true
      -- Deferred one tick: WinClosed fires while the closing window still
      -- exists, so computing immediately would read the old layout.
      vim.schedule(publish_can_move)
    end,
  }
)

-- Tell the terminal multiplexer to sync with Neovim's directory
vim.api.nvim_create_autocmd({ "DirChanged", "BufEnter" }, {
  callback = function()
    local cwd = vim.fn.expand("%:p:h")
    cwd = cwd:gsub("\\", "/") 
    if cwd ~= "" and vim.fn.isdirectory(cwd) == 1 then
      io.stdout:write(string.format("\x1b]7;file://%s%s\x1b\\", vim.fn.hostname(), cwd))
    end
  end,
})
