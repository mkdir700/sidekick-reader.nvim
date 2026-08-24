local reader = require("sidekick_reader")

local toggled
local shown
local hidden
local closed
reader.setup({
	registry_dir = "/tmp/sidekick_reader",
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

local ok = reader.toggle("%7", 0)
assert(ok and toggled.pane_id == "%7" and toggled.win == 0)

local terminal = {}
reader.sidekick_show("%8", 12, terminal)
assert(shown.pane_id == "%8" and shown.win == 12 and shown.terminal == terminal)
reader.sidekick_hide("%8")
assert(hidden == "%8")
reader.sidekick_close("%8")
assert(closed == "%8")

dofile(vim.fn.getcwd() .. "/plugin/sidekick-reader.lua")
assert(vim.fn.exists(":SidekickReader") == 2, "the SidekickReader command should exist")

local attempts = 0
reader.setup({
	reader_factory = function()
		return {
			show = function()
				attempts = attempts + 1
				if attempts == 1 then
					return nil, "No Sidekick Reader session is registered for this Sidekick pane"
				end
				return true
			end,
		}
	end,
})
reader.sidekick_show("%9", 13, {})
assert(
	vim.wait(500, function()
		return attempts == 2
	end),
	"a newly started Sidekick session should be retried until its registration is ready"
)

attempts = 0
reader.setup({
	reader_factory = function()
		return {
			show = function()
				attempts = attempts + 1
				return nil, "No Sidekick Reader session is registered for this Sidekick pane"
			end,
			hide = function() end,
		}
	end,
})
reader.sidekick_show("%10", 14, {})
reader.sidekick_hide("%10")
vim.wait(100)
assert(attempts == 1, "hiding Sidekick should cancel registration retries")

print("plugin_spec: ok")
