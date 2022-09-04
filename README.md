# :eyeglasses: tint.nvim

Tint inactive windows in Neovim using window-local highlight namespaces.

## :construction: Important

This is still a work in progress, create an issue if you find any.

This feature was added via [!13457](https://github.com/neovim/neovim/pull/13457). Your version of Neovim must
include this change in order for this to work.

## :clapper: Demo

![tint](https://user-images.githubusercontent.com/31262046/188242698-3588074d-176b-4926-834f-ab9cf6302cd2.gif)

## :grey_question: About

Using [window-local highlight namespaces](https://github.com/neovim/neovim/pull/13457), this plugin will iterate
over each highlight group in the active colorscheme when the plugin is setup and either brighten or darken each
value (based on what you configure) for inactive windows.

The plugin is responsive to changes in colorscheme via `:h ColorScheme`.

## :electric_plug: Setup

See [docs](DOC.md) for more details.

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

## :gear: Options

See [docs](DOC.md), or read `:h tint`.

## :heart: Acknowledgements

- The harder part of the plugin to dim colors from [StackOverflow](https://stackoverflow.com/questions/72424838/programmatically-lighten-or-darken-a-hex-color-in-lua-nvim-highlight-colors)
- The general idea from [Shade.nvim](https://github.com/sunjon/Shade.nvim)
- `bfredl` for making everyones life easier
