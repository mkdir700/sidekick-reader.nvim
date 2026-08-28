local Reader = require("sidekick_reader.reader")

local terminal_buf = vim.api.nvim_create_buf(false, true)
local terminal_win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(terminal_win, terminal_buf)
local initial_windows = #vim.api.nvim_list_wins()
local observer_opts

local reader = Reader.new({
	layout = "stacked",
	viewer_ratio = 0.8,
	registry = {
		read = function()
			return { url = "ws://127.0.0.1:4567" }
		end,
	},
	registry_dir = "/tmp/sidekick_reader-test",
	observer_factory = function(opts)
		observer_opts = opts
		return {
			start = function() end,
			stop = function()
				_G.sidekick_reader_observer_stopped = true
			end,
		}
	end,
})

local terminal = {
	win = terminal_win,
	hide = function(self)
		self.hidden = true
	end,
	focus = function(self)
		self.focused = true
	end,
}

reader:show("%8", terminal_win, terminal)
assert(#vim.api.nvim_list_wins() == initial_windows + 1, "stacked mode should add a viewer window")
assert(vim.api.nvim_win_get_buf(terminal_win) == terminal_buf, "the original Sidekick terminal must remain in place")

local viewer_win
for _, win in ipairs(vim.api.nvim_list_wins()) do
	if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "sidekick-reader" then
		viewer_win = win
	end
end
assert(viewer_win, "the stacked viewer window is missing")
local viewer_height = vim.api.nvim_win_get_height(viewer_win)
local terminal_height = vim.api.nvim_win_get_height(terminal_win)
assert(viewer_height > terminal_height * 3, "the viewer should use roughly 80% of the available height")

local state = reader.states["%8"]
observer_opts.on_event("item/started", {
	item = { type = "userMessage", id = "before-clear", content = { { type = "text", text = "Before clear" } } },
})
observer_opts.on_event("item/started", {
	item = { type = "agentMessage", id = "clear-reply", text = "Visible reply", phase = "final_answer" },
})
vim.api.nvim_set_current_win(terminal_win)
vim.api.nvim_exec_autocmds("CursorMoved", { buffer = state.buf })
assert(state.follow, "clearing the focused terminal must not stop the reader from following output")
observer_opts.on_event("item/started", {
	item = { type = "agentMessage", id = "after-clear", text = "After clear", phase = "final_answer" },
})
assert(
	vim.api.nvim_win_get_cursor(state.win)[1] == vim.api.nvim_buf_line_count(state.buf),
	"messages after clearing the terminal should remain visible"
)

reader:hide("%8")
assert(#vim.api.nvim_list_wins() == initial_windows, "hiding Sidekick should hide the viewer too")
assert(vim.api.nvim_win_is_valid(terminal_win), "the Sidekick terminal window must remain valid")

vim.cmd("new")
local reopened_terminal_win = vim.api.nvim_get_current_win()
vim.api.nvim_win_close(terminal_win, true)
terminal.win = reopened_terminal_win

local reopened_ok, reopened_err = pcall(reader.show, reader, "%8", reopened_terminal_win, terminal)
assert(reopened_ok, "reopening from a new Sidekick window must not reuse the closed window: " .. tostring(reopened_err))
assert(#vim.api.nvim_list_wins() == initial_windows + 1, "showing Sidekick should restore the viewer")

state = reader.states["%8"]
vim.api.nvim_set_current_win(state.win)
assert(vim.fn.maparg("gf", "n") ~= "", "the reader should provide a file-open key")
vim.bo[state.buf].modifiable = true
vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, { "first", "second", "latest" })
vim.bo[state.buf].modifiable = false
vim.api.nvim_win_set_cursor(state.win, { 1, 0 })
local follow_mapping = vim.fn.maparg("G", "n", false, true)
assert(type(follow_mapping.callback) == "function", "the reader should provide a follow key")
follow_mapping.callback()
assert(vim.api.nvim_win_get_cursor(state.win)[1] == 3, "G must move the reader to its latest line")

local input_mapping = vim.fn.maparg("i", "n", false, true)
assert(type(input_mapping.callback) == "function", "the reader should provide a return-to-input key")
input_mapping.callback()
assert(terminal.focused, "the input key should focus Sidekick")

local close_mapping = vim.fn.maparg("q", "n", false, true)
assert(type(close_mapping.callback) == "function", "the reader should provide a workspace hide key")
close_mapping.callback()
assert(terminal.hidden, "q should hide the whole Sidekick workspace")

reader:close("%8")
assert(reader.states["%8"] == nil, "closing Sidekick should discard the reader state")
assert(_G.sidekick_reader_observer_stopped, "closing Sidekick should stop the observer")

print("stacked_reader_spec: ok")
