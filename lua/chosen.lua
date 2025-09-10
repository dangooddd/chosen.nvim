local M = {} -- module
local H = {} -- hidden module
local uv = vim.uv or vim.loop

M.config = {
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
}

---Utility function to set default table value
---@param tbl table
---@param val any
function H.set_tbl_default(tbl, val)
    setmetatable(tbl, { __index = function() return val end })
end

---Get icon from webdevicons or mini.icons
---@param fname string
---@return string?, string?
function H.get_icon(fname)
    local ok_web_icons, web_icons = pcall(require, "nvim-web-devicons")
    local ok_mini_icons, mini_icons = pcall(require, "mini.icons")

    if ok_mini_icons then
        return mini_icons.get("file", fname)
    elseif ok_web_icons then
        fname = vim.fn.fnamemodify(fname, ":t")
        local ext = vim.fn.fnamemodify(fname, ":e")
        return web_icons.get_icon(fname, ext, { default = true })
    end
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
---@field bind_hjkl? boolean Change behaviour of hjkl keys in Chosen buffers
---@field close_on_save? boolean Close window on save / delete of current file action
---@field close_on_write? boolean Close window on write action
---@field notify_on_write? boolean Send notification on write action
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
---@field show_icons? boolean

---@class chosen.Keymap
---@field revert? string Mapping to reset mode (or exit in default mode)
---@field save? string Mapping to add current file to Chosen index
---@field delete? string Mapping to toggle delete mode
---@field swap? string Mapping to toggle swap mode
---@field split? string Mapping to toggle split mode
---@field vsplit? string Mapping to toggle vsplit mode

---@param opts chosen.SetupOpts?
function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})

    -- highlights
    vim.api.nvim_set_hl(0, "ChosenKey", { link = "Comment", default = true })
    vim.api.nvim_set_hl(0, "ChosenDelete", { link = "DiagnosticError", default = true })
    vim.api.nvim_set_hl(0, "ChosenSwap", { link = "DiagnosticWarn", default = true })
    vim.api.nvim_set_hl(0, "ChosenPlaceholder", { link = "DiagnosticHint", default = true })
    vim.api.nvim_set_hl(0, "ChosenSplit", { link = "DiagnosticInfo", default = true })
    vim.api.nvim_set_hl(0, "ChosenCurrentFile", { link = "Special", default = true })
    vim.api.nvim_set_hl(0, "ChosenCursor", { nocombine = true, blend = 100, default = true })

    -- autocmds
    vim.api.nvim_create_augroup("Chosen", { clear = true })

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
    if not H.index_loaded then
        H.index_loaded = true
        M.index = M.load_index()
    end
end

---Delete file from index entry for given cwd
---Returns true if found and deleted
---@param cwd string?
---@param fname string File name to delete
---@return boolean?
function H.delete_from_index(cwd, fname)
    cwd = cwd or H.get_resolved_cwd()
    if not cwd or not M.index[cwd] then return end

    fname = vim.fn.fnamemodify(fname, ":p")

    for i, file in ipairs(M.index[cwd]) do
        if file == fname then
            table.remove(M.index[cwd], i)
            if #M.index[cwd] == 0 then
                M.index[cwd] = nil
            end
            return true
        end
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
    -- ensure that cwd is not nil
    if not cwd then return end
    -- ensure that filename not empty
    if vim.fn.fnamemodify(fname, ":t") == "" then return end

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

---Toggle chosen buffer mode
---@param buf chosen.Buf
---@param pattern string Pattern to determine mode
---@param value string? Value to place if pattern is not found
function H.toggle_mode(buf, pattern, value)
    value = value or pattern

    if string.find(vim.b[buf].chosen_mode or "", pattern) then
        vim.b[buf].chosen_mode = ""
    else
        vim.b[buf].chosen_mode = value
    end

    -- re-render after mode changed
    H.render_buf(buf)
end

---Callbacks to call on buffer actions
---@type table<string, function>
H.keymap_callbacks = {
    ---Clear mode or close window
    ---@param buf chosen.Buf
    revert = function(buf)
        if vim.b[buf].chosen_mode == "" then
            pcall(vim.api.nvim_win_close, vim.fn.bufwinid(buf), false)
        else
            vim.b[buf].chosen_mode = ""
            H.render_buf(buf)
        end
    end,

    ---Save current file to index
    ---If already saved, delete it
    ---@param buf chosen.Buf
    save = function(buf)
        if not H.delete_from_index(nil, vim.b[buf].chosen_fname) then
            H.save_to_index(nil, vim.b[buf].chosen_fname)
        end

        if M.config.close_on_save then
            pcall(vim.api.nvim_win_close, vim.fn.bufwinid(buf), false)
        else
            H.refresh_win(buf)
        end
    end,

    ---@param buf chosen.Buf
    delete = function(buf)
        H.toggle_mode(buf, "delete")
    end,

    ---@param buf chosen.Buf
    swap = function(buf)
        H.toggle_mode(buf, "swap", "swap_first")
    end,

    ---@param buf chosen.Buf
    split = function(buf)
        H.toggle_mode(buf, "split_horizontal")
    end,

    ---@param buf chosen.Buf
    vsplit = function(buf)
        H.toggle_mode(buf, "split_vertical")
    end,

    ---@param buf chosen.Buf
    write = function(buf)
        M.dump_index()

        if M.config.notify_on_write then
            vim.notify("Chosen index written", vim.log.levels.INFO)
        end

        if M.config.close_on_write then
            pcall(vim.api.nvim_win_close, vim.fn.bufwinid(buf), false)
        end
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
        H.refresh_win(buf)
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

        -- re-render buffer
        H.render_buf(buf)
    end,

    ---@param buf chosen.Buf
    ---@param fname string
    ["split_horizontal"] = function(buf, fname)
        pcall(vim.api.nvim_win_close, vim.fn.bufwinid(buf), false)
        vim.cmd.split()
        H.edit(fname)
    end,

    ---@param buf chosen.Buf
    ---@param fname string
    ["split_vertical"] = function(buf, fname)
        pcall(vim.api.nvim_win_close, vim.fn.bufwinid(buf), false)
        vim.cmd.vsplit()
        H.edit(fname)
    end,
}

H.set_tbl_default(H.mode_actions, H.mode_actions[""])

---@type table<string, string>
H.mode_hls = {
    [""] = "ChosenKey",
    ["delete"] = "ChosenDelete",
    ["swap_first"] = "ChosenSwap",
    ["swap_second"] = "ChosenSwap",
    ["split_horizontal"] = "ChosenSplit",
    ["split_vertical"] = "ChosenSplit",
}

H.set_tbl_default(H.mode_hls, H.mode_hls[""])

---@param buf chosen.Buf
function H.render_buf(buf)
    vim.bo[buf].modifiable = true -- by default chosen buffer is not modifiable
    vim.b[buf].chosen_width = 1   -- for width update on repeated rendering

    -- clear hls
    vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)

    local cwd = H.get_resolved_cwd()
    local keys = M.config.keys
    local mode_hl = H.mode_hls[vim.b[buf].chosen_mode]
    local lines = {}
    local hls = {}

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
        lines[i] = fname

        -- highlight current file
        if vim.fn.fnamemodify(fname, ":p") == vim.b[buf].chosen_fname then
            hls[#hls + 1] = { "ChosenCurrentFile", i - 1, 3, -1 }
        end

        local icon_len = 1
        if M.config.ui_options.show_icons then
            local icon, icon_hl = H.get_icon(fname)
            if icon then
                lines[i] = string.format("%s %s", icon, lines[i])
                icon_len = #icon
                hls[#hls + 1] = { icon_hl, i - 1, 3, 4 }
            end
        end

        lines[i] = string.format(" %s %s ", key, lines[i])

        -- key hightlights
        hls[#hls + 1] = { mode_hl, i - 1, 0, 2 }

        -- calculate max width of a line
        -- because lua length is in bytes, we should correct width when icon showing
        vim.b[buf].chosen_width = math.max(vim.b[buf].chosen_width, #lines[i] - icon_len + 1)

        -- keybinds
        vim.keymap.set("n", key, function()
            H.mode_actions[vim.b[buf].chosen_mode](buf, fname)
        end, keymap_opts)
    end

    vim.b[buf].chosen_height = #lines

    -- message on empty menu
    if #lines == 0 then
        lines[1] = string.format(" Press %s to save ", M.config.keymap.save)
        -- placeholder highlights
        table.insert(hls, { "ChosenPlaceholder", 0, 0, -1 })
        vim.b[buf].chosen_width = #lines[1]
    end

    -- place text
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- place hls
    for _, hl_param in ipairs(hls) do
        vim.api.nvim_buf_add_highlight(buf, -1, unpack(hl_param))
    end

    vim.bo[buf].modifiable = false -- reset modifiable
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

    if M.config.bind_hjkl then
        vim.keymap.set("n", "j", "<PageDown>", keymap_opts)
        vim.keymap.set("n", "k", "<PageUp>", keymap_opts)
        vim.keymap.set("n", "h", "z<Left>", keymap_opts)
        vim.keymap.set("n", "l", "z<Right>", keymap_opts)
    end

    for name, mapping in pairs(M.config.keymap) do
        vim.keymap.set("n", mapping, function()
            H.keymap_callbacks[name](buf)
        end, keymap_opts)
    end

    -- set custom cursor
    vim.opt.guicursor:append("n:ChosenCursor/ChosenCursor")

    -- auto close window when focus changes
    vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave", "CmdlineEnter" }, {
        group = "Chosen",
        buffer = buf,
        once = true,
        -- use schedule_wrap to prevent instant close
        -- of other floating windows or other issues
        callback = vim.schedule_wrap(function()
            -- reset cursor
            vim.opt.guicursor:remove("n:ChosenCursor/ChosenCursor")

            -- autoclose on leave
            pcall(vim.api.nvim_win_close, vim.fn.bufwinid(buf), false)
        end),
    })

    H.render_buf(buf)
    return buf
end

---Create window config for given Chosen buffer
---@param buf chosen.Buf
---@param relative_win integer?
---@return vim.api.keyset.win_config
function H.create_win_config(buf, relative_win)
    local ui = M.config.ui_options
    local opts = {
        border = ui.border,
        relative = "win",
        win = relative_win or vim.api.nvim_get_current_win(),
        style = "minimal",
        height = math.max(
            math.min(ui.max_height, vim.b[buf].chosen_height or 0),
            ui.min_height,
            1
        ),
        width = math.max(
            math.min(ui.max_width, vim.b[buf].chosen_width or 0),
            ui.min_width,
            1
        ),
        title = ui.title,
        title_pos = ui.title_pos,
    }

    opts.col = math.max(0, (vim.api.nvim_win_get_width(opts.win) - opts.width) / 2)
    opts.row = math.max(0, (vim.api.nvim_win_get_height(opts.win) - opts.height) / 2)

    return opts
end

---@param buf chosen.Buf
---@return chosen.Win
function H.refresh_win(buf)
    local win = vim.fn.bufwinid(buf)
    if win == -1 then return win end

    H.render_buf(buf)

    -- on refresh, keep relative window
    local old_config = vim.api.nvim_win_get_config(win)
    local new_config = H.create_win_config(buf, old_config.win)

    vim.api.nvim_win_set_config(win, new_config)

    return win
end

---@param buf chosen.Buf
---@return chosen.Win
function H.open_win(buf)
    -- close existing window
    pcall(vim.api.nvim_win_close, vim.fn.bufwinid(buf), false)

    H.render_buf(buf)

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
