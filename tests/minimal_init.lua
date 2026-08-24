vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/nui.nvim")

vim.env.XDG_CONFIG_HOME = vim.fn.tempname()
vim.env.XDG_DATA_HOME = vim.fn.tempname()
vim.env.XDG_STATE_HOME = vim.fn.tempname()
vim.env.XDG_CACHE_HOME = vim.fn.tempname()
