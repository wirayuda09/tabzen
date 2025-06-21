local M = {}

-- Cache for performance
local cache = {
    buffers = {},
    last_update = 0,
}

function M.get_buffer_name(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == "" then
        return "[No Name]"
    end
    return vim.fn.fnamemodify(name, ":t")
end

function M.is_buffer_modified(bufnr)
    return vim.api.nvim_buf_get_option(bufnr, "modified")
end

function M.is_valid_buffer(bufnr)
    return vim.api.nvim_buf_is_valid(bufnr) and
        vim.api.nvim_buf_get_option(bufnr, "buflisted") and
        vim.api.nvim_buf_get_option(bufnr, "buftype") == ""
end

function M.get_tab_buffers()
    local current_time = vim.loop.now()

    -- Use cache if recent enough
    if current_time - cache.last_update < 50 then
        return cache.buffers
    end

    -- Get all listed buffers instead of just tab windows
    local buffers = {}
    local all_buffers = vim.api.nvim_list_bufs()

    for _, bufnr in ipairs(all_buffers) do
        if M.is_valid_buffer(bufnr) then
            table.insert(buffers, bufnr)
        end
    end

    -- Sort buffers by their number for consistent ordering
    table.sort(buffers)

    cache.buffers = buffers
    cache.last_update = current_time

    return buffers
end

function M.truncate_string(str, max_width)
    if #str <= max_width then
        return str
    end
    return str:sub(1, max_width - 1) .. "…"
end

function M.clear_cache()
    cache.buffers = {}
    cache.last_update = 0
end

return M
