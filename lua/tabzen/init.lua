local M = {}

-- Configuration
local config = {
    max_tab_width = 15,
    show_tab_numbers = false,
    show_close_button = true,
    show_modified_indicator = false,
    separator = " │ ",
    modified_icon = "●",
    close_icon = "×",
    debug_clicks = false,
    keymaps = {
        next_tab = "<Tab>",
        prev_tab = "<S-Tab>",
        close_tab = "<leader>x",
        new_tab = "<leader>n",
    }
}

-- Helper function to brighten a color
local function brighten_color(color, amount)
    if not color or color == "" then
        return "#3a3a3a"
    end

    color = color:gsub("#", "")
    local r = tonumber(color:sub(1, 2), 16) or 0
    local g = tonumber(color:sub(3, 4), 16) or 0
    local b = tonumber(color:sub(5, 6), 16) or 0

    r = math.min(255, r + amount)
    g = math.min(255, g + amount)
    b = math.min(255, b + amount)

    return string.format("#%02x%02x%02x", r, g, b)
end

-- Set up subtle highlight groups with brighter backgrounds
local function setup_highlights()
    local normal_bg = vim.fn.synIDattr(vim.fn.hlID("Normal"), "bg")
    local tabline_bg = vim.fn.synIDattr(vim.fn.hlID("TabLine"), "bg")
    local tabline_fg = vim.fn.synIDattr(vim.fn.hlID("TabLine"), "fg")

    if normal_bg == "" then normal_bg = "#1e1e1e" end
    if tabline_bg == "" then tabline_bg = "#2d2d2d" end
    if tabline_fg == "" then tabline_fg = "#c0c0c0" end

    local active_bg = brighten_color(tabline_bg, 25)
    local active_modified_bg = brighten_color(tabline_bg, 20)

    vim.api.nvim_set_hl(0, "TabZenActive", {
        fg = "#ffffff",
        bg = active_bg,
        bold = true,
        default = false
    })

    vim.api.nvim_set_hl(0, "TabZenInactive", {
        fg = "#808080",
        bg = tabline_bg,
        default = false
    })

    vim.api.nvim_set_hl(0, "TabZenActiveModified", {
        fg = "#e6c07b",
        bg = active_modified_bg,
        bold = false,
        default = false
    })

    vim.api.nvim_set_hl(0, "TabZenInactiveModified", {
        fg = "#d19a66",
        bg = tabline_bg,
        italic = true,
        default = false
    })

    vim.api.nvim_set_hl(0, "TabZenSeparator", {
        fg = "#444444",
        bg = tabline_bg,
        default = false
    })

    vim.api.nvim_set_hl(0, "TabZenFill", {
        fg = "NONE",
        bg = tabline_bg,
        default = false
    })

    vim.api.nvim_set_hl(0, "TabZenCloseButton", {
        fg = "#ff6b6b",
        bg = "NONE",
        bold = true,
        default = false
    })
end

-- Utility functions
local function get_buffer_name(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == "" then
        return "[No Name]"
    end
    return vim.fn.fnamemodify(name, ":t")
end

local function is_valid_buffer(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return false
    end

    local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
    local buflisted = vim.api.nvim_buf_get_option(bufnr, "buflisted")

    return buflisted and buftype == ""
end

local function get_listed_buffers()
    local buffers = {}
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if is_valid_buffer(bufnr) then
            table.insert(buffers, bufnr)
        end
    end
    table.sort(buffers)
    return buffers
end

local function truncate_string(str, max_width)
    if #str <= max_width then
        return str
    end
    return str:sub(1, max_width - 1) .. "…"
end

-- Tab rendering with close button support
local function render_tab(bufnr, is_current, tab_num)
    local name = get_buffer_name(bufnr)
    local modified = vim.api.nvim_buf_get_option(bufnr, "modified")

    local content = " "
    content = content .. truncate_string(name, config.max_tab_width)

    if modified and config.show_modified_indicator then
        content = content .. config.modified_icon
    end

    -- Choose highlight group based on active state and modified status
    local hl_group
    if is_current then
        hl_group = modified and "TabZenActiveModified" or "TabZenActive"
    else
        hl_group = modified and "TabZenInactiveModified" or "TabZenInactive"
    end

    -- Use v:lua to call the function properly
    local tab_content = string.format("%%#%s#%%%d@v:lua.TabzenBufferClick@%s", hl_group, bufnr, content)

    -- Add close button with separate click handler
    if config.show_close_button then
        local close_content = string.format("%%#TabZenCloseButton#%%%d@v:lua.TabzenCloseClick@ %s %%T", bufnr, config.close_icon)
        tab_content = tab_content .. close_content
    else
        tab_content = tab_content .. " %%T"
    end

    return tab_content
end

-- Main tabline function
function M.tabline()
    local buffers = get_listed_buffers()
    local current_buf = vim.api.nvim_get_current_buf()

    if #buffers == 0 then
        return "%#TabZenFill#"
    end

    local tabs = {}

    for i, bufnr in ipairs(buffers) do
        local is_current = bufnr == current_buf
        local tab = render_tab(bufnr, is_current, i)
        table.insert(tabs, tab)
    end

    local separator = "%#TabZenSeparator#" .. config.separator
    local result = table.concat(tabs, separator)
    result = result .. "%#TabZenFill#%="

    return result
end

-- Click handler for tab (not close button)
function M.handle_click(bufnr, clicks, button)
    bufnr = tonumber(bufnr)
    
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        if config.debug_clicks then
            print("TabzenClick: Invalid buffer " .. (bufnr or "nil"))
        end
        return
    end

    if config.debug_clicks then
        print("TabzenClick: bufnr=" .. bufnr .. ", clicks=" .. clicks .. ", button='" .. button .. "'")
    end

    -- Handle left click
    if button == "l" or button == "1" then
        if clicks == 1 then
            vim.schedule(function()
                if vim.api.nvim_buf_is_valid(bufnr) then
                    vim.api.nvim_set_current_buf(bufnr)
                end
            end)
        end
    -- Handle middle click - close tab
    elseif button == "m" or button == "2" then
        vim.schedule(function()
            M.close_buffer(bufnr)
        end)
    end
end

-- Close button click handler
function M.handle_close_click(bufnr, clicks, button)
    bufnr = tonumber(bufnr)
    
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        if config.debug_clicks then
            print("TabzenCloseClick: Invalid buffer " .. (bufnr or "nil"))
        end
        return
    end

    if config.debug_clicks then
        print("TabzenCloseClick: bufnr=" .. bufnr .. ", clicks=" .. clicks .. ", button='" .. button .. "'")
    end

    -- Any click on close button should close the tab
    vim.schedule(function()
        M.close_buffer(bufnr)
    end)
end

-- Navigation functions
function M.next_tab()
    local buffers = get_listed_buffers()
    local current = vim.api.nvim_get_current_buf()

    if #buffers <= 1 then return end

    for i, bufnr in ipairs(buffers) do
        if bufnr == current then
            local next_buf = buffers[i + 1] or buffers[1]
            vim.api.nvim_set_current_buf(next_buf)
            return
        end
    end
end

function M.prev_tab()
    local buffers = get_listed_buffers()
    local current = vim.api.nvim_get_current_buf()

    if #buffers <= 1 then return end

    for i, bufnr in ipairs(buffers) do
        if bufnr == current then
            local prev_buf = buffers[i - 1] or buffers[#buffers]
            vim.api.nvim_set_current_buf(prev_buf)
            return
        end
    end
end

function M.goto_tab(num)
    local buffers = get_listed_buffers()
    if buffers[num] then
        vim.api.nvim_set_current_buf(buffers[num])
    end
end

function M.close_buffer(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    local buffers = get_listed_buffers()

    if #buffers <= 1 then
        vim.cmd("enew")
        if vim.api.nvim_buf_is_valid(bufnr) and bufnr ~= vim.api.nvim_get_current_buf() then
            pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
        end
        return
    end

    local current_idx = nil
    for i, buf in ipairs(buffers) do
        if buf == bufnr then
            current_idx = i
            break
        end
    end

    if current_idx then
        local next_buf = buffers[current_idx + 1] or buffers[current_idx - 1]
        if next_buf and next_buf ~= bufnr then
            vim.api.nvim_set_current_buf(next_buf)
        end
    end

    pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
end

function M.new_tab()
    vim.cmd("enew")
end

function M.set_highlights(highlights)
    for group, opts in pairs(highlights) do
        vim.api.nvim_set_hl(0, group, opts)
    end
end

-- Setup function with proper initialization order
function M.setup(opts)
    if opts then
        config = vim.tbl_deep_extend("force", config, opts)
    end

    -- FIRST: Register the global click handler functions
    _G.TabzenBufferClick = M.handle_click
    _G.TabzenCloseClick = M.handle_close_click

    -- SECOND: Set up highlights
    setup_highlights()
    if opts and opts.highlights then
        M.set_highlights(opts.highlights)
    end

    -- THIRD: Set up tabline (after functions are registered)
    vim.o.showtabline = 2
    vim.o.tabline = "%!v:lua.require('tabzen').tabline()"

    -- Set up keymaps
    local keymap_opts = { silent = true, noremap = true }

    vim.keymap.set("n", config.keymaps.next_tab, M.next_tab, keymap_opts)
    vim.keymap.set("n", config.keymaps.prev_tab, M.prev_tab, keymap_opts)
    vim.keymap.set("n", config.keymaps.close_tab, M.close_buffer, keymap_opts)
    vim.keymap.set("n", config.keymaps.new_tab, M.new_tab, keymap_opts)

    for i = 1, 9 do
        vim.keymap.set("n", "<leader>" .. i, function()
            M.goto_tab(i)
        end, keymap_opts)
    end

    -- Set up autocommands
    local group = vim.api.nvim_create_augroup("TabZen", { clear = true })

    vim.api.nvim_create_autocmd({
        "BufEnter", "BufLeave", "BufDelete", "BufNew", "BufAdd", "BufModifiedSet"
    }, {
        group = group,
        callback = function()
            vim.schedule(function()
                vim.cmd("redrawtabline")
            end)
        end,
    })

    vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        callback = function()
            vim.schedule(function()
                setup_highlights()
                if opts and opts.highlights then
                    M.set_highlights(opts.highlights)
                end
            end)
        end,
    })
end

return M