local hajimi = require("hajimi")

local toggled
hajimi.setup({
	registry_dir = "/tmp/hajimi",
	reader_factory = function()
		return {
			toggle = function(_, pane_id, win)
				toggled = { pane_id = pane_id, win = win }
				return true
			end,
		}
	end,
})

local ok = hajimi.toggle("%7", 0)
assert(ok and toggled.pane_id == "%7" and toggled.win == 0)

dofile(vim.fn.getcwd() .. "/plugin/hajimi.lua")
assert(vim.fn.exists(":Hajimi") == 2, "the Hajimi command should exist")

print("plugin_spec: ok")
