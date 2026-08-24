local view = require("hajimi.view")

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

local original = "This reply is deliberately longer than the narrow Hajimi window but contains no source newline."
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
assert(table.concat(labels, " "):find("Hajimi", 1, true), "the assistant role should be visual, not buffer text")

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
vim.api.nvim_win_set_cursor(reopened.win, { 2, 0 })
view.jump(reopened.buf, 1)
assert_equal({ 4, 0 }, vim.api.nvim_win_get_cursor(reopened.win), "next message should jump to its content")
view.jump(reopened.buf, -1)
assert_equal({ 2, 0 }, vim.api.nvim_win_get_cursor(reopened.win), "previous message should jump back to its content")

view.render(reopened.buf, {
	{ role = "tool", kind = "command", command = "pwd", output = "/tmp\n", status = "completed" },
})
local tool_text = table.concat(vim.api.nvim_buf_get_lines(reopened.buf, 0, -1, false), "\n")
assert(tool_text:find("pwd", 1, true) and tool_text:find("/tmp", 1, true), "command activity should be readable")

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
