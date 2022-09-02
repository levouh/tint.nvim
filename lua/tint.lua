local tint = {
  config = {
    amt = -40,
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

local function lighten_darken_color(col, amt)
  if string.find(col, "^#") then
    col = string.sub(col, 2)
  end

  local num = tonumber(col, 16)
  local r = math.floor(num / 0x10000) + amt
  local g = (math.floor(num / 0x100) % 0x100) + amt
  local b = (num % 0x100) + amt

  return string.format("#%06x", clamp(r) * 0x10000 + clamp(g) * 0x100 + clamp(b))
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
    def.fg = lighten_darken_color(get_hex(def.fg), tint.config.amt)
  end

  if tint.config.bg and def.bg and not ignored(k) then
    def.bg = lighten_darken_color(get_hex(def.bg), tint.config.amt)
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

__.on_focus = function()
  vim.api.nvim_win_set_hl_ns(vim.api.nvim_get_current_win(), __.default_ns)
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
  user_config = user_config or {}
  vim.tbl_extend("force", tint.config, user_config)

  if __.setup_module then
    return
  end

  __.setup_module = true
  __.setup_all()
end

return tint
