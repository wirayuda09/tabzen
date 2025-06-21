local M = {}

M.defaults = {
    -- UI settings
    max_tab_width = 20,
    show_tab_numbers = true,
    show_close_button = true,
    show_modified_indicator = true,

    auto_close_empty_tabs = false,
    cycle_tabs = true,

    -- Styling
    separator = "│",
    modified_icon = "●",
    close_icon = "×",

    -- Keymaps
    keymaps = {
        next_tab = "<Tab>",
        prev_tab = "<S-Tab>",
        close_tab = "<leader>tc",
        new_tab = "<leader>tn",
        move_tab_left = "<leader>t<",
        move_tab_right = "<leader>t>",
        goto_tab = "<leader>gt", -- followed by number
    },

    -- Performance
    update_interval = 50, -- ms
    lazy_redraw = true,
}

M.options = {}

function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
