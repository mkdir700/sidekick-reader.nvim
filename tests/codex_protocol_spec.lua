local Protocol = require("hajimi.providers.codex.protocol")

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

local deltas = {}
local protocol = Protocol.new({
	on_notification = function(method, params)
		if method == "item/agentMessage/delta" then
			deltas[#deltas + 1] = params.delta
		end
	end,
})

protocol:feed(
	'{"method":"item/agentMessage/delta","params":{"delta":"hello ","threadId":"t","turnId":"x","itemId":"i"}}\n{"method":"item/agent'
)
assert_equal({ "hello " }, deltas, "complete events should be delivered immediately")

protocol:feed('Message/delta","params":{"delta":"world","threadId":"t","turnId":"x","itemId":"i"}}\n')
assert_equal({ "hello ", "world" }, deltas, "partial events should be reassembled without changing text")

local response
local request = protocol:request(
	"initialize",
	{ clientInfo = { name = "hajimi", version = "0.1.0" } },
	function(err, result)
		assert_equal(nil, err)
		response = result
	end
)

local decoded = vim.json.decode(request)
assert_equal("initialize", decoded.method)
assert_equal("hajimi", decoded.params.clientInfo.name)

protocol:feed(vim.json.encode({ id = decoded.id, result = { userAgent = "codex-test" } }) .. "\n")
assert_equal({ userAgent = "codex-test" }, response, "responses should reach the matching request")

print("codex_protocol_spec: ok")
