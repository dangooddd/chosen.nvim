local M = {} -- module
local H = {} -- hidden module
local uv = vim.uv or vim.loop

M.config = {
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
}

---Utility function to set default table value
---@param tbl table
---@param val any
function H.set_tbl_default(tbl, val)
    setmetatable(tbl, { __index = function() return val end })
end

---Get cwd with resolved links
---@return string?
function H.get_resolved_cwd()
    local cwd = uv.cwd()
    if not cwd then return nil end
    return vim.fn.resolve(cwd)
end

---Table where Chosen stores files
---Stores in following format
---[ ["cwd"] = { "file1", "file2" } ]
---@class chosen.Index
---@field [string] table<string> Index entry for given cwd
M.index = {}

---@param store_path string?
---@return chosen.Index
function M.load_index(store_path)
    store_path = store_path or M.config.store_path
    if not uv.fs_stat(store_path) then return {} end

    -- load file as lua
    local ok, out = pcall(dofile, store_path)
    if not ok then return {} end -- empty table on first launch
    return out
end

---@param store_path string?
---@param index chosen.Index?
function M.dump_index(store_path, index)
    store_path = store_path or M.config.store_path
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
---@field store_path? string File where Chosen data file (index) will be stored
---@field keys? string Keys that will be used to pick files
---@field autowrite? boolean Autowrite Chosen index file on exit
---@field ui_options? chosen.UIOpts
---@field win_options? table<string, any> Window local options in Chosen buffers
---@field buf_options? table<string, any> Buffer local options in Chosen buffers
---@field keymap? chosen.Keymap

---@class chosen.UIOpts
---@field min_width? integer
---@field min_height? integer
---@field max_width? integer
---@field max_height? integer
---@field border? "rounded"|"single"|"double"
---@field title? string
---@field title_pos? "left"|"center"|"right"

---@class chosen.Keymap
---@field revert? string Mapping to reset mode (or exit in default mode)
---@field save? string Mapping to add current file to Chosen index
---@field delete? string Mapping to toggle delete mode
---@field swap? string Mapping to toggle swap mode

---@param opts chosen.SetupOpts?
function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})

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
            if M.config.autowrite then
                M.dump_index()
            end
        end,
    })

    -- define Chosen user command
    vim.api.nvim_create_user_command("Chosen", M.toggle, {})

    -- load index on setup
    M.index = M.load_index()
end

---Delete file from index entry for given cwd
---@param cwd string?
---@param fname string File name to delete
function H.delete_from_index(cwd, fname)
    cwd = cwd or H.get_resolved_cwd()
    if not cwd or not M.index[cwd] then return end

    fname = vim.fn.fnamemodify(fname, ":p")

    for i, file in ipairs(M.index[cwd] or {}) do
        if file == fname then
            table.remove(M.index[cwd], i)
            break
        end
    end

    if #M.index[cwd] == 0 then
        M.index[cwd] = nil
    end
end

---Swap two files in index entry for given cwd
---@param cwd string?
---@param lhs string First file path to swap
---@param rhs string Second file path to swap
function H.swap_in_index(cwd, lhs, rhs)
    cwd = cwd or H.get_resolved_cwd()
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

---Save file to index entry for given cwd
---@param cwd string?
---@param fname string
function H.save_to_index(cwd, fname)
    cwd = cwd or H.get_resolved_cwd()
    if not cwd then return end              -- ensure that cwd is not nil

    fname = vim.fn.fnamemodify(fname, ":p") -- use only absolute path to prevent issues
    M.index[cwd] = M.index[cwd] or {}       -- ensure that index entry exist

    -- insert if not duplicate
    if not vim.tbl_contains(M.index[cwd], fname) then
        table.insert(M.index[cwd], fname)
    end
end

---Edit file with given name
---@param fname string
function H.edit(fname)
    -- prefer relative path for edit command
    -- escape name for edit (if name contains spaces, for example)
    fname = vim.fn.fnamemodify(fname, ":.")
    fname = vim.fn.fnameescape(fname)
    pcall(vim.cmd.edit, fname)
end

---Callbacks to call on buffer actions
---@type table<string, function>
H.keymap_callbacks = {
    ---Clear swap|delete mode or close window
    ---@param buf chosen.Buf
    revert = function(buf)
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
        H.save_to_index(nil, vim.b[buf].chosen_fname)
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
        if vim.b[buf].chosen_mode == "swap_first" or
            vim.b[buf].chosen_mode == "swap_second"
        then
            vim.b[buf].chosen_mode = ""
        else
            vim.b[buf].chosen_mode = "swap_first"
        end

        H.render_highlights(buf)
    end,
}

---Callbacks to call on file pick with current mode
---@type table<string, function>
H.mode_actions = {
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
        H.delete_from_index(nil, fname)
        vim.b[buf].chosen_mode = ""

        -- re-render window because number of files is probably changed
        H.open_win(buf)
    end,

    ---Enter second stage of swapping
    ---@param buf chosen.Buf
    ---@param fname string
    ["swap_first"] = function(buf, fname)
        vim.b[buf].chosen_swap = fname
        vim.b[buf].chosen_mode = "swap_second"
    end,

    ---Swap files
    ---@param buf chosen.Buf
    ---@param fname string
    ["swap_second"] = function(buf, fname)
        H.swap_in_index(nil, vim.b[buf].chosen_swap, fname)
        vim.b[buf].chosen_swap = nil
        vim.b[buf].chosen_mode = ""

        -- re-render only buffer
        H.render_buf(buf)
        H.render_highlights(buf)
    end,
}

H.set_tbl_default(H.mode_actions, H.mode_actions[""])

---@type table<string, string>
H.mode_hls = {
    [""] = "ChosenIndex",
    ["delete"] = "ChosenDelete",
    ["swap_first"] = "ChosenSwap",
    ["swap_second"] = "ChosenSwap",
}

H.set_tbl_default(H.mode_hls, H.mode_hls[""])

---@param buf chosen.Buf
function H.render_highlights(buf)
    vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)

    ---@type integer
    vim.b[buf].chosen_height = vim.b[buf].chosen_height or 0 -- ensure value exist

    local hl = H.mode_hls[vim.b[buf].chosen_mode]

    -- set hl based on current Chosen mode
    for i = 0, vim.b[buf].chosen_height - 1 do
        vim.api.nvim_buf_add_highlight(buf, -1, hl, i, 0, 2)
    end

    -- set hl for message on empty menu
    if vim.b[buf].chosen_height == 0 then
        vim.api.nvim_buf_add_highlight(buf, -1, hl, 0, 0, -1)
    end
end

---@param buf chosen.Buf?
function H.render_buf(buf)
    ---@type chosen.Buf
    buf = buf or vim.api.nvim_get_current_buf()
    vim.bo[buf].modifiable = true -- by default chosen buffer is not modifiable
    vim.b[buf].chosen_width = 1   -- for width update on repeated rendering

    local cwd = uv.cwd()
    local keys = M.config.keys
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
            H.mode_actions[vim.b[buf].chosen_mode](buf, fname)
        end, keymap_opts)
    end

    vim.b[buf].chosen_height = #lines

    -- message on empty menu
    if #lines == 0 then
        lines[1] = string.format(" Press %s to save ", M.config.keymap.save)
        vim.b[buf].chosen_width = #lines[1]
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false -- reset modifiable
    H.render_highlights(buf)
end

---@param fname string?
---@return chosen.Buf
function H.create_buf(fname)
    fname = fname or vim.fn.expand("%:p")
    local buf = vim.api.nvim_create_buf(false, true)

    vim.b[buf].chosen_fname = fname
    vim.b[buf].chosen_mode = ""
    vim.b[buf].chosen_height = 0
    vim.b[buf].chosen_width = 0

    for opt, val in pairs(M.config.buf_options) do
        vim.bo[buf][opt] = val
    end

    local keymap_opts = {
        silent = true,
        buffer = buf,
        noremap = true,
        nowait = true
    }

    vim.keymap.set("n", "q", "<cmd>q<CR>", keymap_opts)

    for name, mapping in pairs(M.config.keymap) do
        vim.keymap.set("n", mapping, function()
            H.keymap_callbacks[name](buf)
        end, keymap_opts)
    end

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

---Create window config for given Chosen buffer
---@param buf chosen.Buf
---@return vim.api.keyset.win_config
function H.create_win_config(buf)
    local ui = M.config.ui_options

    local opts = {
        border = ui.border,
        relative = "win",
        style = "minimal",
        height = math.max(
            math.min(ui.max_height, vim.b[buf].chosen_height or 0),
            ui.min_height,
            1 -- if value in config lesser than 1
        ),
        width = math.max(
            math.min(ui.max_width, vim.b[buf].chosen_width or 0),
            ui.min_width,
            1 -- if value in config lesser than 1
        ),
        title = ui.title,
        title_pos = ui.title_pos,
    }

    opts.col = (vim.api.nvim_win_get_width(0) - opts.width) / 2
    opts.row = (vim.api.nvim_win_get_height(0) - opts.height) / 2

    return opts
end

---@param buf chosen.Buf?
---@return chosen.Win
function H.open_win(buf)
    buf = buf or H.create_buf()
    -- close existing window
    pcall(vim.api.nvim_win_close, vim.fn.bufwinid(buf), false)

    H.render_buf(buf)
    H.render_highlights(buf)

    local win = vim.api.nvim_open_win(buf, true, H.create_win_config(buf))

    for opt, val in pairs(M.config.win_options) do
        vim.wo[win][opt] = val
    end

    return win
end

-- toggles Chosen window
function M.toggle()
    if not vim.b.chosen_fname then
        H.open_win(H.create_buf())
    else
        vim.api.nvim_win_close(0, false)
    end
end

---@alias chosen.Buf integer
---@alias chosen.Win integer

return M
