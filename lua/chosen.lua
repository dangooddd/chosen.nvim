local M = {} -- module
local H = {} -- hidden module
local uv = vim.uv or vim.loop

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
        max_width = 40,
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

---Utility function to set default table value
---@param tbl table
---@param val any
local tbl_default = function(tbl, val)
    setmetatable(tbl, { __index = function() return val end })
end

---Table where Chosen stores files
---Stores in following format
---[ ["cwd"] = { "file1", "file2" } ]
---@class chosen.Index
---@field [string] table<string> Index entry for given cwd
M.index = {}

---@param store_path string?
---@return chosen.Index
M.load_index = function(store_path)
    store_path = store_path or H.config.store_path
    if not uv.fs_stat(store_path) then return {} end

    -- load file as lua
    local ok, out = pcall(dofile, store_path)
    if not ok then return {} end -- empty table on first launch
    return out
end

---@param store_path string? Path where Chosen index table will be stored. If nil passed, use store path from config
---@param index chosen.Index? Chosen index to dump. If nil passed, use default
M.dump_index = function(store_path, index)
    store_path = store_path or H.config.store_path
    index = index or M.index

    local path_dir = vim.fs.dirname(store_path)
    -- ensure parent directory exist
    if not vim.fn.mkdir(path_dir, "p") then return nil end

    -- write file, which returns lua table with Chosen index
    local lines = vim.split(vim.inspect(index), "\n")
    lines[1] = "return " .. lines[1]
    vim.fn.writefile(lines, store_path)
end


---@class chosen.SetupOpts
---@field store_path? string File where Chosen data will be stored
---@field index_keys? string Indexes that will be shown in Chosen window
---@field disable_autowrite? boolean Disables autowriting on VimLeavePre event
---@field float? chosen.FloatOpts for vim.api.nvim_open_win function and other ui related settings
---@field mappings? chosen.Mappings Mappings in Chosen buffer

---@class chosen.FloatOpts
---@field min_width? integer Min width, integer value > 1
---@field min_height? integer Min height, integer value > 1
---@field max_width? integer
---@field max_height? integer
---@field border? "rounded"|"single"|"double" Border style to pass to vim.api.nvim_open_win
---@field title? string
---@field title_pos? "left"|"center"|"right"
---@field win_options? table<string, any> Options to pass to vim.wo

---@class chosen.Mappings
---@field save? string Mapping for adding current file to Chosen index
---@field delete? string Mapping for toggle delete mode. In delete mode any key from index_keys will delete file instead of open
---@field swap? string Mapping for toggle swap mode. In swap mode you need to type two keys to swap them

---@param opts chosen.SetupOpts?
M.setup = function(opts)
    H.config = vim.tbl_deep_extend("force", default_config, opts or {})
    -- those should be positive
    H.config.float.min_height = math.max(1, H.config.float.min_height)
    H.config.float.min_width = math.max(1, H.config.float.min_width)

    vim.g.chosen_disable_autowrite = H.config.disable_autowrite

    -- highlights
    vim.api.nvim_set_hl(0, "ChosenIndex", {
        link = "DiagnosticOk",
        default = true
    })

    vim.api.nvim_set_hl(0, "ChosenDelete", {
        link = "DiagnosticError",
        default = true
    })

    vim.api.nvim_set_hl(0, "ChosenSwap", {
        link = "DiagnosticWarn",
        default = true
    })

    -- autocmds
    vim.api.nvim_create_augroup("Chosen", { clear = false })

    -- dump index on leave of editor
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = "Chosen",
        once = true,
        callback = function()
            -- exit if disabled
            if vim.g.chosen_disable_autowrite then return end

            -- save with default values
            M.dump_index()
        end,
    })

    -- load index on setup
    M.index = M.load_index()
end

---Delete file from index entry for given cwd
---@param cwd string?
---@param fname string File name to delete
H.delete = function(cwd, fname)
    cwd = cwd or uv.cwd()
    if not M.index[cwd] then return end

    fname = vim.fn.fnamemodify(fname, ":p")

    for i, file in ipairs(M.index[cwd] or {}) do
        if file == fname then
            table.remove(M.index[cwd], i)
            break
        end
    end
end

---Swap two files in index entry for given cwd
---@param cwd string?
---@param lhs string First file path to swap
---@param rhs string Second file path to swap
H.swap = function(cwd, lhs, rhs)
    cwd = cwd or uv.cwd()
    if not M.index[cwd] then return end

    lhs = vim.fn.fnamemodify(lhs, ":p")
    rhs = vim.fn.fnamemodify(rhs, ":p")

    -- find indexes for swap files
    local li, ri = -1, -1
    for i, file in ipairs(M.index[cwd]) do
        if file == lhs then li = i end
        if file == rhs then ri = i end
    end

    -- swap only if all files was found
    if li ~= -1 and ri ~= -1 then
        M.index[cwd][li], M.index[cwd][ri] = M.index[cwd][ri], M.index[cwd][li]
    end
end

---Edit file with given name
---@param fname string
H.edit = function(fname)
    -- prefer relative path for edit command
    -- escape name for edit (if name contains spaces, for example)
    fname = vim.fn.fnamemodify(fname, ":.")
    fname = vim.fn.fnameescape(fname)
    pcall(vim.cmd.edit, fname)
end

---Save file to index entry for given cwd
---@param cwd string?
---@param fname string
H.save = function(cwd, fname)
    cwd = cwd or uv.cwd()
    if not cwd then return end              -- ensure that cwd is not nil

    fname = vim.fn.fnamemodify(fname, ":p") -- use only absolute path to prevent issues
    M.index[cwd] = M.index[cwd] or {}       -- ensure that index entry exist

    -- insert if not duplicate
    if not vim.tbl_contains(M.index[cwd], fname) then
        table.insert(M.index[cwd], fname)
    end
end

---Callbacks to call on mappings
---@type table<string, table>
H.callbacks = {
    -- actions on mode keys like delete|swap|save
    buf = {
        ---Clear swap|delete mode or close window
        ---@param buf chosen.Buf
        escape = function(buf)
            if vim.b[buf].chosen_mode == "" then
                pcall(vim.api.nvim_win_close, vim.fn.bufwinid(buf), false)
            else
                vim.b[buf].chosen_mode = ""
                H.render_highlights(buf)
            end
        end,

        ---Save current buffer and re-render window
        ---@param buf chosen.Buf
        save = function(buf)
            H.save(nil, vim.b[buf].chosen_fname)
            H.open_win(buf)
        end,

        ---Toggle delete mode
        ---@param buf chosen.Buf
        delete = function(buf)
            if vim.b[buf].chosen_mode == "delete" then
                vim.b[buf].chosen_mode = ""
            else
                vim.b[buf].chosen_mode = "delete"
            end
            H.render_highlights(buf)
        end,

        ---Toggle swap mode
        ---@param buf chosen.Buf
        swap = function(buf)
            if vim.b[buf].chosen_mode == "swapfirst" or
                vim.b[buf].chosen_mode == "swapsecond" then
                vim.b[buf].chosen_mode = ""
            else
                vim.b[buf].chosen_mode = "swapfirst"
            end
            H.render_highlights(buf)
        end,
    },

    -- actions on keypress
    -- different callbacks on differen modes
    mode = {
        ---Close window and edit selected file
        ---@param buf chosen.Buf
        ---@param fname string
        [""] = function(buf, fname)
            pcall(vim.api.nvim_win_close, vim.fn.bufwinid(buf), false)
            H.edit(fname)
        end,

        ---Delete file from list
        ---@param buf chosen.Buf
        ---@param fname string
        ["delete"] = function(buf, fname)
            H.delete(nil, fname)
            vim.b[buf].chosen_mode = ""

            -- re-render window because number of files is probably changed
            H.open_win(buf)
        end,

        ---Enter second stage of swapping
        ---@param buf chosen.Buf
        ---@param fname string
        ["swapfirst"] = function(buf, fname)
            vim.b[buf].chosen_swap = fname
            vim.b[buf].chosen_mode = "swapsecond"
        end,

        ---Swap files
        ---@param buf chosen.Buf
        ---@param fname string
        ["swapsecond"] = function(buf, fname)
            H.swap(nil, vim.b[buf].chosen_swap, fname)
            vim.b[buf].chosen_swap = nil
            vim.b[buf].chosen_mode = ""

            -- re-render only buffer
            H.render_buf(buf)
            H.render_highlights(buf)
        end,
    },
}

-- open file by default
tbl_default(H.callbacks.mode, H.callbacks.mode[""])

---@param buf chosen.Buf
H.render_highlights = function(buf)
    vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)

    ---@type integer
    vim.b[buf].chosen_height = vim.b[buf].chosen_height or 0 -- ensure value exist

    local mode_highlights = {
        ["delete"] = "ChosenDelete",
        ["swapfirst"] = "ChosenSwap",
        ["swapsecond"] = "ChosenSwap",
    }
    -- default hl
    tbl_default(mode_highlights, "ChosenIndex")

    local hl = mode_highlights[vim.b[buf].chosen_mode]

    -- set hl based on current Chosen mode
    for i = 0, vim.b[buf].chosen_height - 1 do
        vim.api.nvim_buf_add_highlight(buf, -1, hl, i, 0, 2)
    end

    -- set hl for message on empty buffer
    if vim.b[buf].chosen_height == 0 then
        vim.api.nvim_buf_add_highlight(buf, -1, hl, 0, 0, -1)
    end
end

---@param buf chosen.Buf?
H.render_buf = function(buf)
    ---@type chosen.Buf
    buf = buf or vim.api.nvim_get_current_buf()
    vim.bo[buf].modifiable = true -- by default chosen buffer is not modifiable
    vim.b[buf].chosen_width = 1   -- for width update on repeated rendering

    local cwd = uv.cwd()
    local keys = H.config.index_keys
    local lines = {}

    local keymap_opts = {
        buffer = buf,
        noremap = true,
        nowait = true
    }

    for i, fname in ipairs(M.index[cwd] or {}) do
        -- do not render more than index_keys can handle
        if i > #keys then break end

        local key = keys:sub(i, i)
        fname = vim.fn.fnamemodify(fname, ":~:.")
        lines[i] = string.format(" %s %s ", key, fname)

        -- calculate max width of a line
        vim.b[buf].chosen_width = math.max(vim.b[buf].chosen_width, #lines[i])

        -- keybinds
        vim.keymap.set("n", key, function()
            H.callbacks.mode[vim.b[buf].chosen_mode](buf, fname)
        end, keymap_opts)
    end

    vim.b[buf].chosen_height = #lines

    -- message if buffer is empty
    if #lines == 0 then
        lines[1] = string.format(" Press %s to save ", H.config.mappings.save)
        vim.b[buf].chosen_width = #lines[1]
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false -- reset modifiable
    H.render_highlights(buf)
end

---@param fname string?
---@return chosen.Buf
H.create_buf = function(fname)
    fname = fname or vim.fn.expand("%:p")
    local buf = vim.api.nvim_create_buf(false, true)

    vim.b[buf].chosen_fname = fname
    vim.b[buf].chosen_mode = ""
    vim.b[buf].chosen_height = 0
    vim.b[buf].chosen_width = 0
    vim.bo[buf].filetype = "chosen"

    -- set mappings
    local keymap_opts = {
        silent = true,
        buffer = buf,
        noremap = true,
        nowait = true
    }

    local mappings = H.config.mappings
    local callbacks = H.callbacks

    vim.keymap.set("n", "q", "<cmd>q<CR>", keymap_opts)

    vim.keymap.set("n", "<Esc>", function()
        callbacks.buf.escape(buf)
    end, keymap_opts)

    vim.keymap.set("n", mappings.swap, function()
        callbacks.buf.swap(buf)
    end, keymap_opts)

    vim.keymap.set("n", mappings.delete, function()
        callbacks.buf.delete(buf)
    end, keymap_opts)

    vim.keymap.set("n", mappings.save, function()
        callbacks.buf.save(buf)
    end, keymap_opts)

    -- auto close window when focus changes
    vim.api.nvim_create_autocmd("BufLeave", {
        group = "Chosen",
        buffer = buf,
        callback = function()
            pcall(vim.api.nvim_win_close, vim.fn.bufwinid(buf), false)
        end,
    })

    H.render_buf(buf)
    return buf
end

---Get window config for given Chosen buffer
---@param buf chosen.Buf
---@return vim.api.keyset.win_config
H.win_config = function(buf)
    local float = H.config.float

    local opts = {
        border = float.border,
        relative = "win",
        style = "minimal",
        height = math.max(
            math.min(float.max_height, vim.b[buf].chosen_height or 0),
            float.min_height,
            1 -- if value in config lesser than 1
        ),
        width = math.max(
            math.min(float.max_width, vim.b[buf].chosen_width or 0),
            float.min_width,
            1 -- if value in config lesser than 1
        ),
        title = float.title,
        title_pos = float.title_pos,
    }

    opts.col = (vim.api.nvim_win_get_width(0) - opts.width) / 2
    opts.row = (vim.api.nvim_win_get_height(0) - opts.height) / 2

    return opts
end

---@param buf chosen.Buf?
---@return chosen.Win
H.open_win = function(buf)
    buf = buf or H.create_buf()
    -- close existing window
    pcall(vim.api.nvim_win_close, vim.fn.bufwinid(buf), false)

    H.render_buf(buf)
    H.render_highlights(buf)

    local win = vim.api.nvim_open_win(buf, true, H.win_config(buf))

    for opt, val in pairs(H.config.float.win_options) do
        vim.wo[win][opt] = val
    end

    return win
end

-- toggles Chosen window
M.toggle = function()
    if vim.bo.filetype == "chosen" then
        vim.api.nvim_win_close(0, false)
    else
        H.open_win(H.create_buf())
    end
end

---@alias chosen.Buf integer Chosen buffer which uses specific buffer local variables
---@alias chosen.Win integer

return M
