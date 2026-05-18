local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()


config.default_prog = { 'powershell.exe' }

-- This is where you actually apply your config choices

-- For example, changing the color scheme:
config.enable_tab_bar = true
config.color_scheme = 'Tokyo Night'
config.font_size = 15
config.window_decorations = "RESIZE"
config.window_background_image = "D:/Programs/Editors/WezTerm/Killua.jpg"
config.window_background_image_hsb = {
  -- Darken the background image by reducing it to 1/3rd
  brightness = 0.15,

  -- You can adjust the hue by scaling its value.
  -- a multiplier of 1.0 leaves the value unchanged.
  hue = 1,

  -- You can adjust the saturation also.
  saturation = 2,
}
config.default_cwd = "D:/"
local mux = wezterm.mux


wezterm.on("gui-startup", function()
  local tab, pane, window = mux.spawn_window{}
  window:gui_window():toggle_fullscreen()
end)
-- and finally, return the configuration to wezterm
return config
