1. [Setup](#setup)
2. [Options](#options)

## Setup

`require` the `tint` module, and pass the options you want to alter to the `setup` function.

```lua
-- Default configuration
require("tint").setup()

-- Override defaults
require("tint").setup({
  tint = -45,  -- Darken colors, use a positive value to brighten
  saturation = 0.6,  -- Saturation to preserve
  tint_background_colors = true,  -- Tint background portions of highlight groups
  highlight_ignore_patterns = { "WinSeparator", "Status.*" },  -- Highlight group patterns to ignore, see `string.find`
  window_ignore_function = function(winid)
    local buf = vim.api.nvim_win_get_buf(winid)
    local buftype vim.api.nvim_buf_get_option(buf, "buftype")

    if buftype == "terminal" then
      -- Do not tint `terminal`-type buffers
      return true
    end

    -- Tint the window
    return false
  end
})
```

## Options

### **tint**
*type*: `number`
*default*: `-40`

Amount to change current colorscheme. Negative values darken, positive values brighten.

### **saturation**
*type*: `float`
*default*: `0.7`

The amount of saturation to preserve, in the range of `[0.0, 1.0]`.

### **highlight_ignore_patterns**
*type*: `table[string]`
*default*: `{}`

A list of patterns (supplied to `string.find`) for highlight group names to ignore tinting for.

### **window_ignore_function**
*type*: `function`
*default*: `nil`

A function that will be called for each window to discern whether or not it should be tinted. Arguments are are `(winid)`, return `false` or `nil` to tint a window, anything else to not tint it.

### **tint_background_colors**
*type*: `boolean`
*default*: `false`

Whether or not to tint background portions of highlight groups.

