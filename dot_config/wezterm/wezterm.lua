-- WezTerm owns templates, running instances, and pane navigation.
local wezterm = require 'wezterm'
local act = wezterm.action
local mux = wezterm.mux
local templates_path = wezterm.config_dir .. '/workspace_templates.lua'
wezterm.add_to_config_reload_watch_list(templates_path)
local templates = dofile(templates_path)
local config = wezterm.config_builder()
config.mux_enable_ssh_agent = false
config.default_workspace = 'main'
if wezterm.target_triple:find('windows') then
  config.default_prog = { 'powershell.exe' }
end

-- Enter in Copy Mode opens a selected reference in a new Neovim pane.
local reference_path = wezterm.config_dir .. '/open_reference.lua'
wezterm.add_to_config_reload_watch_list(reference_path)
local reference = dofile(reference_path)
reference.apply(config)

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

  -- Inspect/copy terminal output from any application.
  { key = 'c', mods = 'ALT', action = act.ActivateCopyMode },

  -- 3. Window management
  { key = 'x', mods = 'CTRL', action = reference.layout_action(act.CloseCurrentPane { confirm = true }) },
  { key = 'z', mods = 'CTRL', action = reference.layout_action(act.TogglePaneZoomState) },

  -- 4. Resize panes (Alt + Shift + h/j/k/l)
  { key = 'H', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Left', 5 } },
  { key = 'J', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Down', 5 } },
  { key = 'K', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Up', 5 } },
  { key = 'L', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Right', 5 } },

  -- 5. Running instances: Ctrl+Alt+h/k previous; Ctrl+Alt+j/l next.
  { key = 'h', mods = 'CTRL|ALT', action = act.SwitchWorkspaceRelative(-1) },
  { key = 'k', mods = 'CTRL|ALT', action = act.SwitchWorkspaceRelative(-1) },
  { key = 'j', mods = 'CTRL|ALT', action = act.SwitchWorkspaceRelative(1) },
  { key = 'l', mods = 'CTRL|ALT', action = act.SwitchWorkspaceRelative(1) },
  -- Templates create new instances; Alt+R renames only the current instance.
  { key = 'w', mods = 'ALT', action = templates.create_instance },
  { key = 'n', mods = 'ALT', action = templates.new_template },
  { key = 'r', mods = 'ALT', action = templates.rename_instance },
  { key = 's', mods = 'ALT', action = templates.save_template },
  { key = 'd', mods = 'ALT', action = templates.delete_template },
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
