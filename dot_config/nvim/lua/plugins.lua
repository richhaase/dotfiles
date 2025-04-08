local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    -- LSP manager
	"williamboman/mason.nvim",
	"williamboman/mason-lspconfig.nvim",
	"neovim/nvim-lspconfig",
	-- Add hooks to LSP to support Linter && Formatter
	{
		"jay-babu/mason-null-ls.nvim",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"williamboman/mason.nvim",
			"nvimtools/none-ls.nvim",
			"nvim-lua/plenary.nvim"
		},
		config = function()
			require("config.mason-null-ls")
		end,
	},
	-- Vscode-like pictograms
	{
		"onsails/lspkind.nvim",
		event = { "VimEnter" },
	},
	-- Auto-completion engine
	{
		"hrsh7th/nvim-cmp",
		dependencies = {
			"lspkind.nvim",
			"hrsh7th/cmp-nvim-lsp", -- lsp auto-completion
			"hrsh7th/cmp-buffer", -- buffer auto-completion
			"hrsh7th/cmp-path", -- path auto-completion
			"hrsh7th/cmp-cmdline", -- cmdline auto-completion
		},
		config = function()
			require("config.nvim-cmp")
		end,
	},
    -- Code snippet engine
	{
		"L3MON4D3/LuaSnip",
		version = "v2.*",
        build = "make install_jsregexp"
	},
    -- Colorscheme
	"tanvirtin/monokai.nvim",
    -- Run `:checkhealth noice` to check for common issues
    {
        "folke/noice.nvim",
        event = "VeryLazy",
        opts = {},
        dependencies = {
            -- If you lazy-load any plugin below, make sure to add proper `module="..."` entries
            "MunifTanjim/nui.nvim",
            -- OPTIONAL:
            --   `nvim-notify` is only needed, if you want to use the notification view.
            --   If not available, we use `mini` as the fallback
            "rcarriga/nvim-notify",
        },
    },
    -- Git integrations 
    'tpope/vim-fugitive',
    -- Git decorations
	{
		"lewis6991/gitsigns.nvim",
		config = function()
			require("config.gitsigns")
		end,
	},
    -- Autopairs: [], (), "", '', etc
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = function()
			require("config.nvim-autopairs")
		end,
	},
    -- treesitter
    {
        'nvim-treesitter/nvim-treesitter',
        build = ':TSUpdate',
        config = function()
            require('config.nvim-treesitter')
        end,
    },
	-- treesitter text objects
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		dependencies = "nvim-treesitter/nvim-treesitter",
		config = function()
			require("config.nvim-treesitter-textobjects")
		end,
	},
	-- Show indentation and blankline
	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		config = function()
			require("config.indent-blankline")
		end,
	},
    -- Status line - lualine
    {
        'nvim-lualine/lualine.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        config = function()
			require("config.lualine")
		end,
    },
    -- Markdown support
    {
        "preservim/vim-markdown",
        ft = { "markdown" }
    },
    -- file explorer
    {
        "nvim-tree/nvim-tree.lua",
        version = "*",
        lazy = false,
        dependencies = {
            "nvim-tree/nvim-web-devicons",
        },
        config = function()
            require("nvim-tree").setup {}
        end,
    },
    -- Smart motion
    -- Usage: Enter a 2-character search pattern then press a label character to
    --        pick your target.
    --        Initiate the sesarch with `s`(forward) or `S`(backward)
    {
        "ggandor/leap.nvim",
        config = function()
            -- See `:h leap-custom-mappings` for more details
            require("leap").create_default_mappings()
        end,
    },
    -- Make surrounding easier
    -- ------------------------------------------------------------------
    -- Old text                    Command         New text
    -- ------------------------------------------------------------------
    -- surr*ound_words             gziw)           (surround_words)
    -- *make strings               gz$"            "make strings"
    -- [delete ar*ound me!]        gzd]            delete around me!
    -- remove <b>HTML t*ags</b>    gzdt            remove HTML tags
    -- 'change quot*es'            gzc'"           "change quotes"
    -- delete(functi*on calls)     gzcf            function calls
    -- ------------------------------------------------------------------
    {
        "kylechui/nvim-surround",
        version = "*", -- Use for stability; omit to use `main` branch for the latest features
        -- You can use the VeryLazy event for things that can
        -- load later and are not important for the initial UI
        event = "VeryLazy",
        config = function()
        require("nvim-surround").setup({
            -- To solve the conflicts with leap.nvim
            -- See: https://github.com/ggandor/leap.nvim/discussions/59
            keymaps = {
                insert = "<C-g>z",
                insert_line = "gC-ggZ",
                normal = "gz",
                normal_cur = "gZ",
                normal_line = "gzgz",
                normal_cur_line = "gZgZ",
                visual = "gz",
                visual_line = "gZ",
                delete = "gzd",
                change = "gzc",
            },
        })
        end,
    },
    -- fuzzy finder
    {
        "ibhagwan/fzf-lua",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require('config.fzf-lua')
        end,
    },
    -- Improve the performance of big file
    {
    	"pteroctopus/faster.nvim",
    },
    -- Trouble
    {
        "folke/trouble.nvim",
        opts = {},
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        cmd = "Trouble",
        lazy = false,
        keys = {
            {
                "<leader>xx",
                "<cmd>Trouble diagnostics toggle<cr>",
            desc = "Diagnostics (Trouble)",
            },
            {
                "<leader>cs",
                "<cmd>Trouble symbols toggle focus=false<cr>",
                desc = "Symbols (Trouble)",
            },
            {
                "<leader>cl",
                "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
                desc = "LSP Definitions / references / ... (Trouble)",
            },
        },
    },
    -- Marks
    {
        "chentoast/marks.nvim",
        event = "VeryLazy",
        opts = {},
    },
    -- {
    --     "willothy/nvim-cokeline",
    --     dependencies = {
    --         "nvim-lua/plenary.nvim",        -- Required for v0.4.0+
    --         "nvim-tree/nvim-web-devicons", -- If you want devicons
    --         "stevearc/resession.nvim"       -- Optional, for persistent history
    --     },
    --     config = true
    -- },
    -- Julia lang support
    "JuliaEditorSupport/julia-vim",
    -- toggleterm
    {
         'akinsho/toggleterm.nvim',
         version = "*",
         config = function()
             require('config.toggleterm')
         end,
    },
    {
        "goolord/alpha-nvim",
        -- dependencies = { 'echasnovski/mini.icons' },
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        config = function()
        local startify = require("alpha.themes.startify")
        -- available: devicons, mini, default is mini
        -- if provider not loaded and enabled is true, it will try to use another provider
        startify.file_icons.provider = "devicons"
        require("alpha").setup(
            startify.config
        )
        end,
    },
})
