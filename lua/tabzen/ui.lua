local config = require("tabzen.config")
local utils = require("tabzen.utils")

local M = {}

-- UI state
local state = {
    last_render = "",
    namespace = vim.api.nvim_create_namespace("tabzen"),
}

function M.render_tab(bufnr, is_current, tab_num)
    local opts = config.options
    local name = utils.get_buffer_name(bufnr)
    local modified = utils.is_buffer_modified(bufnr)

    -- Build tab content
    local content = ""

    -- Add padding
    content = content .. " "

    -- Tab number
    if opts.show_tab_numbers then
        content = content .. tab_num .. ":"
    end

    -- Buffer name
    content = content .. utils.truncate_string(name, opts.max_tab_width)

    -- Modified indicator
    if modified and opts.show_modified_indicator then
        content = content .. opts.modified_icon
    end

    -- Close button
    if opts.show_close_button then
        content = content .. " " .. opts.close_icon
    end

    -- Add padding
    content = content .. " "

    -- Apply highlighting based on current state
    local hl_group = is_current and "TabLineSel" or "TabLine"

    return {
        content = content,
        highlight = hl_group,
        bufnr = bufnr,
    }
end

function M.build_tabline()
    local buffers = utils.get_tab_buffers()
    local current_buf = vim.api.nvim_get_current_buf()
    local opts = config.options

    if #buffers == 0 then
        return ""
    end

    local tabline_parts = {}

    for i, bufnr in ipairs(buffers) do
        local is_current = bufnr == current_buf
        local tab = M.render_tab(bufnr, is_current, i)

        -- Use proper tabline syntax for clickable tabs
        local hl_start = is_current and "%#TabLineSel#" or "%#TabLine#"
        local clickable = string.format("%%%d@TabzenClick@", bufnr)
        local tab_content = hl_start .. clickable .. tab.content .. "%T"

        table.insert(tabline_parts, tab_content)
    end

    -- Add separator between tabs and fill the rest
    local result = table.concat(tabline_parts, "%#TabLineFill#" .. opts.separator)
    result = result .. "%#TabLineFill#"

    return result
end

function M.update_tabline()
    local new_tabline = M.build_tabline()

    -- Only update if changed (performance optimization)
    if new_tabline ~= state.last_render then
        vim.o.tabline = new_tabline
        state.last_render = new_tabline

        if config.options.lazy_redraw then
            vim.cmd("redrawtabline")
        end
    end
end

-- Click handler for tab clicks
function M.handle_tab_click(bufnr, clicks, button, modifiers)
    if button == "l" then -- left click
        if clicks == 1 then
            -- Switch to the clicked buffer
            vim.schedule(function()
                vim.api.nvim_set_current_buf(tonumber(bufnr))
            end)
        elseif clicks == 2 then
            -- Double click to close
            vim.schedule(function()
                M.close_buffer(tonumber(bufnr))
            end)
        end
    elseif button == "m" then -- middle click
        vim.schedule(function()
            M.close_buffer(tonumber(bufnr))
        end)
    end
end

function M.close_buffer(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    local buffers = utils.get_tab_buffers()

    -- Don't close if it's the last buffer
    if #buffers <= 1 then
        return
    end

    -- Switch to next buffer before closing
    local current_idx = nil
    for i, buf in ipairs(buffers) do
        if buf == bufnr then
            current_idx = i
            break
        end
    end

    if current_idx then
        local next_buf = buffers[current_idx + 1] or buffers[current_idx - 1]
        if next_buf then
            vim.api.nvim_set_current_buf(next_buf)
        end
    end

    -- Use pcall to handle errors gracefully
    pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
    utils.clear_cache()
end

return M
