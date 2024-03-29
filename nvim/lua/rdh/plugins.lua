local ensure_packer = function()
    local fn = vim.fn
    local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
    if fn.empty(fn.glob(install_path)) > 0 then
        fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
        vim.cmd [[packadd packer.nvim]]
        return true
    end
    return false
end
local packer_bootstrap = ensure_packer()


-- Reload configurations if we modify plugins.lua
vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerSync
  augroup end
]])


-- Install plugins 
return require('packer').startup(function(use)
    use 'wbthomason/packer.nvim'

    use {
        'folke/tokyonight.nvim',
        lazy = false,
        priority = 1000,
        opts = {},
    }
    use 'chentoast/marks.nvim'
    use {
        'nvim-tree/nvim-tree.lua',
        config = function()
            require('nvim-tree').setup()
        end,
        requires = {
            'nvim-tree/nvim-web-devicons',
        },
    }
    use { 'akinsho/toggleterm.nvim', tag = '*',
        config = function()
            require('toggleterm').setup {
                open_mapping = [[<c-s>]],
                insert_mappings = true,
                terminal_mappings = true,
                direction = 'float',
                auto_scroll = true,
            }
        end
    }
    use { 'ibhagwan/fzf-lua',
        requires = { 'nvim-tree/nvim-web-devicons' }
    }
    use { 'nvim-lualine/lualine.nvim',
        requires = { 'nvim-tree/nvim-web-devicons', opt = true }
    }  
    use 'tpope/vim-fugitive'
    use { 'numToStr/Comment.nvim',
        config = function()
            require('Comment').setup()
        end
    }
    use { 'nvim-treesitter/nvim-treesitter', {run = ':TSUpdate'} }

    if packer_bootstrap then
        require('packer').sync()
    end
end)

