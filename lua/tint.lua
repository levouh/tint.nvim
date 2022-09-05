local tint = {
  config = {
    amt = -40,
    saturation = 0.7,
    bg = false,
    ignore = {},
    ignorefunc = nil,
  },
}

local __ = {}

local function get_hex(val)
  -- Convert decimal to hex
  return string.format("%06x", val)
end

local function clamp(component)
  return math.min(math.max(component, 0), 255)
end

---@param col string The hex color to transform.
---@param amt integer The amount to amplify each color component (can be both negative and positive).
---@param saturation integer The amount of saturation to preserve, in the range of [0.0, 1.0].
local function transform_color(col, amt, saturation)
  if string.find(col, "^#") then
    col = string.sub(col, 2)
  end

  local num = tonumber(col, 16)
  local r = math.floor(num / 0x10000)
  local g = (math.floor(num / 0x100) % 0x100)
  local b = (num % 0x100)
  if saturation ~= 1 then
    local rec601_luma = 0.299 * r + 0.587 * g + 0.114 * b
    r = math.floor(r * saturation + rec601_luma * (1 - saturation))
    g = math.floor(g * saturation + rec601_luma * (1 - saturation))
    b = math.floor(b * saturation + rec601_luma * (1 - saturation))
  end

  return string.format("#%06x", clamp(r + amt) * 0x10000 + clamp(g + amt) * 0x100 + clamp(b + amt))
end

local function get_def(v)
  -- Some keys in `v` are not valid - pass only valid ones here
  return {
    fg = v.fg or v.foreground,
    bg = v.bg or v.background,
    sp = v.sp or v.special,
    blend = v.blend,
    bold = v.bold,
    standout = v.standout,
    underline = v.underline,
    undercurl = v.undercurl,
    underdouble = v.underdouble,
    underdotted = v.underdotted,
    underdashed = v.underdashed,
    strikethrough = v.strikethrough,
    italic = v.italic,
    reverse = v.reverse,
    nocombine = v.nocombine,
    link = v.link,
    default = v.default,
    ctermfg = v.ctermfg,
    ctermbg = v.ctermbg,
    cterm = v.cterm,
  }
end

local function ignore_tint(winid)
  return tint.config.ignorefunc and tint.config.ignorefunc(winid) or false
end

local function ignored(k)
  for _, pat in ipairs(tint.config.ignore) do
    if string.find(k, pat) then
      return true
    end
  end

  return false
end

local function set_default_ns(k, def)
  vim.api.nvim_set_hl(__.default_ns, k, def)
end

local function set_tint_ns(k, def)
  if def.fg and not ignored(k) then
    def.fg = transform_color(get_hex(def.fg), tint.config.amt, tint.config.saturation)
  end

  if tint.config.bg and def.bg and not ignored(k) then
    def.bg = transform_color(get_hex(def.bg), tint.config.amt, tint.config.saturation)
  end

  vim.api.nvim_set_hl(__.tint_ns, k, def)
end

local function setup_namespaces()
  if not __.default_ns and not __.tint_ns then
    __.default_ns = vim.api.nvim_create_namespace("_tint_norm")
    __.tint_ns = vim.api.nvim_create_namespace("_tint_dim")
  end

  local defs = vim.api.nvim__get_hl_defs(0)
  for k, _ in pairs(defs) do
    -- Seems we cannot always ask for `rgb` values from `nvim__get_hl_defs`
    local v = vim.api.nvim_get_hl_by_name(k, true)

    -- Ensure we only have valid keys copied over
    local def = get_def(v)

    set_default_ns(k, def)
    set_tint_ns(k, def)
  end
end

local function setup_autocmds()
  if __.setup_autocmds then
    return
  end

  local augroup = vim.api.nvim_create_augroup("_tint", { clear = true })

  vim.api.nvim_create_autocmd({ "WinEnter" }, {
    group = augroup,
    pattern = { "*" },
    callback = __.on_focus,
  })

  vim.api.nvim_create_autocmd({ "WinLeave" }, {
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

__.on_focus = function()
  local winid = vim.api.nvim_get_current_win()
  if ignore_tint(winid) then
    return
  end

  vim.api.nvim_win_set_hl_ns(winid, __.default_ns)
end

__.on_unfocus = function()
  local winid = vim.api.nvim_get_current_win()
  if ignore_tint(winid) then
    return
  end

  vim.api.nvim_win_set_hl_ns(winid, __.tint_ns)
end

__.on_colorscheme = function()
  __.setup_all()
end

__.setup_all = function()
  setup_namespaces()
  setup_autocmds()
end

tint.setup = function(user_config)
  if not verify_version() then
    return
  end

  if __.setup_module then
    return
  end

  user_config = user_config or {}
  tint.config = vim.tbl_extend("force", tint.config, user_config)

  __.setup_module = true
  __.setup_all()
end

return tint
