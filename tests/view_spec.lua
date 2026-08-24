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
vim.api.nvim_win_set_cursor(reopened.win, { 1, 0 })
view.jump(reopened.buf, 1)
assert_equal({ 4, 0 }, vim.api.nvim_win_get_cursor(reopened.win), "next message should jump to its heading")
view.jump(reopened.buf, -1)
assert_equal({ 1, 0 }, vim.api.nvim_win_get_cursor(reopened.win), "previous message should jump back to its heading")

view.render(reopened.buf, {
	{ role = "tool", kind = "command", command = "pwd", output = "/tmp\n", status = "completed" },
})
local tool_text = table.concat(vim.api.nvim_buf_get_lines(reopened.buf, 0, -1, false), "\n")
assert(tool_text:find("pwd", 1, true) and tool_text:find("/tmp", 1, true), "command activity should be readable")

print("view_spec: ok")
