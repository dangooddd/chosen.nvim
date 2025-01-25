# chosen.nvim
Quickly move between your chosen files, per-project.

https://github.com/user-attachments/assets/c50ec361-40d2-4a2b-b1c0-b7125b3d2136

- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Options](#options)
- [Usage](#usage)
- [Alternatives](#alternatives)

## Requirements

- Neovim 0.8+

## Installation

Install with your favourite plugin manager.

Example for [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "dangooddd/chosen.nvim",
    ---@type chosen.SetupOpts
    opts = {},
}
```

## Quick Start

After installation, paste somewhere in your config:

```lua
require("chosen").setup()
```

Then add binding to open Chosen window, for example:
```lua
vim.keymap.set("n", "<Enter>", require("chosen").toggle)
```

Alternatively, you can use ":Chosen" command in cmdline.

Full example for lazy:

```lua
-- plugins/chosen.lua
return {
    "dangooddd/chosen.nvim",
    keys = { "<Enter>" },
    cmd = "Chosen"
    config = function()
        require("chosen").setup()
        vim.keymap.set("n", "<Enter>", require("chosen").toggle)
    end,
}
```

## Options

Config below is used by default, you do not need to pass it to setup:

```lua
require("chosen").setup({
    -- Path where Chosen will store its data
    store_path = vim.fn.stdpath("data") .. "/chosen",
    -- Keys that will be used to manipulate Chosen files
    keys = "123456789zxcbnmZXVBNMafghjklAFGHJKLwrtyuiopWRTYUIOP",
    -- Disables autowrite of chosen index on VimLeavePre
    autowrite = true,
    -- Chosen ui options
    ui_options = {
        max_height = 10,
        min_height = 1,
        max_width = 40,
        min_width = 10,
        border = "rounded",
        title = " Chosen ",
        title_pos = "center",
    },
    -- Window local options to use in Chosen buffers
    win_options = {
        winhl = "NormalFloat:Normal,FloatBorder:Normal,FloatTitle:Title",
    },
    -- Buffer local options to use in Chosen buffers
    buf_options = {
        filetype = "chosen",
    },
    -- Mappings in Chosen buffers
    keymap = {
        -- Reset mode or exit
        revert = "<Esc>",
        -- Save current file
        save = "c",
        -- Toggle delete mode
        delete = "d",
        -- Toggle swap mode
        swap = "s",
    },
})
```

You can also define Hightlight groups to modify Chosen ui:

- ChosenIndex - default index hl
- ChosenDelete - index hl in delete mode
- ChosenSwap - index hl in swap mode

## Usage

After installation and quick start, you will be able to toggle chosen window.

In chosen buffer you have only 4 actions:
- Save current buffer to Chosen index (c by default)
- Toggle delete mode (d by default)
- Toggle swap mode (s by default)
- Pick file with one key from config.keys

In delete mode, key press will delete file from the list.

In swap mode, you need to press two keys. After that, files will be swapped.

If none of modes is active, key press will open file.

### Chosen data file (index)

Chosen stores its data in format of lua table that called index.
By default, this plugin will load this file on setup and save it on VimLeavePre event.

To disable autowrite:

```lua
require("chosen").setup({ autowrite = false })
```

Also you can manage index load and save by yourself:

```lua
local chosen = require("chosen")
chosen.index = chosen.load_index()
chosen.dump_index()
```

## Alternatives

- [mini.visits](https://github.com/echasnovski/mini.visits) - inspiration for index data file
- [arrow](https://github.com/otavioschwanck/arrow.nvim.git) - inspiration for ui
- [snipe](https://github.com/leath-dub/snipe.nvim) - general purpose targetted menu
- [harpoon](https://github.com/ThePrimeagen/harpoon/tree/harpoon2) - most popular alternative
