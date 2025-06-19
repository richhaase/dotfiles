return {
  "stevearc/oil.nvim",
  opts = {
    default_file_explorer = false,  -- Keep netrw as default
  },
  keys = {
    { "<leader>o", "<cmd>Oil<cr>", desc = "Open Oil file manager" },
  },
}