# :eyeglasses: tint.nvim

Dim inactive windows in Neovim using window-local highlight namespaces.

## :construction: Important

This is still a work in progress, create an issue if you find any.

This feature was added via [!13457](https://github.com/neovim/neovim/pull/13457). Your version of Neovim must
include this change in order for this to work.

## :clapper: Demo

![tint](https://user-images.githubusercontent.com/31262046/188242698-3588074d-176b-4926-834f-ab9cf6302cd2.gif)

## :grey_question: About

Using [window-local highlight namespaces](https://github.com/neovim/neovim/pull/13457), this plugin will iterate
over your current colorscheme and either brighten or dim your current colorscheme (based on what you configure)
for inactive windows.

## :electric_plug: Setup

See a description of all options in [Options](#options).

```lua
-- Default configuration
require("tint").setup()

-- Override defaults
require("tint").setup({
  bg = true,  -- Dim background highlights
  amt = -40,  -- Dim by value, brighten would just be 40
  ignore = { "WinSeparator", "Status.*" },  -- Highlight group patterns to ignore
  ignorefunc = function(winid)
    local buf = vim.api.nvim_win_get_buf(winid)
    local buftype vim.api.nvim_buf_get_option(buf, "buftype")

    if buftype == "terminal" then
      -- Ignore `terminal`-type buffers
      return true
    end

    -- Dim everything else
    return true
  end
})
```

## :gear: Options

| Option | Default | Description                                                                                |
|--------|---------|--------------------------------------------------------------------------------------------|
| bg     | false   | Whether or not to dim highlights for background portions of highlight groups.              |
| amt    | -40     | Amount to change current colorscheme. Negative values dim, positive values brighten.       |
| ignore | {}      | A list of patterns (supplied to `string.find`) for highlight groups to ignore dimming for. |
| ignorefunc | nil | A function that will be called for each window to discern whether or not it should be dimmed. Arguments are are `(winid)`. |
