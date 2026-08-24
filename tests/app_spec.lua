local App = require("hajimi.app")
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

local provider
local app = App.new({
	cwd = vim.fn.getcwd(),
	view = view,
	provider_factory = function(opts)
		provider = {
			start = function(_, callback)
				callback(nil)
			end,
			send = function(_, text, callback)
				assert_equal("Explain this", text)
				opts.on_delta("checking", { itemId = "message-one" })
				opts.on_delta("finished", { itemId = "message-two" })
				callback(nil)
			end,
			thread_id = function()
				return "thread-test"
			end,
		}
		return provider
	end,
})

local opened = app:open({ width = 28 })
local completed = false
app:ask("Explain this", function(err)
	assert_equal(nil, err)
	completed = true
end)

assert_equal(true, completed)
assert_equal({
	{ role = "user", text = "Explain this" },
	{ role = "assistant", text = "checking" },
	{ role = "assistant", text = "finished" },
}, app:messages(), "the conversation should contain original user and assistant text")

assert_equal(
	{ "", "Explain this", "", "checking", "", "finished" },
	vim.api.nvim_buf_get_lines(opened.buf, 0, -1, false)
)

vim.api.nvim_win_close(opened.win, true)
local reopened = app:open({ width = 36 })
assert_equal(opened.buf, reopened.buf, "the app should reopen the same conversation")
assert_equal("thread-test", app:thread_id())

print("app_spec: ok")
