local hajimi = require("hajimi")

local toggled
local shown
local hidden
local closed
hajimi.setup({
	registry_dir = "/tmp/hajimi",
	reader_factory = function()
		return {
			toggle = function(_, pane_id, win)
				toggled = { pane_id = pane_id, win = win }
				return true
			end,
			show = function(_, pane_id, win, terminal)
				shown = { pane_id = pane_id, win = win, terminal = terminal }
				return true
			end,
			hide = function(_, pane_id)
				hidden = pane_id
			end,
			close = function(_, pane_id)
				closed = pane_id
			end,
		}
	end,
})

local ok = hajimi.toggle("%7", 0)
assert(ok and toggled.pane_id == "%7" and toggled.win == 0)

local terminal = {}
hajimi.sidekick_show("%8", 12, terminal)
assert(shown.pane_id == "%8" and shown.win == 12 and shown.terminal == terminal)
hajimi.sidekick_hide("%8")
assert(hidden == "%8")
hajimi.sidekick_close("%8")
assert(closed == "%8")

dofile(vim.fn.getcwd() .. "/plugin/hajimi.lua")
assert(vim.fn.exists(":Hajimi") == 2, "the Hajimi command should exist")

print("plugin_spec: ok")
