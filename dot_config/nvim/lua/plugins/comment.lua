return {
  "numToStr/Comment.nvim",
  event = "VeryLazy",
  opts = {
    -- Enable treesitter integration for smart commenting
    pre_hook = function()
      return require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook()
    end,
  },
}