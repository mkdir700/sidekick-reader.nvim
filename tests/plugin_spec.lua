local hajimi = require("hajimi")

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

local sent
hajimi.setup({
	width = 30,
	provider_factory = function(opts)
		return {
			start = function(_, callback)
				callback(nil)
			end,
			send = function(_, text, callback)
				sent = text
				opts.on_delta("Hajimi reply")
				callback(nil)
			end,
			thread_id = function()
				return "thread-command"
			end,
		}
	end,
})

dofile(vim.fn.getcwd() .. "/plugin/hajimi.lua")
vim.cmd("Hajimi Explain this file")

assert_equal("Explain this file", sent)
assert_equal("hajimi", vim.bo.filetype)
assert_equal("Hajimi reply", vim.api.nvim_buf_get_lines(0, 4, 5, false)[1])
assert(vim.fn.maparg("i", "n") ~= "", "the conversation should provide an input key")
assert(vim.fn.maparg("]m", "n") ~= "", "the conversation should provide next-message navigation")
assert(vim.fn.maparg("[m", "n") ~= "", "the conversation should provide previous-message navigation")
assert(vim.fn.exists(":Hajimi") == 2, "the Hajimi command should exist")

print("plugin_spec: ok")
