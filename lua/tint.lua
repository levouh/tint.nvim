local colors = require("tint.colors")
local transforms = require("tint.transforms")

---@class TintHlGroupInfo
---@field hl_group_name string the highlight group name, pass to `:h nvim_get_hl_by_name` for more highlight information

---@alias TintTransformFunction function(r: number, g: number, b: number, TintHlGroupInfo): number, number, number
---@alias TintWindowIgnoreFunction function(winid: number):boolean

---@class TintFocusChangeEvents
---@field focus table<string> events that trigger focus
---@field unfocus table<string> events that trigger unfocus

---@class TintUserConfiguration
---@field tint number? amount to tint, negative dims positive brightens
---@field saturation float? saturation to preserve, must be betwee, 0.0 and 1.0
---@field transforms table<TintTransformFunction>|string|nil functions called in order to transform a color
---@field tint_background_colors boolean? whether backgrounds of colors should be tinted or not
---@field highlight_ignore_patterns table<string>? highlight group names to not tint
---@field window_ignore_function TintWindowIgnoreFunction? granular control over whether tint touches a window _at all_
---@field focus_change_events TintFocusChangeEvents?

local tint = { transforms = { SATURATE_TINT = "saturate_tint" } }

-- Private "namespace" for functions, etc. that might not be defined before they are used
local __ = { enabled = true, current_window = nil }

--- Default module configuration values
---
---@type TintUserConfiguration
__.default_config = {
  tint = -40,
  saturation = 0.7,
  transforms = nil,
  tint_background_colors = false,
  highlight_ignore_patterns = {},
  window_ignore_function = nil,
  focus_change_events = {
    focus = { "WinEnter" },
    unfocus = { "WinLeave" },
  },
}

-- Pre-defined transforms that can be used by the user
__.transforms = {
  [tint.transforms.SATURATE_TINT] = function()
    return {
      transforms.saturate(__.user_config.saturation),
      transforms.tint(__.user_config.tint),
    }
  end,
}

--- Ensure the passed table has only valid keys to hand to `nvim_set_hl`
---
---@param hl_def table Value returned by `nvim_get_hl_by_name` with `rgb` colors exported
---@return table # highlight definition with valid `nvim_set_hl` keys only
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

--- Get the set of transforms to apply to highlight groups from the colorscheme in question
---
---@return table<function> # callables to transform the input RGB color values by
local function get_transforms()
  if type(__.user_config.transforms) == "string" then
    if __.transforms[__.user_config.transforms] then
      return __.transforms[__.user_config.transforms]()
    else
      return __.transforms[tint.transforms.SATURATE_TINT]()
    end
  elseif __.user_config.transforms then
    ---@diagnostic disable-next-line
    return __.user_config.transforms
  else
    return __.transforms[tint.transforms.SATURATE_TINT]()
  end
end

--- Determine if a window should be ignored or not, triggered on `WinLeave`
---
---@param winid number window handle
---@return boolean # whether or not the window should be ignored for tinting
local function win_should_ignore_tint(winid)
  return __.user_config.window_ignore_function and __.user_config.window_ignore_function(winid) or false
end

--- Determine if a highlight group should be ignored or not
---
---@param hl_group_name string name of the highlight group
---@return boolean # whether or not the group should be ignored
local function hl_group_is_ignored(hl_group_name)
  for _, pat in ipairs(__.user_config.highlight_ignore_patterns) do
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
---@param hl_def table # highlight definition, see `:h nvim_set_hl`
local function set_tint_ns(hl_group_name, hl_def, ns_hl_id)
  local ignored = hl_group_is_ignored(hl_group_name)
  local hl_group_info = { hl_group_name = hl_group_name }

  if hl_def.fg and not ignored then
    ---@diagnostic disable-next-line
    hl_def.fg = transforms.transform_color(hl_group_info, colors.get_hex(hl_def.fg), __.user_config.transforms)
  end

  if hl_def.sp and not ignored then
    ---@diagnostic disable-next-line
    hl_def.sp = transforms.transform_color(hl_group_info, colors.get_hex(hl_def.sp), __.user_config.transforms)
  end

  if __.user_config.tint_background_colors and hl_def.bg and not ignored then
    ---@diagnostic disable-next-line
    hl_def.bg = transforms.transform_color(hl_group_info, colors.get_hex(hl_def.bg), __.user_config.transforms)
  end

  vim.api.nvim_set_hl(ns_hl_id, hl_group_name, hl_def)
end

--- Backwards compatibile (for now) method of getting highlights as nvim__get_hl_defs is removed in #22693
---
---@return table<string, any> # highlight definitions
local function get_global_highlights(ns_id)
  ---@diagnostic disable-next-line: undefined-field
  return vim.api.nvim__get_hl_defs and vim.api.nvim__get_hl_defs(ns_id) or vim.api.nvim_get_hl(ns_id, {})
end

--- Setup color namespaces such that they can be set per-window
local function setup_namespaces()
  if not __.default_ns and not __.tint_ns then
    __.default_ns = vim.api.nvim_create_namespace("_tint_norm")
    __.tint_ns = vim.api.nvim_create_namespace("_tint_dim")
  end

  for hl_group_name, hl_def in pairs(get_global_highlights(0)) do
    -- Ensure we only have valid keys copied over
    hl_def = ensure_valid_hl_keys(hl_def)
    set_default_ns(hl_group_name, hl_def)
    set_tint_ns(hl_group_name, hl_def, __.tint_ns)
  end
end

local function add_namespace(ns_id, suffix)
  __["tint_ns_" .. suffix] = vim.api.nvim_create_namespace("_tint_dim_" .. suffix)

  for hl_group_name, hl_def in pairs(get_global_highlights(ns_id)) do
    -- Ensure we only have valid keys copied over
    hl_def = ensure_valid_hl_keys(hl_def)
    set_tint_ns(hl_group_name, hl_def, __["tint_ns_" .. suffix])
  end
end

---@param winid number
---@return number
local function get_untint_ns_id(winid)
  local untint_ns_id = vim.w[winid].untint_ns_id
  if untint_ns_id == nil then
    untint_ns_id = vim.api.nvim_get_hl_ns and vim.api.nvim_get_hl_ns({ winid = winid })
    if untint_ns_id == nil or untint_ns_id < 0 then
      untint_ns_id = 0
    end
    vim.api.nvim_win_set_var(winid, "untint_ns_id", untint_ns_id)
  end
  return untint_ns_id
end

---@param winid number
---@return number
local function get_tint_ns_id(winid)
  local untint_ns_id = get_untint_ns_id(winid)

  local tint_ns_id
  if untint_ns_id == 0 then
    tint_ns_id = __.tint_ns
  else
    local ns_suffix
    for ns_name, ns_id in pairs(vim.api.nvim_get_namespaces()) do
      if ns_id == untint_ns_id then
        ns_suffix = ns_name
        break
      end
    end
    if not ns_suffix then
      ns_suffix = untint_ns_id
    end

    if not __["tint_ns_" .. ns_suffix] then
      add_namespace(untint_ns_id, ns_suffix)
    end
    tint_ns_id = __["tint_ns_" .. ns_suffix]
  end

  if type(tint_ns_id) ~= "number" then
    tint_ns_id = 0
  end

  return tint_ns_id
end

--- Create an `:h augroup` for autocommands used by this plugin
---
---@return number # handle for created augroup
local function create_augroup()
  return vim.api.nvim_create_augroup("_tint", { clear = true })
end

--- Setup autocommands to swap (or reconfigure) tint highlight namespaces
---
--- `__.user_config.focus_change_events.focus`: Tint the window
---  `__.user_config.focus_change_events.unfocus`: Untint the window
--- `ColorScheme`: When changing colorschemes, reconfigure the tint namespaces
local function setup_autocmds()
  if __.setup_autocmds then
    return
  end

  local augroup = create_augroup()
  local focus_events = __.user_config.focus_change_events.focus

  if not vim.tbl_contains(focus_events, "WinClosed") then
    table.insert(focus_events, "WinClosed")
  end

  vim.api.nvim_create_autocmd(__.user_config.focus_change_events.focus, {
    group = augroup,
    pattern = { "*" },
    callback = __.on_focus_or_close,
  })

  vim.api.nvim_create_autocmd(__.user_config.focus_change_events.unfocus, {
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
---
---@return boolean # whether or not the running Neovim instance has the functions necessary for this function to run
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

--- Swap old configuration keys to new ones, handle cases `tbl_extend` does not (nested config values)
---
---@param user_config table old style user configuration
---@return TintUserConfiguration # modified user configuration to follow new format
local function get_user_config(user_config)
  local new_config = vim.deepcopy(user_config)

  -- Copy over old configuration values here before calling `tbl_extend` later
  new_config.tint = user_config.amt or user_config.tint
  new_config.tint_background_colors = user_config.bg ~= nil and user_config.bg or user_config.tint_background_colors
  new_config.highlight_ignore_patterns = user_config.ignore or user_config.highlight_ignore_patterns
  new_config.window_ignore_function = user_config.ignorefunc or user_config.window_ignore_function

  if new_config.focus_change_events then
    new_config.focus_change_events.focus = new_config.focus_change_events.focus
      or __.default_config.focus_change_events.focus
    new_config.focus_change_events.unfocus = new_config.focus_change_events.unfocus
      or __.default_config.focus_change_events.unfocus
  end

  return new_config
end

--- Setup `__.user_config` by overriding defaults with user values
local function setup_user_config()
  __.user_config = vim.tbl_extend("force", __.default_config, get_user_config(__.user_config or {}))

  vim.validate({
    tint = { __.user_config.tint, "number" },
    saturation = { __.user_config.saturation, "number" },
    transforms = {
      __.user_config.transforms,
      function(val)
        if type(val) == "string" then
          return __.transforms[val]
        elseif type(val) == "table" then
          for _, v in ipairs(val) do
            if type(v) ~= "function" then
              return false
            end
          end

          return true
        elseif val == nil then
          return true
        end

        return false
      end,
      "'tint' passed invalid value for option 'transforms'",
    },
    tint_background_colors = { __.user_config.tint_background_colors, "boolean" },
    highlight_ignore_patterns = {
      __.user_config.highlight_ignore_patterns,
      function(val)
        for _, v in ipairs(val) do
          if type(v) ~= "string" then
            return false
          end
        end

        return true
      end,
      "'tint' passed invalid value for option 'highlight_ignore_patterns'",
    },
    window_ignore_function = { __.user_config.window_ignore_function, "function", true },
    focus_change_events = {
      __.user_config.focus_change_events,
      function(val)
        if type(val) ~= "table" then
          return false
        end

        if not val.focus or not val.unfocus then
          return false
        end

        for _, v in ipairs(val.focus) do
          if type(v) ~= "string" then
            return false
          end
        end

        for _, v in ipairs(val.unfocus) do
          if type(v) ~= "string" then
            return false
          end
        end

        return true
      end,
      "'tint' passed invalid value for option 'focus_change_events'",
    },
  })

  __.user_config.transforms = get_transforms()
end

--- Ensure the passed function runs after `:h VimEnter` has run
---
---@param func function to call only after `VimEnter` is done
local function on_or_after_vimenter(func)
  if vim.v.vim_did_enter == 1 then
    func()
  else
    vim.api.nvim_create_autocmd({ "VimEnter" }, {
      callback = func,
      once = true,
    })
  end
end

--- Iterate all windows in all tabpages and call the passed function on them
---
---@param func function(winid: number, tabpage: number) called for every valid tabpage and contained window
local function iterate_all_windows(func)
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    if vim.api.nvim_tabpage_is_valid(tabpage) then
      for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
        if vim.api.nvim_win_is_valid(winid) then
          func(winid, tabpage)
        end
      end
    end
  end
end

--- Restore the global highlight namespace in all windows
local function restore_default_highlight_namespaces()
  iterate_all_windows(function(winid, _)
    vim.api.nvim_win_set_hl_ns(winid, get_untint_ns_id(winid))
    vim.api.nvim_win_del_var(winid, "untint_ns_id")
  end)
end

--- Set the tint highlight namespace in all unfocused windows
local function tint_unfocused_windows()
  iterate_all_windows(function(winid, _)
    if winid ~= vim.api.nvim_get_current_win() and vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_win_call(winid, function()
        __.on_unfocus()
      end)
    end
  end)
end

--- Check if this plugin is currently enabled
---
---@return boolean # whether or not the plugin is enabled
local function check_enabled()
  return __.enabled
end

--- Handle triggering focus events after a window closes
---
--- See #38 for more context, but sometimes when a window is closed
--- the `:h WinEnter` event will not be triggered appropriately
local function handle_close_event()
  vim.schedule(function()
    tint.untint(vim.api.nvim_get_current_win())
  end)
end

--- Check if the event is for a window closing
---
---@param event table Arguments from the associated `:h nvim_create_autocmd` setup
local function is_close_event(event)
  return event and event.event == "WinClosed"
end

--- Set the highlight namespace for a window
---
---@param winid number window handle
---@param hl_ns_id number namespace handle
local function set_window_hl_ns(winid, hl_ns_id)
  local existing = vim.w[winid].tint_hl_ns_id
  if existing and existing == hl_ns_id then
    return
  end

  vim.api.nvim_win_set_var(winid, "tint_hl_ns_id", hl_ns_id)
  vim.api.nvim_win_set_hl_ns(winid, hl_ns_id)
end

--- Triggered by TintFocusChangeEvents.focus
---
--- Restore the default highlight namespace
---
---@param event table arguments from the associated `:h nvim_create_autocmd` setup
__.on_focus_or_close = function(event)
  if not check_enabled() then
    return
  end

  local winid = vim.api.nvim_get_current_win()
  if win_should_ignore_tint(winid) then
    return
  end

  if is_close_event(event) then
    handle_close_event()
  else
    tint.untint(winid)
  end
end

--- Triggered by TintFocusChangeEvents.unfocus
---
--- Set the tint highlight namespace
---
---@param _ table? arguments from the associated `:h nvim_create_autocmd` setup
__.on_unfocus = function(_)
  if not check_enabled() then
    return
  end

  local winid = vim.api.nvim_get_current_win()
  if win_should_ignore_tint(winid) then
    return
  end

  tint.tint(winid)
end

--- Triggered by `:h ColorScheme`
---
--- Redefine highlights in both namespaces based on colors in new colorscheme
---
---@param _ table arguments from the associated `:h nvim_create_autocmd` setup
__.on_colorscheme = function(_)
  if not check_enabled() then
    return
  end

  __.setup_all(true)
end

--- Setup everything required for this module to run
---
---@param skip_config boolean? skip re-doing user configuration setup, useful when re-enabling, etc.
__.setup_all = function(skip_config)
  if not skip_config then
    setup_user_config()
  end

  setup_namespaces()
  setup_autocmds()

  -- Used to in two scenarios:
  --   1. When the editor is opened with multiple windows/splits
  --   2. When the plugin is explicitly enabled
  vim.schedule(tint_unfocused_windows)
end

--- Setup user configuration, highlight namespaces, and autocommands
---
--- Triggered by:
---   `:h VimEnter`
---
---@param _ table arguments from the associated `:h nvim_create_autocmd` setup
__.setup_callback = function(_)
  __.setup_all(false)
end

--- Enable this plugin
---
---@public
tint.enable = function()
  if __.enabled or not __.user_config then
    return
  end

  __.enabled = true

  -- Reconfigure autocommands, setup highlight namespaces, etc.
  --
  -- Skip user config setup as this has already happened
  __.setup_all(true)
end

--- Disable this plugin
---
---@public
tint.disable = function()
  if not __.enabled or not __.user_config then
    return
  end

  -- Disable autocommands
  create_augroup()
  __.setup_autocmds = false

  restore_default_highlight_namespaces()

  __.enabled = false
end

--- Toggle the plugin being enabled and/or disabled
---
---@public
tint.toggle = function()
  if __.enabled then
    tint.disable()
  else
    tint.enable()
  end
end

--- Setup the plugin - can be called infinite times but will only do setup once
---
---@public
---@param user_config TintUserConfiguration see `:h tint-setup`
tint.setup = function(user_config)
  if not verify_version() then
    return
  end

  if __.user_config then
    return
  end

  __.user_config = user_config

  on_or_after_vimenter(__.setup_callback)
end

--- Refresh highlight namespaces, to be used after new highlight groups are added that need to be tinted
---
---@public
tint.refresh = function()
  if not __.user_config then
    return
  end

  setup_namespaces()
end

--- Tint the specified window
---
---@public
---@param winid number a valid window handle
tint.tint = function(winid)
  if not __.user_config or not vim.api.nvim_win_is_valid(winid) then
    return
  end

  set_window_hl_ns(winid, get_tint_ns_id(winid))
end

--- Untint the specified window
---
---@public
---@param winid number a valid window handle
tint.untint = function(winid)
  if not __.user_config or not vim.api.nvim_win_is_valid(winid) then
    return
  end

  set_window_hl_ns(winid, get_untint_ns_id(winid))
  vim.api.nvim_win_del_var(winid, "untint_ns_id")
end

return tint
