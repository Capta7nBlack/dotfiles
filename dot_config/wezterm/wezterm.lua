local wezterm = require 'wezterm'
local act = wezterm.action
local mux = wezterm.mux


-- This will hold the configuration.
local config = wezterm.config_builder()

local is_windows = wezterm.target_triple:find("windows") ~= nil
local is_mac = wezterm.target_triple:find("apple") ~= nil

if is_windows then
  require('windows')(config)
else
  -- This handles both Linux and macOS for all standard behavior
  require('unix')(config)
end


-- This is where you actually apply your config choices

-- For example, changing the color scheme:
config.enable_tab_bar = false
config.color_scheme = 'Tokyo Night'
config.font_size = 15
config.window_decorations = "RESIZE"
config.window_background_image = wezterm.config_dir .. '/background.jpg'
config.window_background_image_hsb = {
  -- Darken the background image by reducing it to 1/3rd
  brightness = 0.2,

  -- You can adjust the hue by scaling its value.
  -- a multiplier of 1.0 leaves the value unchanged.
  hue = 1,

  -- You can adjust the saturation also.
  saturation = 1.5,
}

config.inactive_pane_hsb = {
  saturation = 0.75,
  brightness = 0.65,
}

-- Force the split lines to be a highly visible color
-- You can change this hex code to match your theme (e.g., a bright blue or distinct gray)
config.colors = {
  split = "#90D6FF", -- A nice visible blue. Change to '#888888' for neutral gray.
}



-- Helper to detect Neovim
local function is_vim(pane)
  local process_name = pane:get_foreground_process_name()
  if not process_name then return false end
  process_name = process_name:match("^.+[/\\](.+)$") or process_name
  return process_name == 'nvim' or process_name == 'nvim.exe'
end

-- Helper for seamless movement (Alt + h/j/k/l)
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
  -- === 1. SEAMLESS NAVIGATION (Alt + h/j/k/l) ===
  direction_keys('h', 'Left'),
  direction_keys('j', 'Down'),
  direction_keys('k', 'Up'),
  direction_keys('l', 'Right'),

  -- === 2. TERMINAL PANE SPLITTING (Ctrl + h/j/k/l) ===
  -- These will always split the WezTerm terminal, creating a new pane in the direction pressed
  { key = 'h', mods = 'CTRL', action = act.SplitPane { direction = 'Left' } },
  { key = 'j', mods = 'CTRL', action = act.SplitPane { direction = 'Down' } },
  { key = 'k', mods = 'CTRL', action = act.SplitPane { direction = 'Up' } },
  { key = 'l', mods = 'CTRL', action = act.SplitPane { direction = 'Right' } },

  -- === 3. WINDOW MANAGEMENT (Ctrl + x / Ctrl + m) ===
  -- Close current pane
  { key = 'x', mods = 'CTRL', action = act.CloseCurrentPane { confirm = true } },
  -- Toggle maximize pane
  { key = 'm', mods = 'CTRL', action = act.TogglePaneZoomState },

  -- === 4. RESIZE PANES (Alt + Shift + h/j/k/l) ===
  { key = 'H', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Left', 5 } },
  { key = 'J', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Down', 5 } },
  { key = 'K', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Up', 5 } },
  { key = 'L', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Right', 5 } },
}


wezterm.on("gui-startup", function()
  local tab, pane, window = mux.spawn_window{}
  window:gui_window():toggle_fullscreen()
end)
-- and finally, return the configuration to wezterm
return config
