# :eyeglasses: tint.nvim

Tint inactive windows in Neovim using window-local highlight namespaces.

## :warning: Caveats

- This feature was added via [!13457](https://github.com/neovim/neovim/pull/13457). Your version of Neovim must include this change in order for this to work.
- If you are noticing that certain colors are not being tinted, it is because likely they are defined _after_ `tint` has been loaded and are "standalone" (i.e. not `link`).
  - `tint` applies changes to your colorscheme (i.e. the global highlight namespace with `ns_id=0`) _when its `setup` function is called_. From this then, if you are lazy-loading a different plugin that declares its own standalone highlight groups and loads after `tint`, they will likely not work as intended.
  - To help work around this (perhaps until a better solution is found), you can use `require("tint").refresh()` after a plugin loads if you are having issues with its colors.

## :clapper: Demo

![tint](https://user-images.githubusercontent.com/31262046/188242698-3588074d-176b-4926-834f-ab9cf6302cd2.gif)

## :grey_question: About

Using [window-local highlight namespaces](https://github.com/neovim/neovim/pull/13457), this plugin will iterate
over each highlight group in the active colorscheme when the plugin is setup and either brighten or darken each
value (based on what you configure) for inactive windows.

## :gear: Setup

See [docs](DOC.md) or `:h tint` for more details.

```lua
-- Default configuration
require("tint").setup()
```

Or if you want to override the defaults:

```lua
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

### Custom color transformations

See `:h tint-transforms_api` for more details.

If you come up with a cool set of transformations that you think might be useful to others, see the [contributing guide](CONTRIBUTING.md) on how you can make this available for others.

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

### Bounding colors to some threshold

See `:h tint-transforms-tint_with_threshold` for more details.

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

## :desktop_computer: API

See [docs](DOC.md) or `:h tint` for more details.

## :heart: Acknowledgements

- The harder part of the plugin to dim colors from [StackOverflow](https://stackoverflow.com/questions/72424838/programmatically-lighten-or-darken-a-hex-color-in-lua-nvim-highlight-colors)
- The general idea from [Shade.nvim](https://github.com/sunjon/Shade.nvim)
- `bfredl` for making everyones life better
- `williamboman` for adding saturation to better mimic the way `Shade` looks
