local view = require("sidekick_reader.view")

local function assert_equal(expected, actual, message)
	if not vim.deep_equal(expected, actual) then
		error(
			(message or "values differ")
				.. "\nexpected: "
				.. vim.inspect(expected)
				.. "\nactual: "
				.. vim.inspect(actual)
		)
	end
end

local original =
	"This reply is deliberately longer than the narrow Sidekick Reader window but contains no source newline."
local result = view.open({
	width = 24,
	messages = {
		{ role = "assistant", text = original },
	},
})

assert_equal(true, vim.wo[result.win].wrap, "the conversation window should wrap long text visually")
assert_equal(
	original,
	vim.api.nvim_buf_get_lines(result.buf, 1, 2, false)[1],
	"the buffer should preserve original text"
)
local labels = {}
for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(result.buf, -1, 0, -1, { details = true })) do
	for _, virtual_line in ipairs(mark[4].virt_lines or {}) do
		for _, chunk in ipairs(virtual_line) do
			labels[#labels + 1] = chunk[1]
		end
	end
end
assert(
	table.concat(labels, " "):find("Sidekick Reader", 1, true),
	"the assistant role should be visual, not buffer text"
)

vim.api.nvim_set_current_win(result.win)
vim.api.nvim_win_set_cursor(result.win, { 2, 0 })
vim.cmd("normal! yy")
assert_equal(original .. "\n", vim.fn.getreg('"'), "yanking visually wrapped text should preserve the original")

vim.api.nvim_win_close(result.win, true)
local reopened = view.open({
	buf = result.buf,
	width = 32,
	messages = {
		{ role = "assistant", text = original },
	},
})

assert_equal(result.buf, reopened.buf, "reopening should reuse the existing conversation buffer")
assert_equal(original, vim.api.nvim_buf_get_lines(reopened.buf, 1, 2, false)[1])

view.render(reopened.buf, {
	{ role = "user", text = "first" },
	{ role = "assistant", text = "second" },
	{ role = "user", text = "third" },
})
assert_equal(1, view.message_index(reopened.buf, 2), "message content should resolve to its message")
assert_equal(1, view.message_index(reopened.buf, 3), "the separator should resolve to the message above it")
assert_equal(2, view.message_index(reopened.buf, 4), "the next message should resolve independently")
vim.api.nvim_win_set_cursor(reopened.win, { 2, 0 })
view.jump(reopened.buf, 1)
assert_equal({ 4, 0 }, vim.api.nvim_win_get_cursor(reopened.win), "next message should jump to its content")
view.jump(reopened.buf, -1)
assert_equal({ 2, 0 }, vim.api.nvim_win_get_cursor(reopened.win), "previous message should jump back to its content")
vim.api.nvim_win_set_cursor(reopened.win, { 4, 0 })
view.jump_edge(reopened.buf, "last")
assert_equal({ 6, 0 }, vim.api.nvim_win_get_cursor(reopened.win), "last message should jump to its content")
view.jump_edge(reopened.buf, "first")
assert_equal({ 2, 0 }, vim.api.nvim_win_get_cursor(reopened.win), "first message should jump to its content")

view.render(reopened.buf, {
	{ role = "tool", kind = "command", command = "pwd", output = "/tmp\n", status = "completed" },
})
local tool_text = table.concat(vim.api.nvim_buf_get_lines(reopened.buf, 0, -1, false), "\n")
assert(tool_text:find("pwd", 1, true) and tool_text:find("/tmp", 1, true), "command activity should be readable")
assert(vim.fn.foldclosed(2) == 2, "completed command activity should be folded by default")

local multiline_command_ok = pcall(view.render, reopened.buf, {
	{
		role = "tool",
		kind = "command",
		command = "cat <<'EOF'\nhello\nEOF",
		output = "hello\n",
		status = "completed",
	},
})
assert(multiline_command_ok, "replayed multiline commands must be split into valid buffer lines")
assert(vim.fn.foldclosed(2) == 2, "a replayed multiline command should remain folded")

view.render(reopened.buf, {
	{
		role = "tool",
		kind = "file_change",
		status = "completed",
		changes = {
			{ path = "/tmp/example.rs", kind = "update", diff = "@@ -1 +1 @@\n-before\n+after" },
		},
	},
})
local diff_text = table.concat(vim.api.nvim_buf_get_lines(reopened.buf, 0, -1, false), "\n")
assert(diff_text:find("/tmp/example.rs", 1, true), "file changes should show the edited path")
assert(diff_text:find("-before", 1, true) and diff_text:find("+after", 1, true), "file changes should show the diff")
assert(vim.fn.foldclosed(2) == -1, "file diffs should remain expanded")

local live_messages = {
	{ role = "assistant", text = "working" },
	{ role = "tool", kind = "command", command = "cargo test", output = "running\n", status = "inProgress" },
}
view.render(reopened.buf, { live_messages[1] })
view.update(reopened.buf, live_messages, { type = "append", index = 2 })
assert(vim.fn.foldclosed(4) == 4, "a live command should be folded when it is appended")
live_messages[2].output = "running\ndone\n"
live_messages[2].status = "completed"
view.update(reopened.buf, live_messages, { type = "update", index = 2 })
assert(vim.fn.foldclosed(4) == 4, "a live command should remain folded as output arrives")

local live_diff = {
	role = "tool",
	kind = "file_change",
	status = "inProgress",
	changes = { { path = "/tmp/live.rs", kind = "update", diff = "+first" } },
}
view.render(reopened.buf, { live_diff })
live_diff.changes = { { path = "/tmp/live.rs", kind = "update", diff = "-first\n+second" } }
view.update(reopened.buf, { live_diff }, { type = "update", index = 1 })
local live_diff_text = table.concat(vim.api.nvim_buf_get_lines(reopened.buf, 0, -1, false), "\n")
assert(live_diff_text:find("-first", 1, true) and live_diff_text:find("+second", 1, true))

view.set_status(reopened.buf, reopened.win, { type = "active" })
assert(
	vim.wait(500, function()
		return vim.wo[reopened.win].winbar:find("Working", 1, true) ~= nil
	end),
	"active work should be visible in the header"
)
local function has_bottom_working_line()
	for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(reopened.buf, -1, 0, -1, { details = true })) do
		for _, virtual_line in ipairs(mark[4].virt_lines or {}) do
			for _, chunk in ipairs(virtual_line) do
				if chunk[1]:find("Working", 1, true) then
					return true
				end
			end
		end
	end
	return false
end
assert(not has_bottom_working_line(), "working status should not be rendered below the latest message")
view.set_status(reopened.buf, reopened.win, { type = "idle" })
assert(vim.wo[reopened.win].winbar:find("Ready", 1, true), "idle work should be visible in the header")

local many = {}
for index = 1, 12 do
	many[#many + 1] = { role = "assistant", text = "message " .. index }
end
view.render(reopened.buf, many)
vim.api.nvim_win_set_height(reopened.win, 8)
view.follow(reopened.buf, reopened.win)
local screen_line = vim.api.nvim_win_call(reopened.win, vim.fn.winline)
assert(screen_line >= 6, "follow mode should keep the newest content near the bottom, not vertically centered")

local nullable_ok = pcall(view.render, reopened.buf, {
	{ role = "tool", kind = "command", command = "pwd", output = vim.NIL, status = "inProgress" },
	{ role = "assistant", text = vim.NIL },
})
assert(nullable_ok, "nullable Codex text fields must not crash the renderer")

print("view_spec: ok")
