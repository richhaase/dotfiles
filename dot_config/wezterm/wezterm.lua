local wezterm = require("wezterm")
local config = {}

local function is_vim(pane)
    -- this is set by the plugin, and unset on ExitPre in Neovim
    return pane:get_user_vars().IS_NVIM == "true"
end

local direction_keys = {
    h = "Left",
    j = "Down",
    k = "Up",
    l = "Right",
}

local function split_nav(resize_or_move, key)
    return {
        key = key,
        mods = resize_or_move == "resize" and "META" or "CTRL",
        action = wezterm.action_callback(function(win, pane)
            if is_vim(pane) then
                -- pass the keys through to vim/nvim
                win:perform_action({
                    SendKey = { key = key, mods = resize_or_move == "resize" and "META" or "CTRL" },
                }, pane)
            else
                if resize_or_move == "resize" then
                    win:perform_action({ AdjustPaneSize = { direction_keys[key], 3 } }, pane)
                else
                    win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
                end
            end
        end),
    }
end

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

config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
    -- splitting
    {
        mods = "LEADER",
        key = "-",
        action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }),
    },
    {
        mods = "LEADER",
        key = "=",
        action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
    },
    -- zoom pane
    {
        mods = "LEADER",
        key = "m",
        action = wezterm.action.TogglePaneZoomState,
    },
    -- rotate panes
    {
        mods = "LEADER",
        key = "Space",
        action = wezterm.action.RotatePanes("Clockwise"),
    },
    -- show the pane selection mode, but have it swap the active and selected panes
    {
        mods = "LEADER",
        key = "0",
        action = wezterm.action.PaneSelect({
            mode = "SwapWithActive",
        }),
    },
    -- move between split panes
    split_nav("move", "h"),
    split_nav("move", "j"),
    split_nav("move", "k"),
    split_nav("move", "l"),
    -- resize panes
    split_nav("resize", "h"),
    split_nav("resize", "j"),
    split_nav("resize", "k"),
    split_nav("resize", "l"),
}

return config
