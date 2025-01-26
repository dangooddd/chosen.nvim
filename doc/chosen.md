# Introduction

Chosen is a simple plugin to manage list of important files.

This list is saved on filesystem, so it is persistent between
different editing sessions.

# Configuration

Default configuration options:

```lua
require("chosen").setup({
    -- Path where Chosen will store its data
    store_path = vim.fn.stdpath("data") .. "/chosen",
    -- Keys that will be used to manipulate Chosen files
    keys = "123456789zxcbnmZXVBNMafghjklAFGHJKLwrtyuiopWRTYUIOP",
    -- Autowrite of chosen index on VimLeavePre event
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
        -- Save current file
        save = "c",
        -- Toggle delete mode
        delete = "d",
        -- Toggle swap mode
        swap = "s",
        -- Toggle split mode
        split = "<C-s>",
        -- Toggle vsplit mode
        vsplit = "<C-v>",
    },
})
```

Configuration options should be intuitive enough to understand withoud further explanation.

# Usage

Chosen aims to be very intuitive, so after setup simply call:

```
:Chosen
```

In this window you can use specified in config mappings to toggle different modes.
Try it yourself!

You can also open window with using lua:

```lua
require("chosen").toggle()
```

# Api

Chosen uses index table to make its lists persistent.
This file uses following structure:

```lua
{
    ["/path/to/dir"] = { "/path/to/file1", "/path/to/file2" },
}
```

You have few options to manage this file manually.

To manually load index:

```lua
-- require("chosen").config.store_path if nil passed to store_path
require("chosen").index = require("chosen").load_index(store_path)
```

To manually dump index:

```lua
-- require("chosen").config.store_path if nil passed to store_path
-- require("chosen").index if nil passed to index
require("chosen").dump_index(store_path, index)
```

# Hightlights

| Group             | Default                          | Description
| ----------------- | -------------------------------- | -----------------------------
| ChosenKey         | `{ link = "DiagnosticInfo"}`     | Key in default mode 
| ChosenDelete      | `{ link = "DiagnosticError" }`   | Key in delete mode
| ChosenSwap        | `{ link = "DiagnosticWarning" }` | Key in swap mode
| ChosenSplit       | `{ link = "Special" }`           | Key in split and vsplit modes
| ChosenPlaceholder | `{ link = "DiagnosticHint" }`    | Placeholder on empty buffer    

# Tips

To disable autowrite in runtime:

```lua
:lua require("chosen").setup({ autowrite = false })
```

To make Chosen use default floating window hightlights:

```lua
require("chosen").setup({
    win_options = {
        winhl = "",
    },
})
```
