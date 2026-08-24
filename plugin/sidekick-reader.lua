if vim.g.loaded_sidekick_reader then
	return
end
vim.g.loaded_sidekick_reader = true

vim.api.nvim_create_user_command("SidekickReader", function(opts)
	require("sidekick_reader").toggle(opts.args ~= "" and opts.args or nil)
end, {
	nargs = "?",
	desc = "Toggle the Sidekick Reader view for a Sidekick Codex session",
})
