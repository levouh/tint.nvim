# Content

1. [Setup](#setup)
2. [Options](#options)
3. [Transforms API](#transforms-api)
4. [Colors API](#colors-api)
5. [Plugin API](#plugin-api)

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
```

Custom transformations can also be setup. Make sure to create a PR if you end up making one that you think others may enjoy as well.
See `CONTRIBUTING.md` for more details on how to add transforms.

```lua
-- Handle transformations of highlight groups for the tinted namespace yourself
require("tint").setup({
  transforms = {
    require("tint.transforms").saturate(0.5),
    function(r, g, b, hl_group_info)
      print("Higlight group name: " .. hl_group_info.hl_group_name)

      local hl_def = vim.api.nvim_get_hl_by_name(hl_group_info.hl_group_name)
      print("Highlight group definition: " .. vim.inspect(hl_def))

      return r + 1, g + 1, b + 1
    end
  }
})
```

Your colorscheme might have colors that are slightly different from your default editor background, and those that are much further away. You want the colors that are further away tinted
more, and those that are closer tinted less. In order to achieve this, you can set some arbitrary "tint bounding color" and keep all tinted colors some threshold away from it.

Setting this to the `background` portion of your `Normal` highlight group is usually the easiest way to go.

```lua
require("tint").setup({
  transforms = {
    require("tint.transforms").tint_with_threshold(-100, "#1C1C1C", 150),  -- Try to tint by `-100`, but keep all colors at least `150` away from `#1C1C1C`
    require("tint.transforms").saturate(0.5),
  }
})
```

## Options

All configuration values are optional. If no value is provided, the default will be used.

### **option-tint**
*type*: `number`
*default*: `-40`

Amount to change current colorscheme. Negative values darken, positive values brighten.

### **option-saturation**
*type*: `float`
*default*: `0.7`

The amount of saturation to preserve, in the range of `[0.0, 1.0]`.

### **option-transforms**
*type*: `table|string`
*default*: `tint.transforms.SATURATE_TINT`

A predefined set of transforms as a `string`, can be one of:

- `require("tint").transforms.SATURATE_TINT`: Saturate and tint using `saturation` and `tint` config values

Or table of functions that each accept the following arguments:

- `r`: `number` The red component of the highlight group in question
- `g`: `number` The green component of the highlight group in question
- `b`: `number` The blue component of the highlight group in question
- `hl_group_info`: `table` Information about the highlight group being tinted, including:
  - `hl_group_name`: `string` The name of the highlight group being altered

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

### **option-highlight_ignore_patterns**
*type*: `table[string]`
*default*: `{}`

A list of patterns (supplied to `string.find`) for highlight group names to ignore tinting for.

### **option-window_ignore_function**
*type*: `function`
*default*: `nil`

A function that will be called for each window to discern whether or not it should be tinted. Arguments are `(winid)`, return `false` or `nil` to tint a window, anything else to not tint it.

### **option-tint_background_colors**
*type*: `boolean`
*default*: `false`

Whether or not to tint background portions of highlight groups.

## Transforms API

Each of the below functions is meant to be used as an entry in the `transforms` key passed in the table to `setup`, like so:

```lua
require("tint").setup({
  transforms = {
    -- transform function here
  }
})
```

Custom functions can also be passed to this table, but must meet the following criteria:

1. Must take the following parameters:
  - `param` `r`: A red value between `0` and `255`
  - `param` `g`: A green value between `0` and `255`
  - `param` `b`: A blue value between `0` and `255`
  - `param` `hl_group_info`: Information about the highlight group being modified, use `print(vim.inspect(hl_group_info))` for more information
2. Must return the following:
  - `return`: The same `r`, `g`, and `b` values modified as needed

For example:

```lua
require("tint").setup({
  transforms = {
    function(r, g, b, hl_group_info)
      print(vim.inspect(hl_group_info))
      return r + 1, g + 1, b + 1
    end
  }
})
```

Along with supporting custom functions, there are a number of builtin functions that can also be used.

### **transforms-saturate**

Returns a function that takes and returns `r`, `g` and `b` values with the passed value of saturation maintained.

- `param` `amt`: The amount of saturation to maintain, betwen `0.0` and `1.0`

```lua
require("tint.transforms").saturate(0.5)
```

The main intention here is to use this with the `transforms` key in `setup`, like:

```lua
require("tint").setup({
  transforms = {
    require("tint.transforms").saturate(0.5),
  },
})
```

### **transforms-tint**

Return a function that takes and returns `r`, `g` and `b` values with the passed `tint` value applied. Positive values
will lighten a color, negative values will darken it.

- `param` `amt`: The amount to tint the passed color. Positive values lighten, negative values darken.

```lua
require("tint.transforms").tint(-40)
```

The main intention here is to use this with the `transforms` key in `setup`, like:

```lua
require("tint").setup({
  transforms = {
    require("tint.transforms").tint(-40),
  },
})
```

### **transforms-tint_with_threshold**

Return a function that takes and returns `r`, `g` and `b` values with the passed `tint` value applied, kept within some
threshold of the passed value to compare to.

- `param` `amt`: The amount to tint the passed color. Positive values lighten, negative values darken.
- `param` `base`: The color to not go within threshold of, formatted as a 6-digit hexidecimal with a leading `#`
- `param` `threshold`: The threshold to stay away from the passed `base` hex color

```lua
-- Tint by -100, keep 150 away from #1C1C1C
require("tint.transforms").tint_with_threshold(-100, "#1C1C1C", 150)
```

The main intention here is to use this with the `transforms` key in `setup`, like:

```lua
require("tint").setup({
  transforms = {
    require("tint.transforms").tint_with_threshold(-100, "#1C1C1C", 150),
  },
})
```

## Colors API

### **colors-get_hex**

Translate a base 10 decimal to its base 16 value, limited to 6 characters.

- `param` `val`: The base 10 `number` value to convert
- `return`: The hex string for the passed number, no leading `#`

```lua
require("tint.colors").get_hex(1842204)  -- 1C1C1C
```

### **colors-clamp**

Bound a value between `0` and `255`.

- `param` `val`: The number to clamp between `0` and `255`
- `return`: The value clamped to between `0` and `255`

```lua
require("tint.colors").clamp(256)  -- 255
```

### **colors-rgb_to_hex**

Transform `r`, `g`, and `b` values to a hexidecimal color value, suitable for declaring a color definition.

- `param` `r`: The red value of an RGB color
- `param` `g`: The green value of an RGB color
- `param` `b`: The blue value of an RGB color
- `return`: The RGB value as a hex string with a leading `#`

```lua
require("tint.colors").rgb_to_hex(28, 28, 28)  -- #1C1C1C
```

### **colors-hex_to_rgb**

Transform the passed hexidecimal color string to `r`, `g`, and `b` values.

- `param` `hex`: A hex string, either with a leading `#` or not
- `return`: A tuple of `r`, `g` and `b` values for the passed hex value

```lua
require("tint.colors").rgb_to_hex("#1C1C1C")  -- 28, 28, 28
```

## Plugin API

### **plugin-enable**

Function that can be called to enable the plugin after it has been previously disabled.

For example:

```lua
require("tint").enable()
```

### **plugin-disable**

Function that can be called to disable the plugin entirely. After this is called, each window has the default global namespace (`ns_id=0`) restored to it.

For example:

```lua
require("tint").disable()
```

### **plugin-refresh**

If you are noticing that certain colors are not being tinted, it is likely because you have not explicitly defined them anywhere within your own colorscheme.
`tint` applies changes to your colorscheme (i.e. the global highlight namespace with `ns_id=0`) _when its `setup` function is called_.
From this then, if you are e.g. lazy-loading a plugin that declares its own highlight groups (that are not links to other highlight groups), they will not be highlighted.

For example:

```lua
-- After some new plugin was added that defines its own colors
require("tint").refresh()
```
