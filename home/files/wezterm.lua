-- Pull in the wezterm API
local wezterm = require("wezterm")
local mux = wezterm.mux

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices

config.color_scheme = "Solarized Dark Higher Contrast"
config.native_macos_fullscreen_mode = true
config.scrollback_lines = 100000
-- Keep SHIFT off the bypass so shift+click still reaches apps that grab the
-- mouse. The Claude Code TUI masks the modifier bits off the button byte, so
-- it arrives there as a plain click.
config.bypass_mouse_reporting_modifiers = "CTRL|ALT"

local SPECIAL_PASTE_COMBO = "SHIFT|ALT"
local PASTE_COMBO = "SHIFT|CTRL"
if wezterm.target_triple:match("macos") then
  config.font_size = 14.0
  SPECIAL_PASTE_COMBO = "SHIFT|CTRL"
  PASTE_COMBO = "SUPER"
else
  config.font = wezterm.font("Maple Mono NF")
  config.font_size = 13.0
end

wezterm.on("gui-startup", function(cmd)
  local window = mux.spawn_window(cmd or {})
  if wezterm.target_triple ~= "macos" then
    window:gui_window():toggle_fullscreen()
  else
    window:gui_window():maximize()
  end
end)

config.mouse_bindings = {
  -- CMD-click will open the link under the mouse cursor
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "CTRL",
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "NONE",
    action = wezterm.action_callback(function(window, pane)
      wezterm.GLOBAL.selection_buffer = window:get_selection_text_for_pane(pane)
    end),
  },
  {
    event = { Up = { streak = 2, button = "Left" } },
    mods = "NONE",
    action = wezterm.action_callback(function(window, pane)
      wezterm.GLOBAL.selection_buffer = window:get_selection_text_for_pane(pane)
    end),
  },
  {
    event = { Up = { streak = 3, button = "Left" } },
    mods = "NONE",
    action = wezterm.action.Nop,
  },

  -- Apps like the Claude Code fullscreen TUI turn on full mouse tracking, so
  -- the bindings above stop matching (an entry is only considered when the
  -- pane's mouse reporting state matches) and drags go to the app instead of
  -- building a selection. These claim the left button back so select and copy
  -- work without holding SHIFT. Wheel and other buttons still reach the app.
  {
    event = { Down = { streak = 1, button = "Left" } },
    mods = "NONE",
    mouse_reporting = true,
    action = wezterm.action.SelectTextAtMouseCursor("Cell"),
  },
  {
    event = { Drag = { streak = 1, button = "Left" } },
    mods = "NONE",
    mouse_reporting = true,
    action = wezterm.action.ExtendSelectionToMouseCursor("Cell"),
  },
  {
    event = { Down = { streak = 2, button = "Left" } },
    mods = "NONE",
    mouse_reporting = true,
    action = wezterm.action.SelectTextAtMouseCursor("Word"),
  },
  {
    event = { Drag = { streak = 2, button = "Left" } },
    mods = "NONE",
    mouse_reporting = true,
    action = wezterm.action.ExtendSelectionToMouseCursor("Word"),
  },
  {
    event = { Down = { streak = 3, button = "Left" } },
    mods = "NONE",
    mouse_reporting = true,
    action = wezterm.action.SelectTextAtMouseCursor("Line"),
  },
  {
    event = { Drag = { streak = 3, button = "Left" } },
    mods = "NONE",
    mouse_reporting = true,
    action = wezterm.action.ExtendSelectionToMouseCursor("Line"),
  },
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "NONE",
    mouse_reporting = true,
    action = wezterm.action_callback(function(window, pane)
      wezterm.GLOBAL.selection_buffer = window:get_selection_text_for_pane(pane)
    end),
  },
  {
    event = { Up = { streak = 2, button = "Left" } },
    mods = "NONE",
    mouse_reporting = true,
    action = wezterm.action_callback(function(window, pane)
      wezterm.GLOBAL.selection_buffer = window:get_selection_text_for_pane(pane)
    end),
  },
  {
    event = { Up = { streak = 3, button = "Left" } },
    mods = "NONE",
    mouse_reporting = true,
    action = wezterm.action.Nop,
  },

  -- Same again for CTRL+click to open a link. Down and Drag are bound to Nop so
  -- the press, and any wobble before the release, don't reach the app instead.
  {
    event = { Down = { streak = 1, button = "Left" } },
    mods = "CTRL",
    mouse_reporting = true,
    action = wezterm.action.Nop,
  },
  {
    event = { Drag = { streak = 1, button = "Left" } },
    mods = "CTRL",
    mouse_reporting = true,
    action = wezterm.action.Nop,
  },
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "CTRL",
    mouse_reporting = true,
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
}

config.keys = {

  { key = ";", mods = "CTRL", action = wezterm.action.ShowTabNavigator },
  { key = "k", mods = "CTRL", action = wezterm.action.ActivateCommandPalette },
  {
    key = "h",
    mods = "SHIFT|CMD",
    action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
  },
  {
    key = "v",
    mods = "SHIFT|CMD",
    action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }),
  },
  {
    key = "r",
    mods = "CMD|SHIFT",
    action = wezterm.action.ReloadConfiguration,
  },
  { key = "l", mods = "SHIFT|ALT", action = wezterm.action.ShowLauncher },
  -- Make Option-Left equivalent to Alt-b which many line editors interpret as backward-word
  { key = "LeftArrow", mods = "OPT", action = wezterm.action({ SendString = "\x1bb" }) },
  -- Make Option-Right equivalent to Alt-f; forward-word
  { key = "RightArrow", mods = "OPT", action = wezterm.action({ SendString = "\x1bf" }) },

  { mods = "", key = "Home", action = wezterm.action({ SendString = "\001" }) },
  { mods = "", key = "End", action = wezterm.action({ SendString = "\005" }) },
  {
    key = "v",
    mods = SPECIAL_PASTE_COMBO,
    action = wezterm.action_callback(function(_, pane)
      pane:send_text(wezterm.GLOBAL.selection_buffer)
    end),
  },
  { key = "v", mods = PASTE_COMBO, action = wezterm.action.PasteFrom("Clipboard") },
  { key = "c", mods = PASTE_COMBO, action = wezterm.action.CopyTo("ClipboardAndPrimarySelection") },
}

-- and finally, return the configuration to wezterm
return config
