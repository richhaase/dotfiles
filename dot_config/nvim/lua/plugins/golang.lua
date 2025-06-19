return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gopls = {
          settings = {
            gopls = {
              gofumpt = true,              -- Use gofumpt for formatting
              usePlaceholders = true,      -- Function signature placeholders
              analyses = {
                unusedparams = true,       -- Detect unused parameters
                shadow = true,             -- Detect shadowed variables
              },
              staticcheck = true,          -- Enable staticcheck linter
              codelenses = {
                gc_details = true,         -- Show GC details
                generate = true,           -- Show generate commands
                test = true,               -- Show test commands
              },
            },
          },
        },
      },
    },
  },
}