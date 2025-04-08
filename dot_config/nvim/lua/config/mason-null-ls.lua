local mason = require("mason")
local null_ls = require("null-ls")
local mason_null_ls = require("mason-null-ls")

mason.setup()

mason_null_ls.setup({
	ensure_installed = {
		"black",
		"stylua",
	},
	-- Run `require("null-ls").setup`.
	-- Will automatically install masons tools based on selected sources in `null-ls`.
	-- Can also be an exclusion list.
	-- Example: `automatic_installation = { exclude = { "rust_analyzer", "solargraph" } }`
	automatic_installation = false,
	-- Sources found installed in mason will automatically be set up for null-ls.
	automatic_setup = true,
	handlers = {
		-- Hint: see https://github.com/nvimtools/none-ls.nvim/blob/main/doc/BUILTINS.md
		--       to see what sources are available
		-- Hint: see https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTIN_CONFIG.md
		--       to check what we can configure for each source
		-- function() end, -- disables automatic setup of all null-ls sources
		black = function(source_name, methods)
			null_ls.register(null_ls.builtins.formatting.black)
		end,
		stylua = function(source_name, methods)
			null_ls.register(null_ls.builtins.formatting.stylua)
		end,
	},
})

null_ls.setup()
