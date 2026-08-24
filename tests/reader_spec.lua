local Reader = require("sidekick_reader.reader")

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
	registry_dir = "/tmp/sidekick_reader-test",
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
assert(
	rendered ~= origin and vim.bo[rendered].filetype == "sidekick-reader",
	"the current window should show the reader"
)
assert(vim.b[rendered].sidekick_reader_pane_id == "%7", "the rendered buffer should remember its Sidekick pane")
vim.api.nvim_set_current_win(0)
assert(vim.fn.maparg("<C-]>", "n") ~= "", "the reader should provide the same return key")
assert(observed_url == "ws://127.0.0.1:4567", "the reader observed the wrong Sidekick session")

observer_opts.on_event("item/started", {
	item = { type = "userMessage", id = "u1", content = { { type = "text", text = "Hello from Sidekick" } } },
})
assert(table.concat(vim.api.nvim_buf_get_lines(rendered, 0, -1, false), "\n"):find("Hello from Sidekick", 1, true))
observer_opts.on_event("item/started", {
	item = { type = "agentMessage", id = "a1", text = "", phase = "final_answer" },
})
observer_opts.on_event("item/agentMessage/delta", { itemId = "a1", delta = "Newest reply" })
assert(
	vim.api.nvim_win_get_cursor(0)[1] == vim.api.nvim_buf_line_count(rendered),
	"follow mode should keep the cursor on the newest content"
)

vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.cmd("doautocmd CursorMoved")
local old_view = vim.fn.winsaveview()
observer_opts.on_event("item/agentMessage/delta", { itemId = "a1", delta = " while reading" })
assert(vim.api.nvim_win_get_cursor(0)[1] == 2, "background output must not move the cursor while reading history")
assert(vim.fn.winsaveview().topline == old_view.topline, "background output must not move the viewport")
assert(vim.wo[0].winbar:find("New output", 1, true), "new background output should be announced in the header")

reader:toggle("%7", 0)
assert(vim.api.nvim_win_get_buf(0) == origin, "the second toggle should restore the Sidekick terminal")

reader:toggle("%7", 0)
assert(vim.api.nvim_win_get_cursor(0)[1] == 2, "reopening should restore the old reading position")

vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(rendered), 0 })
vim.cmd("doautocmd CursorMoved")
observer_opts.on_event("item/started", {
	item = { type = "userMessage", id = "u2", content = { { type = "text", text = "A later message" } } },
})
assert(
	vim.api.nvim_win_get_cursor(0)[1] == vim.api.nvim_buf_line_count(rendered),
	"moving to the last line should re-enter follow mode"
)

vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.cmd("doautocmd CursorMoved")
local follow_mapping = vim.fn.maparg("G", "n", false, true)
assert(
	follow_mapping.buffer == 1 and type(follow_mapping.callback) == "function",
	"the reader should provide follow mode"
)
follow_mapping.callback()
assert(
	vim.api.nvim_win_get_cursor(0)[1] == vim.api.nvim_buf_line_count(rendered),
	"G should return to the newest content"
)
assert(not vim.wo[0].winbar:find("New output", 1, true), "following again should clear the new output notice")

assert(vim.fn.maparg("<C-j>", "n", false, true).buffer ~= 1, "the reader must not override the window-navigation key")
assert(vim.fn.maparg("<C-k>", "n", false, true).buffer ~= 1, "the reader must not override the window-navigation key")
assert(vim.fn.maparg("]m", "n") ~= "", "the reader should jump to the next message with ]m")
assert(vim.fn.maparg("[m", "n") ~= "", "the reader should jump to the previous message with [m")

print("reader_spec: ok")
