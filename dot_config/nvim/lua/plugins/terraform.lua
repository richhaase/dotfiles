return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        terraformls = {
          -- Better terraform language server settings
          cmd = { "terraform-ls", "serve" },
          filetypes = { "terraform", "terraform-vars" },
          settings = {
            terraformls = {
              experimentalFeatures = {
                validateOnSave = true,
                prefillRequiredFields = true,
              },
            },
          },
        },
      },
    },
  },
}