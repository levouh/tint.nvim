1. [Setup](#setup)
2. [Options](#options)

## Setup

`require` the `tint` module, and pass the options you want to alter to the `setup` function.

```lua
-- Default configuration
require("tint").setup()

-- Override some defaults
require("tint").setup({
  tint = -45,  -- Darken colors, use a positive value to brighten
  saturation = 0.6,  -- Saturation to preserve
  transforms = require("tint").transforms.SATURATE_TINT,  -- Showing default behavior, but value here can be predefined set of transforms
  tint_background_colors = true,  -- Tint background portions of highlight groups
  highlight_ignore_patterns = { "WinSeparator", "Status.*" },  -- Highlight group patterns to ignore, see `string.find`
  window_ignore_function = function(winid)
    local bufid = vim.api.nvim_win_get_buf(winid)
    local buftype = vim.api.nvim_buf_get_option(bufid, "buftype")
    local floating = vim.api.nvim_win_get_config(winid).relative ~= ""

    -- Do not tint `terminal` or floating windows, tint everything else
    return buftype == "terminal" or floating
  end
})

-- Handle transformations of highlight groups for the tinted namespace yourself
require("tint").setup({
  transforms = {
    require("tint.colors").saturate(0.5),
    function(r, g, b, hl_group_info)
      print("Higlight group name: " .. hl_group_info.hl_group_name)

      local hl_def = vim.api.nvim_get_hl_by_name(hl_group_info.hl_group_name)
      print("Highlight group definition: " .. vim.inspect(hl_def))

      return r + 1, g + 1, b + 1
    end
  }
})
```

## Options

All configuration values are optional. If no value is provided, the default will be used.

### **tint**
*type*: `number`
*default*: `-40`

Amount to change current colorscheme. Negative values darken, positive values brighten.

### **saturation**
*type*: `float`
*default*: `0.7`

The amount of saturation to preserve, in the range of `[0.0, 1.0]`.

### **transforms**
*type*: `table|string`
*default*: `tint.transforms.SATURATE_TINT`

A predefined set of transforms as a `string`, can be one of:

`require("tint").transforms.SATURATE_TINT`: Saturate and tint using `saturation` and `tint` config values

Or table of functions that each accept the following arguments:

`r`: `number` The red component of the highlight group in question
`g`: `number` The green component of the highlight group in question
`b`: `number` The blue component of the highlight group in question
`hl_group_info`: `table` Information about the highlight group being tinted, including:
  `hl_group_name`: `string` The name of the highlight group being altered

and each return the `r`, `g` and `b` values modified as needed.

For example:

```lua
require("tint").setup({
  transforms = {
    function(r, g, b, hl_group_info)
      print("Higlight group name: " .. hl_group_info.hl_group_name)

      local hl_def = vim.api.nvim_get_hl_by_name(hl_group_info.hl_group_name)
      print("Highlight group definition: " .. vim.inspect(hl_def))

      return r + 1, g + 1, b + 1
    end
  }
})
```

If you end up finding cool combinations, feel free to submit them to be used by others.

### **highlight_ignore_patterns**
*type*: `table[string]`
*default*: `{}`

A list of patterns (supplied to `string.find`) for highlight group names to ignore tinting for.

### **window_ignore_function**
*type*: `function`
*default*: `nil`

A function that will be called for each window to discern whether or not it should be tinted. Arguments are `(winid)`, return `false` or `nil` to tint a window, anything else to not tint it.

### **tint_background_colors**
*type*: `boolean`
*default*: `false`

Whether or not to tint background portions of highlight groups.

