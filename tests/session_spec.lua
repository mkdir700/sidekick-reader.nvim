local Session = require("sidekick_reader.session")

local changes = 0
local status
local session = Session.new({
	on_change = function()
		changes = changes + 1
	end,
	on_status = function(value)
		status = value
	end,
})

session:handle("thread/status/changed", { status = { type = "active" } })
assert(status.type == "active", "thread status should reach the view")

session:handle("item/started", {
	item = { type = "userMessage", id = "user-1", content = { { type = "text", text = "Hello" } } },
})
session:handle("item/started", {
	item = { type = "agentMessage", id = "agent-1", text = "", phase = "final_answer" },
})
session:handle("item/agentMessage/delta", { itemId = "agent-1", delta = "Hello " })
session:handle("item/agentMessage/delta", { itemId = "agent-1", delta = "back" })
session:handle("item/started", {
	item = { type = "commandExecution", id = "cmd-1", command = "pwd", cwd = "/tmp", status = "inProgress" },
})
session:handle("item/commandExecution/outputDelta", { itemId = "cmd-1", delta = "/tmp\n" })
session:handle("item/completed", {
	item = { type = "commandExecution", id = "cmd-1", command = "pwd", status = "completed", exitCode = 0 },
})

local messages = session:messages()
assert(messages[1].role == "user" and messages[1].text == "Hello")
assert(messages[2].role == "assistant" and messages[2].text == "Hello back")
assert(messages[3].role == "tool" and messages[3].command == "pwd")
assert(messages[3].output == "/tmp\n" and messages[3].status == "completed")
assert(changes >= 7, "live event updates should notify the view")

local replay = Session.new()
replay:load({
	turns = {
		{
			items = {
				{ type = "userMessage", id = "old-user", content = { { type = "text", text = "Earlier question" } } },
				{ type = "agentMessage", id = "old-agent", text = "Earlier answer", phase = "final_answer" },
			},
		},
	},
})
assert(replay:messages()[1].text == "Earlier question" and replay:messages()[2].text == "Earlier answer")

local nullable = Session.new()
nullable:handle("item/started", {
	item = {
		type = "commandExecution",
		id = "nullable-command",
		command = "pwd",
		aggregatedOutput = vim.NIL,
		status = "inProgress",
	},
})
nullable:handle("item/started", {
	item = { type = "agentMessage", id = "nullable-agent", text = vim.NIL, phase = "final_answer" },
})
assert(type(nullable:messages()[1].output) == "string" and nullable:messages()[1].output == "")
assert(type(nullable:messages()[2].text) == "string" and nullable:messages()[2].text == "")

print("session_spec: ok")
