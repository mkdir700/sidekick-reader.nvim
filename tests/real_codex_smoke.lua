local Client = require("sidekick_reader.providers.codex.client")

local reply = ""
local failure
local connected = false
local completed = false
local client = Client.new({
	cwd = vim.fn.getcwd(),
	on_delta = function(delta)
		reply = reply .. delta
	end,
	on_error = function(err)
		failure = err
	end,
})

client:start(function(err)
	failure = err
	connected = err == nil
end)

assert(
	vim.wait(10000, function()
		return connected or failure ~= nil
	end),
	"Timed out while connecting to the real Codex service"
)
assert(not failure, failure)

client:send("Reply with exactly SIDEKICK_READER_OK. Do not use tools or modify files.", function(err)
	failure = err
	completed = err == nil
end)

assert(
	vim.wait(120000, function()
		return completed or failure ~= nil
	end, 50),
	"Timed out while waiting for the real Codex reply"
)

client:stop()
assert(not failure, failure)
assert(reply:find("SIDEKICK_READER_OK", 1, true), "Unexpected real Codex reply: " .. reply)

print("real_codex_smoke: " .. reply)
