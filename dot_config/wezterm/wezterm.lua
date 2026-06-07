-- ~/.config/wezterm/wezterm.lua
local wezterm = require 'wezterm'
local act = wezterm.action
local mux = wezterm.mux

local resurrect = wezterm.plugin.require('https://github.com/MLFlexer/resurrect.wezterm')

local config = wezterm.config_builder()
config.mux_enable_ssh_agent = false

local is_windows = wezterm.target_triple:find('windows') ~= nil

-- ============================================================
-- SHELL / OS-SPECIFIC PROGRAM
-- ============================================================
if is_windows then
  config.default_prog = { 'powershell.exe' }
end

-- ============================================================
-- RESURRECT: state location
-- Saves go to:  <home>\.wezterm-state\{workspace,window,tab}\
-- Those subfolders must exist (you already created them).
-- ============================================================
local sep = is_windows and '\\' or '/'
local state_dir = wezterm.home_dir .. sep .. '.wezterm-state' .. sep
resurrect.state_manager.change_state_save_dir(state_dir)

wezterm.on('resurrect.error', function(err)
  wezterm.log_error('resurrect error: ' .. tostring(err))
  local windows = wezterm.gui.gui_windows()
  if windows[1] then
    windows[1]:toast_notification('resurrect.wezterm', tostring(err), nil, 5000)
  end
end)

-- ============================================================
-- HELPERS
-- ============================================================
local function list_workspace_names()
  local pattern = (state_dir .. 'workspace' .. sep .. '*.json'):gsub('\\', '/')
  local names = {}
  for _, path in ipairs(wezterm.glob(pattern)) do
    local name = path:match('([^/\\]+)%.json$')
    if name then table.insert(names, name) end
  end
  return names
end

-- Save current workspace under its current workspace name.
local function save_session(win, pane)
  resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
  win:toast_notification('resurrect', 'Session saved', nil, 2000)
end

-- Save current workspace under a NAME you type.
local function save_session_as(win, pane)
  win:perform_action(
    act.PromptInputLine {
      description = 'Save snapshot as:',
      action = wezterm.action_callback(function(w, _, line)
        if line and line ~= '' then
          resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state(), line)
          w:toast_notification('resurrect', 'Saved: ' .. line, nil, 2000)
        end
      end),
    },
    pane
  )
end

-- Pick a snapshot by name and rebuild it INSIDE the current window.
local function restore_session(win, pane)
  local names = list_workspace_names()
  if #names == 0 then
    win:toast_notification('resurrect', 'No snapshots yet — press Alt+s to save one', nil, 3000)
    return
  end
  local choices = {}
  for _, n in ipairs(names) do
    table.insert(choices, { id = n, label = n })
  end
  win:perform_action(
    act.InputSelector {
      title = 'Restore snapshot',
      fuzzy = true,
      choices = choices,
      action = wezterm.action_callback(function(_, inner_pane, id)
        if not id then return end
        local state = resurrect.state_manager.load_state(id, 'workspace')
        resurrect.workspace_state.restore_workspace(state, {
          window = inner_pane:window(), -- reuse THIS window (stays fullscreen)
          relative = true,
          restore_text = true,
          close_open_tabs = true,       -- replace current tabs/panes -> repeatable
          resize_window = false,        -- don't force saved pixel size -> no shift
          on_pane_restore = resurrect.tab_state.default_on_pane_restore,
        })
      end),
    },
    pane
  )
end

-- Pick a snapshot and delete it.
local function delete_session(win, pane)
  local names = list_workspace_names()
  if #names == 0 then
    win:toast_notification('resurrect', 'No snapshots to delete', nil, 2000)
    return
  end
  local choices = {}
  for _, n in ipairs(names) do
    table.insert(choices, { id = n, label = n })
  end
  win:perform_action(
    act.InputSelector {
      title = 'Delete snapshot',
      fuzzy = true,
      choices = choices,
      action = wezterm.action_callback(function(_, _, id)
        if not id then return end
        resurrect.state_manager.delete_state('workspace/' .. id .. '.json')
      end),
    },
    pane
  )
end

-- ============================================================
-- APPEARANCE
-- ============================================================
config.enable_tab_bar = false
config.color_scheme = 'Tokyo Night'
config.font_size = 15
config.window_decorations = 'RESIZE'
config.window_background_image = wezterm.config_dir .. '/background.jpg'
config.window_background_image_hsb = {
  brightness = 0.1,
  hue = 1,
  saturation = 1.5,
}
config.inactive_pane_hsb = {
  saturation = 0.75,
  brightness = 0.65,
}
config.colors = {
  split = '#90D6FF',
}

-- ============================================================
-- NEOVIM-AWARE PANE NAVIGATION (smart-splits)
-- ============================================================
local function is_vim(pane)
  return pane:get_user_vars().IS_NVIM == 'true'
end

local function direction_keys(key, direction)
  return {
    key = key,
    mods = 'ALT',
    action = wezterm.action_callback(function(window, pane)
      if is_vim(pane) then
        window:perform_action({ SendKey = { key = key, mods = 'ALT' } }, pane)
      else
        window:perform_action({ ActivatePaneDirection = direction }, pane)
      end
    end),
  }
end

config.keys = {
  -- 1. Seamless navigation (Alt + h/j/k/l)
  direction_keys('h', 'Left'),
  direction_keys('j', 'Down'),
  direction_keys('k', 'Up'),
  direction_keys('l', 'Right'),

  -- 2. Split panes (Ctrl + h/j/k/l)
  { key = 'h', mods = 'CTRL', action = act.SplitPane { direction = 'Left' } },
  { key = 'j', mods = 'CTRL', action = act.SplitPane { direction = 'Down' } },
  { key = 'k', mods = 'CTRL', action = act.SplitPane { direction = 'Up' } },
  { key = 'l', mods = 'CTRL', action = act.SplitPane { direction = 'Right' } },

  -- 3. Window management
  { key = 'x', mods = 'CTRL', action = act.CloseCurrentPane { confirm = true } },
  { key = 'z', mods = 'CTRL', action = act.TogglePaneZoomState },

  -- 4. Resize panes (Alt + Shift + h/j/k/l)
  { key = 'H', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Left', 5 } },
  { key = 'J', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Down', 5 } },
  { key = 'K', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Up', 5 } },
  { key = 'L', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Right', 5 } },

  -- 5. Resurrect session (manual only)
  { key = 's', mods = 'ALT', action = wezterm.action_callback(save_session) },
  { key = 'S', mods = 'ALT|SHIFT', action = wezterm.action_callback(save_session_as) },
  { key = 'r', mods = 'ALT', action = wezterm.action_callback(restore_session) },
  { key = 'd', mods = 'ALT', action = wezterm.action_callback(delete_session) },
}

-- ============================================================
-- FULLSCREEN ON LAUNCH (guarded against multiple startup evaluations)
-- ============================================================
wezterm.on('gui-startup', function(cmd)
  -- If the mux already has a window, a prior evaluation already spawned one.
  -- Don't spawn another — just fullscreen the existing one.
  local existing = mux.all_windows()
  if #existing > 0 then
    local gui = existing[1]:gui_window()
    if gui then gui:toggle_fullscreen() end
    return
  end
  local tab, pane, window = mux.spawn_window(cmd or {})
  window:gui_window():toggle_fullscreen()
end)

return config
