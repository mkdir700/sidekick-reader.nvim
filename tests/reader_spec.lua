local Reader = require("hajimi.reader")

local origin = vim.api.nvim_create_buf(false, true)
vim.api.nvim_win_set_buf(0, origin)
local observed_url
local observer_opts

local reader = Reader.new({
	registry = {
		read = function(_, pane)
			if pane == "%7" then
				return { pane = pane, url = "ws://127.0.0.1:4567" }
			end
		end,
	},
	registry_dir = "/tmp/hajimi-test",
	observer_factory = function(opts)
		observer_opts = opts
		return {
			start = function(_, url)
				observed_url = url
			end,
		}
	end,
})

reader:toggle("%7", 0)
local rendered = vim.api.nvim_win_get_buf(0)
assert(rendered ~= origin and vim.bo[rendered].filetype == "hajimi", "the current window should show the reader")
assert(vim.b[rendered].hajimi_pane_id == "%7", "the rendered buffer should remember its Sidekick pane")
vim.api.nvim_set_current_win(0)
assert(vim.fn.maparg("<C-]>", "n") ~= "", "the reader should provide the same return key")
assert(observed_url == "ws://127.0.0.1:4567", "the reader observed the wrong Sidekick session")

observer_opts.on_event("item/started", {
	item = { type = "userMessage", id = "u1", content = { { type = "text", text = "Hello from Sidekick" } } },
})
assert(table.concat(vim.api.nvim_buf_get_lines(rendered, 0, -1, false), "\n"):find("Hello from Sidekick", 1, true))

reader:toggle("%7", 0)
assert(vim.api.nvim_win_get_buf(0) == origin, "the second toggle should restore the Sidekick terminal")

print("reader_spec: ok")
