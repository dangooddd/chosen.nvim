# chosen.nvim
Quickly move between your chosen files, per project

https://github.com/user-attachments/assets/c50ec361-40d2-4a2b-b1c0-b7125b3d2136

- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Options](#options)
- [Usage](#usage)

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

Full example for lazy:

```lua
-- plugins/chosen.lua
return {
    "dangooddd/chosen.nvim",
    keys = { "<Enter>" },
    config = function()
        require("chosen").setup()
        vim.keymap.set("n", "<Enter>", require("chosen").toggle)
    end,
}
```

## Options

Config below is used by default, you do not need to pass it to setup:

```lua
local default_config = {
    -- Path where Chosen will store its data
    store_path = vim.fn.stdpath("data") .. "/chosen",
    -- Keys that will be used to manipulate Chosen files
    index_keys = "123456789zxcbnmZXVBNMafghjklAFGHJKLwrtyuiopWRTYUIOP",
    -- Disables autowrite of chosen index on VimLeavePre
    -- Alternatively, you can toggle this with vim.g.chosen_disable_autorwrite
    disable_autowrite = false,
    -- Window specific options
    -- Some will be passed in vim.api.nvim_open_win
    float = {
        max_height = 10,
        min_height = 1,
        max_width = 20,
        min_width = 10,
        border = "rounded",
        title = " Chosen ",
        title_pos = "center",
        -- Options to pass to vim.wo
        win_options = {
            -- Equivalent to set vim.wo.winhl
            winhl = "NormalFloat:Normal,FloatBorder:Normal,FloatTitle:Title",
        },
    },
    -- Options to pass to vim.bo
    buf_options = {
        filetype = "chosen",
    },
    -- Mappings in Chosen buffer
    mappings = {
        -- Save current file
        save = "c",
        -- Toggle delete mode
        delete = "d",
        -- Toggle swap mode
        swap = "s",
    },
}
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
- Press key from index_keys variable in config

In delete mode, key press will delete file from the list. Thats is

In swap mode, you need to press two keys. After that, files will be swapped

If none of modes is active, key press will open file

### Chosen data file (index)

Chosen stores its data in format of lua table that called index

By default, this plugin will load this file on setup and save it on VimLeavePre event

To disable autowrite only for current session:

```lua
vim.g.chosen_disable_autorwrite = true
```

Also you can manage index load and save by yourself:

```lua
local chosen = require("chosen")
chosen.index = chosen.load_index()
chosen.dump_index()
```
