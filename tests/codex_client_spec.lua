local Client = require("sidekick_reader.providers.codex.client")

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

local errors = {}
local reply = ""
local connected = false
local completed = false
local client = Client.new({
	cmd = { "nvim", "--headless", "-u", "tests/minimal_init.lua", "-l", "tests/fixtures/fake_codex.lua" },
	cwd = vim.fn.getcwd(),
	on_delta = function(delta)
		reply = reply .. delta
	end,
	on_error = function(err)
		errors[#errors + 1] = err
	end,
})

client:start(function(err)
	assert_equal(nil, err)
	connected = true
end)

assert(
	vim.wait(3000, function()
		return connected
	end),
	"Codex client did not initialize"
)

client:send("Say hello", function(err)
	assert_equal(nil, err)
	completed = true
end)

assert(
	vim.wait(3000, function()
		return completed
	end),
	"Codex turn did not complete"
)

assert_equal({}, errors)
assert_equal("hello world", reply, "streamed reply text should remain unchanged")
assert_equal("thread-test", client:thread_id(), "the active conversation should be retained")

client:stop()
print("codex_client_spec: ok")
