local M = {}

local function pane_for(terminal)
	local ok, states = pcall(require("sidekick.cli.state").get, { attached = true, name = "codex" })
	if not ok then
		return
	end
	for _, state in ipairs(states) do
		if state.terminal == terminal and state.session then
			local session = state.session.parent or state.session
			return session.tmux_pane_id
		end
	end
end

local function attach(terminal)
	if terminal._sidekick_reader_wrapped then
		return
	end
	terminal._sidekick_reader_wrapped = true
	local show, hide, close = terminal.show, terminal.hide, terminal.close

	terminal.show = function(self, ...)
		local result = show(self, ...)
		local pane = pane_for(self)
		if pane and self.win then
			require("sidekick_reader").sidekick_show(pane, self.win, self)
		end
		return result
	end
	terminal.hide = function(self, ...)
		local pane = pane_for(self)
		if pane then
			require("sidekick_reader").sidekick_hide(pane)
		end
		return hide(self, ...)
	end
	terminal.close = function(self, ...)
		local pane = pane_for(self)
		if pane then
			require("sidekick_reader").sidekick_close(pane)
		end
		return close(self, ...)
	end
end

function M.setup(sidekick_opts, opts)
	sidekick_opts.cli = sidekick_opts.cli or {}
	sidekick_opts.cli.win = sidekick_opts.cli.win or {}
	sidekick_opts.cli.win.keys = sidekick_opts.cli.win.keys or {}
	sidekick_opts.cli.tools = sidekick_opts.cli.tools or {}

	opts = vim.tbl_deep_extend("force", {
		registry_dir = vim.fs.joinpath(vim.fn.stdpath("state"), "sidekick-reader"),
		layout = "stacked",
		viewer_ratio = 0.8,
	}, opts or {})
	require("sidekick_reader").setup(opts)

	sidekick_opts.cli.mux = vim.tbl_deep_extend("force", sidekick_opts.cli.mux or {}, {
		enabled = true,
		backend = "tmux",
	})
	local bridge = vim.api.nvim_get_runtime_file("scripts/bridge.mjs", false)[1]
	sidekick_opts.cli.tools.codex = vim.tbl_deep_extend("force", sidekick_opts.cli.tools.codex or {}, {
		cmd = { "node", assert(bridge, "Sidekick Reader bridge script is missing"), "launch" },
		env = { SIDEKICK_READER_REGISTRY_DIR = opts.registry_dir },
	})

	local user_config = sidekick_opts.cli.win.config
	sidekick_opts.cli.win.config = function(terminal)
		if user_config then
			user_config(terminal)
		end
		attach(terminal)
	end
	sidekick_opts.cli.win.keys.sidekick_reader = {
		"<C-]>",
		function(terminal)
			local pane = pane_for(terminal)
			if pane and terminal.win then
				require("sidekick_reader").focus(pane, terminal.win, terminal)
			end
		end,
		mode = { "n", "t" },
		desc = "Focus Sidekick Reader",
	}
	return sidekick_opts
end

return M
