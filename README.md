# chosen.nvim

Quickly move between your chosen files, per-project.

https://github.com/user-attachments/assets/58c5168e-ea43-4f11-9abc-8b7b94091009

- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Config](#config)
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
    dependencies = { "nvim-tree/nvim-web-devicons" }, -- optional
    -- dependencies = { "echasnovski/mini.icons" }
    keys = { "<Enter>" },
    cmd = "Chosen"
    config = function()
        require("chosen").setup()
        vim.keymap.set("n", "<Enter>", require("chosen").toggle)
    end,
}
```

## Config

Config below is used by default, you do not need to pass it to setup:

```lua
require("chosen").setup({
    -- Path where Chosen will store its data
    store_path = vim.fn.stdpath("data") .. "/chosen",
    -- Keys that will be used to manipulate Chosen files
    keys = "123456789zxcbnmZXVBNMafghjklAFGHJKLwrtyuiopWRTYUIOP",
    -- Autowrite of chosen index on VimLeavePre event
    autowrite = true,
    -- Change behaviour of hjkl keys in Chosen buffers
    -- h and l -- horizontal scroll
    -- j and k -- PageUp / PageDown
    bind_hjkl = true,
    -- Close window on save / delete of current file action
    close_on_save = false,
    -- Close window on write action
    close_on_write = true,
    -- Send notification on write action
    notify_on_write = true,
    -- Chosen ui options
    ui_options = {
        max_height = 10,
        min_height = 1,
        max_width = 40,
        min_width = 10,
        border = "rounded",
        title = " Chosen ",
        title_pos = "center",
        show_icons = true,
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
        -- Save / delete current file
        save = "c",
        -- Toggle delete mode
        delete = "d",
        -- Toggle swap mode
        swap = "s",
        -- Toggle split mode
        split = "<C-s>",
        -- Toggle vsplit mode
        vsplit = "<C-v>",
        -- Write Chosen index file on filesystem
        write = "w",
    },
})
```

## Alternatives

- [mini.visits](https://github.com/echasnovski/mini.visits)
- [arrow](https://github.com/otavioschwanck/arrow.nvim.git)
- [snipe](https://github.com/leath-dub/snipe.nvim)
- [harpoon](https://github.com/ThePrimeagen/harpoon/tree/harpoon2)
