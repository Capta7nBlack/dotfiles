-- ~/.config/wezterm/wezterm.lua
local wezterm = require 'wezterm'
local act = wezterm.action
local mux = wezterm.mux

local resurrect = wezterm.plugin.require('https://github.com/MLFlexer/resurrect.wezterm')

local config = wezterm.config_builder()
config.mux_enable_ssh_agent = false
config.default_workspace = 'main'

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
-- With named workspaces, the snapshot file is automatically <workspace>.json.
local function save_session(win, pane)
  resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
  win:toast_notification('resurrect', 'Saved: ' .. mux.get_active_workspace(), nil, 2000)
end

-- Unified picker: live workspaces (●) switch instantly, saved snapshots (○)
-- are restored into a fresh workspace of the same name. Other workspaces
-- keep running untouched in the background.
local function workspace_picker(win, pane)
  local live = mux.get_workspace_names()
  local is_live = {}
  local choices = {}
  for _, n in ipairs(live) do
    is_live[n] = true
    table.insert(choices, { id = n, label = '● ' .. n })
  end
  for _, n in ipairs(list_workspace_names()) do
    if not is_live[n] then
      table.insert(choices, { id = n, label = '○ ' .. n })
    end
  end
  win:perform_action(
    act.InputSelector {
      title = 'Workspaces  (● live · ○ snapshot)',
      fuzzy = true,
      choices = choices,
      action = wezterm.action_callback(function(w, inner_pane, id)
        if not id then return end
        if is_live[id] then
          w:perform_action(act.SwitchToWorkspace { name = id }, inner_pane)
          w:toast_notification('workspace', '→ ' .. id, nil, 1500)
          return
        end
        -- Not live: create the workspace, then restore the snapshot into it.
        w:perform_action(act.SwitchToWorkspace { name = id }, inner_pane)
        -- SwitchToWorkspace spawns the new workspace asynchronously; defer the
        -- restore one tick so it lands in the new workspace's window.
        wezterm.time.call_after(0.15, function()
          local state = resurrect.state_manager.load_state(id, 'workspace')
          local gui = wezterm.gui.gui_windows()[1]
          if not gui then return end
          resurrect.workspace_state.restore_workspace(state, {
            window = gui:mux_window(),
            relative = true,
            restore_text = true,
            close_open_tabs = true,   -- replace the fresh workspace's blank tab
            resize_window = false,
            on_pane_restore = resurrect.tab_state.default_on_pane_restore,
          })
          gui:toast_notification('workspace', '→ ' .. id .. ' (restored)', nil, 1500)
        end)
      end),
    },
    pane
  )
end

-- Create a new named workspace and switch to it.
local function new_workspace(win, pane)
  win:perform_action(
    act.PromptInputLine {
      description = 'New workspace name:',
      action = wezterm.action_callback(function(w, inner_pane, line)
        if line and line ~= '' then
          w:perform_action(act.SwitchToWorkspace { name = line }, inner_pane)
          w:toast_notification('workspace', '→ ' .. line .. ' (new)', nil, 1500)
        end
      end),
    },
    pane
  )
end

-- Rename the current workspace. Note: the saved snapshot keeps its old name;
-- press Alt+s afterwards to save under the new name (Alt+d to purge the old).
local function rename_workspace(win, pane)
  local current = mux.get_active_workspace()
  win:perform_action(
    act.PromptInputLine {
      description = 'Rename workspace "' .. current .. '" to:',
      action = wezterm.action_callback(function(w, _, line)
        if line and line ~= '' then
          mux.rename_workspace(current, line)
          w:toast_notification('workspace', current .. ' → ' .. line, nil, 2000)
        end
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
-- Tab bar as a pure status strip: tabs hidden, only workspace name shown.
config.enable_tab_bar = true
config.use_fancy_tab_bar = false          -- retro bar: thin, text-only
config.show_tabs_in_tab_bar = false       -- hide the tabs themselves
config.show_new_tab_button_in_tab_bar = false
config.tab_bar_at_bottom = false

-- Right status: list of live workspaces, active one highlighted bold blue.
wezterm.on('update-status', function(window, pane)
  local active = window:active_workspace()
  local names = mux.get_workspace_names() -- sorted alphabetically
  local parts = {}
  for _, name in ipairs(names) do
    if name == active then
      table.insert(parts, { Attribute = { Intensity = 'Bold' } })
      table.insert(parts, { Foreground = { Color = '#7aa2f7' } })
      table.insert(parts, { Text = ' ' .. name .. ' ' })
      table.insert(parts, 'ResetAttributes')
    else
      table.insert(parts, { Foreground = { Color = '#565f89' } }) -- Tokyo Night comment gray
      table.insert(parts, { Text = ' ' .. name .. ' ' })
    end
  end
  window:set_right_status(wezterm.format(parts))
end)
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
  tab_bar = {
    background = 'rgba(0,0,0,0)', -- fully transparent: background image shows through
  },
}

-- ============================================================
-- NEOVIM-AWARE PANE NAVIGATION (smart-splits)
-- ============================================================
local function is_vim(pane)
  return pane:get_user_vars().IS_NVIM == 'true'
end

-- Neovim (smart-splits at_edge) hands navigation over via a user var when
-- the cursor moves past its outermost split. Payload is "direction:counter";
-- the counter only exists to make each value unique so the event always
-- fires. This replaces `wezterm cli activate-pane-direction`, whose process
-- spawn cost 20-1000ms per keypress on Windows.
wezterm.on('user-var-changed', function(window, pane, name, value)
  if name == 'NVIM_EDGE_NAV' then
    local dir_map = { left = 'Left', down = 'Down', up = 'Up', right = 'Right' }
    local direction = dir_map[value:match('^(%a+)')]
    if direction then
      window:perform_action(act.ActivatePaneDirection(direction), pane)
    end
  end
end)

-- Neovim publishes NVIM_CAN_MOVE (see nvim autocmd.lua): the hjkl directions
-- in which it has internal splits. If Neovim can't move that way, don't send
-- the key into Neovim at all — switch panes natively right here. Forwarding
-- and waiting for Neovim to hand navigation back (NVIM_EDGE_NAV) costs a
-- full terminal roundtrip per keypress; this path costs none.
local dir_to_hjkl = { Left = 'h', Down = 'j', Up = 'k', Right = 'l' }

local function nvim_handles(pane, direction)
  local can_move = pane:get_user_vars().NVIM_CAN_MOVE
  if can_move == nil then
    -- Not published yet (Neovim session older than this config): forward the
    -- key; the NVIM_EDGE_NAV fallback still makes navigation work.
    return true
  end
  return can_move:find(dir_to_hjkl[direction], 1, true) ~= nil
end

local function direction_keys(key, direction)
  return {
    key = key,
    mods = 'ALT',
    action = wezterm.action_callback(function(window, pane)
      if is_vim(pane) and nvim_handles(pane, direction) then
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

  -- 5. Workspaces + resurrect
  { key = 'h', mods = 'CTRL|ALT', action = act.SwitchWorkspaceRelative(-1) },
  { key = 'l', mods = 'CTRL|ALT', action = act.SwitchWorkspaceRelative(1) },
  { key = 'w', mods = 'ALT', action = wezterm.action_callback(workspace_picker) },
  { key = 'n', mods = 'ALT', action = wezterm.action_callback(new_workspace) },
  { key = 'r', mods = 'ALT', action = wezterm.action_callback(rename_workspace) },
  { key = 's', mods = 'ALT', action = wezterm.action_callback(save_session) },
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
