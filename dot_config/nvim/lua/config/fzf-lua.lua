local fzf_lua = require("fzf-lua")
fzf_lua.setup({'fzf-native'})

-- Keymaps
vim.api.nvim_set_keymap("n", "<leader>fb", [[<Cmd>lua require"fzf-lua".buffers()<CR>]], {})
vim.api.nvim_set_keymap("n", "<leader>ff", [[<Cmd>lua require"fzf-lua".files()<CR>]], {})
vim.api.nvim_set_keymap("n", "<leader>fg", [[<Cmd>lua require"fzf-lua".live_grep_glob()<CR>]], {})
vim.api.nvim_set_keymap("n", "<leader>fs", [[<Cmd>lua require"fzf-lua".git_status()<CR>]], {})
vim.api.nvim_set_keymap("n", "<leader>fo", [[<Cmd>lua require"fzf-lua".oldfiles()<CR>]], {})
vim.api.nvim_set_keymap("n", "<leader>fk", [[<Cmd>lua require"fzf-lua".keymaps()<CR>]], {})
vim.api.nvim_set_keymap("n", "<leader>fm", [[<Cmd>lua require"fzf-lua".marks()<CR>]], {})

