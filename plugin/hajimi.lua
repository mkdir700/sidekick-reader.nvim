if vim.g.loaded_hajimi then
	return
end
vim.g.loaded_hajimi = true

vim.api.nvim_create_user_command("Hajimi", function(opts)
	require("hajimi").toggle(opts.args ~= "" and opts.args or nil)
end, {
	nargs = "?",
	desc = "Toggle the Hajimi view for a Sidekick Codex session",
})
