local colors = require("tint.colors")

local tint = {
  config = {
    tint = -40,
    saturation = 0.7,
    tint_background_colors = false,
    highlight_ignore_patterns = {},
    window_ignore_function = nil,
  },
}

-- Private "namespace" for functions, etc. that might not be defined before they are used
local __ = {}

--- Ensure the passed table has only valid keys to hand to `nvim_set_hl`
---
---@param hl_def table Value returned by `nvim_get_hl_by_name` with `rgb` colors exported
---@return table The passed highlight definition with valid `nvim_set_hl` keys only
local function ensure_valid_hl_keys(hl_def)
  return {
    fg = hl_def.fg or hl_def.foreground,
    bg = hl_def.bg or hl_def.background,
    sp = hl_def.sp or hl_def.special,
    blend = hl_def.blend,
    bold = hl_def.bold,
    standout = hl_def.standout,
    underline = hl_def.underline,
    undercurl = hl_def.undercurl,
    underdouble = hl_def.underdouble,
    underdotted = hl_def.underdotted,
    underdashed = hl_def.underdashed,
    strikethrough = hl_def.strikethrough,
    italic = hl_def.italic,
    reverse = hl_def.reverse,
    nocombine = hl_def.nocombine,
    link = hl_def.link,
    default = hl_def.default,
    ctermfg = hl_def.ctermfg,
    ctermbg = hl_def.ctermbg,
    cterm = hl_def.cterm,
  }
end

--- Determine if a window should be ignored or not, triggered on `WinLeave`
---
---@param winid number Window ID
---@return boolean Whether or not the window should be ignored for tinting
local function win_should_ignore_tint(winid)
  return tint.config.window_ignore_function and tint.config.window_ignore_function(winid) or false
end

--- Determine if a highlight group should be ignored or not
---
---@param hl_group_name string The name of the highlight group
---@return boolean `true` if the group should be ignored, `false` otherwise
local function hl_group_is_ignored(hl_group_name)
  for _, pat in ipairs(tint.config.highlight_ignore_patterns) do
    if string.find(hl_group_name, pat) then
      return true
    end
  end

  return false
end

--- Create the "default" (non-tinted) highlight namespace
---
---@param hl_group_name string
---@param hl_def table The highlight definition, see `:h nvim_set_hl`
local function set_default_ns(hl_group_name, hl_def)
  vim.api.nvim_set_hl(__.default_ns, hl_group_name, hl_def)
end

--- Create the "tinted" highlight namespace
---
---@param hl_group_name string
---@param hl_def table The highlight definition, see `:h nvim_set_hl`
local function set_tint_ns(hl_group_name, hl_def)
  if hl_def.fg and not hl_group_is_ignored(hl_group_name) then
    hl_def.fg = colors.transform_color(colors.get_hex(hl_def.fg), {
      colors.tint(tint.config.tint),
      colors.saturate(tint.config.saturation),
    })
  end

  if tint.config.tint_background_colors and hl_def.bg and not hl_group_is_ignored(hl_group_name) then
    hl_def.bg = colors.transform_color(colors.get_hex(hl_def.bg), tint.config.tint, tint.config.saturation)
  end

  vim.api.nvim_set_hl(__.tint_ns, hl_group_name, hl_def)
end

--- Setup color namespaces such that they can be set per-window
local function setup_namespaces()
  if not __.default_ns and not __.tint_ns then
    __.default_ns = vim.api.nvim_create_namespace("_tint_norm")
    __.tint_ns = vim.api.nvim_create_namespace("_tint_dim")
  end

  for hl_group_name, _ in pairs(vim.api.nvim__get_hl_defs(0)) do
    -- Seems we cannot always ask for `rgb` values from `nvim__get_hl_defs`
    local hl_def = vim.api.nvim_get_hl_by_name(hl_group_name, true)

    -- Ensure we only have valid keys copied over
    hl_def = ensure_valid_hl_keys(hl_def)
    set_default_ns(hl_group_name, hl_def)
    set_tint_ns(hl_group_name, hl_def)
  end
end

--- Setup autocommands to swap (or reconfigure) tint highlight namespaces
---
--- `WinLeave`: When leaving a window, tint it
--- `WinEnter`: When entering a window, untint it
--- `ColorScheme`: When changing colorschemes, reconfigure the tint namespaces
local function setup_autocmds()
  if __.setup_autocmds then
    return
  end

  local augroup = vim.api.nvim_create_augroup("_tint", { clear = true })

  vim.api.nvim_create_autocmd({ "FocusGained", "WinEnter" }, {
    group = augroup,
    pattern = { "*" },
    callback = __.on_focus,
  })

  vim.api.nvim_create_autocmd({ "FocusLost", "WinLeave" }, {
    group = augroup,
    pattern = { "*" },
    callback = __.on_unfocus,
  })

  vim.api.nvim_create_autocmd({ "ColorScheme" }, {
    group = augroup,
    pattern = { "*" },
    callback = __.on_colorscheme,
  })

  __.setup_autocmds = true
end

--- Verify the version of Neovim running has `nvim_win_set_hl_ns`, added via !13457
local function verify_version()
  if not vim.api.nvim_win_set_hl_ns then
    vim.notify(
      "tint.nvim requires a newer version of Neovim that provides 'nvim_win_set_hl_ns'",
      vim.lsp.log_levels.ERROR
    )

    return false
  end

  return true
end

--- Swap old configuration keys to new ones
local function _user_config_compat(config)
  config.tint = config.amt or config.tint
  config.tint_background_colors = config.bg ~= nil and config.bg or config.tint_background_colors
  config.highlight_ignore_patterns = config.ignore or config.highlight_ignore_patterns
  config.window_ignore_function = config.ignorefunc or config.window_ignore_function
end

--- Setup `tint.config` by overriding defaults with user values
---
---@param user_config table User configuration table passed to `setup`
local function setup_user_config(user_config)
  _user_config_compat(user_config or {})

  tint.config = vim.tbl_extend("force", tint.config, user_config)
end

--- Triggered by
---  `:h WinEnter`
---  `:h FocusGained`
--- to restore the default highlight namespace
__.on_focus = function()
  local winid = vim.api.nvim_get_current_win()
  if win_should_ignore_tint(winid) then
    return
  end

  vim.api.nvim_win_set_hl_ns(winid, __.default_ns)
end

--- Triggered by
---  `:h WinLeave`
---  `:h FocusLost`
--- to set the tint highlight namespace
__.on_unfocus = function()
  local winid = vim.api.nvim_get_current_win()
  if win_should_ignore_tint(winid) then
    return
  end

  vim.api.nvim_win_set_hl_ns(winid, __.tint_ns)
end

--- Triggered by `:h ColorScheme`, redefine highlights in both namespaces based on colors
--- in new colorscheme
__.on_colorscheme = function()
  __.setup_all()
end

--- Setup user configuration, highlight namespaces, and autocommands
__.setup_all = function(user_config)
  setup_user_config(user_config)
  setup_namespaces()
  setup_autocmds()
end

--- Setup the plugin - can be called infinite times but will only do setup once
---
---@public
---@param user_config table User configuration values, see `:h tint-setup`
tint.setup = function(user_config)
  if not verify_version() then
    return
  end

  if __.setup_module then
    return
  end

  __.setup_module = true
  __.setup_all(user_config)
end

return tint
