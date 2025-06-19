return {
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>k9", function()
        Snacks.terminal.open("k9s", { 
          win = { 
            style = "terminal",
            width = 0.9,
            height = 0.9 
          } 
        })
      end, desc = "Open k9s in popup" },
      
      { "<leader>tp", function()
        Snacks.terminal.open("tfplan", { 
          win = { 
            style = "terminal",
            width = 0.8,
            height = 0.6 
          } 
        })
      end, desc = "Run terraform plan in popup" },
    },
  },
}