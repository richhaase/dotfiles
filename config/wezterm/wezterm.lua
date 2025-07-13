local wezterm = require("wezterm")
local config = {}

config.color_scheme = "Solarized Darcula"
config.font = wezterm.font("Hack Nerd Font")
config.font_size = 14
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}
config.hide_tab_bar_if_only_one_tab = true

return config
