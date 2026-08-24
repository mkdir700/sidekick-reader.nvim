if vim.g.loaded_hajimi then
	return
end
vim.g.loaded_hajimi = true

vim.api.nvim_create_user_command("Hajimi", function(opts)
	if opts.args == "" then
		require("hajimi").open()
	else
		require("hajimi").ask(opts.args)
	end
end, {
	nargs = "*",
	desc = "Open Hajimi or ask a question",
})
