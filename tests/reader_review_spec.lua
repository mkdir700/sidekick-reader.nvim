local Reader = require("sidekick_reader.reader")

local observer_opts
local reviewed
local reader = Reader.new({
	registry = {
		read = function()
			return { url = "ws://127.0.0.1:4567" }
		end,
	},
	observer_factory = function(opts)
		observer_opts = opts
		return { start = function() end }
	end,
	review = {
		open = function(diff, cwd, opts)
			reviewed = { diff = diff, cwd = cwd, title = opts.title }
			return true
		end,
	},
})

reader:toggle("%7", 0)
observer_opts.on_event("item/started", {
	turnId = "turn-1",
	item = { type = "userMessage", id = "user", content = { { type = "text", text = "Review me" } } },
})
observer_opts.on_event("turn/diff/updated", { turnId = "turn-1", diff = "round-one-diff" })
vim.api.nvim_win_set_cursor(0, { 2, 0 })
local mapping = vim.fn.maparg("gd", "n", false, true)
assert(type(mapping.callback) == "function", "the reader should review the current turn with gd")
mapping.callback()
assert(reviewed and reviewed.diff == "round-one-diff" and reviewed.title:find("turn%-1"))

print("reader_review_spec: ok")
