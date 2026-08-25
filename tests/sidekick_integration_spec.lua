local integration = require("sidekick_reader.integrations.sidekick")
local reader = require("sidekick_reader")

local setup_opts, shown, focused, hidden, closed
reader.setup = function(opts)
	setup_opts = opts
end
reader.sidekick_show = function(...)
	shown = { ... }
end
reader.focus = function(...)
	focused = { ... }
end
reader.sidekick_hide = function(pane)
	hidden = pane
end
reader.sidekick_close = function(pane)
	closed = pane
end

local terminal = {
	win = 7,
	show = function(self)
		return self
	end,
	hide = function(self)
		return self
	end,
	close = function(self)
		return self
	end,
}
package.loaded["sidekick.cli.state"] = {
	get = function()
		return { { terminal = terminal, session = { parent = { tmux_pane_id = "%4" } } } }
	end,
}

local configured = integration.setup({ cli = { win = {}, tools = {} } })
assert(setup_opts.layout == "stacked" and setup_opts.viewer_ratio == 0.8, "the integration should keep Sidekick visible")
assert(configured.cli.mux.enabled and configured.cli.mux.backend == "tmux", "the integration should enable tmux")
assert(configured.cli.tools.codex.cmd[1] == "node", "the integration should launch the bridge")

configured.cli.win.config(terminal)
terminal:show()
assert(shown[1] == "%4" and shown[2] == 7 and shown[3] == terminal, "showing Sidekick should show the reader")
configured.cli.win.keys.sidekick_reader[2](terminal)
assert(focused[1] == "%4" and focused[2] == 7, "the reader key should focus the matching session")
terminal:hide()
assert(hidden == "%4", "hiding Sidekick should hide the reader")
terminal:close()
assert(closed == "%4", "closing Sidekick should close the reader")

print("sidekick_integration_spec: ok")
