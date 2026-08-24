local Observer = require("hajimi.observer")

local events = {}
local observer = Observer.new({
	on_event = function(method, params)
		events[#events + 1] = { method = method, params = params }
	end,
})

observer:feed('{"method":"item/agentMessage/delta","params":{"itemId":"a","delta":"hel')
assert(#events == 0, "a partial event must not be emitted")
observer:feed('lo"}}\n{"method":"thread/status/changed","params":{"status":{"type":"idle"}}}\n')
assert(#events == 2, "both complete events should be emitted")
assert(events[1].params.delta == "hello")
assert(events[2].method == "thread/status/changed")

print("observer_spec: ok")
