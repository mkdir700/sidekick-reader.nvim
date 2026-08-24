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
session:handle("item/started", {
	item = {
		type = "fileChange",
		id = "files-1",
		status = "inProgress",
		changes = {
			{ path = "/tmp/example.rs", kind = "update", diff = "@@ -1 +1 @@\n-old\n+new" },
		},
	},
})
session:handle("item/fileChange/patchUpdated", {
	itemId = "files-1",
	changes = {
		{ path = "/tmp/example.rs", kind = "update", diff = "@@ -1 +1 @@\n-before\n+after" },
	},
})
session:handle("item/completed", {
	item = {
		type = "fileChange",
		id = "files-1",
		status = "completed",
		changes = {
			{ path = "/tmp/example.rs", kind = "update", diff = "@@ -1 +1 @@\n-before\n+after" },
		},
	},
})

local messages = session:messages()
assert(messages[1].role == "user" and messages[1].text == "Hello")
assert(messages[2].role == "assistant" and messages[2].text == "Hello back")
assert(messages[3].role == "tool" and messages[3].command == "pwd")
assert(messages[3].output == "/tmp\n" and messages[3].status == "completed")
assert(messages[4].role == "tool" and messages[4].kind == "file_change")
assert(messages[4].changes[1].path == "/tmp/example.rs")
assert(messages[4].changes[1].diff:find("+after", 1, true) and messages[4].status == "completed")
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

local turns = Session.new()
turns:handle("item/started", {
	turnId = "turn-1",
	item = { type = "userMessage", id = "turn-1-user", content = { { type = "text", text = "First turn" } } },
})
turns:handle("turn/diff/updated", { turnId = "turn-1", diff = "first version" })
turns:handle("turn/diff/updated", { turnId = "turn-1", diff = "final first-turn diff" })
turns:handle("item/started", {
	turnId = "turn-2",
	item = { type = "agentMessage", id = "turn-2-agent", text = "Second turn", phase = "final_answer" },
})
turns:handle("turn/diff/updated", { turnId = "turn-2", diff = "second-turn diff" })
local first_diff, first_turn = turns:turn_diff_for_message(1)
local second_diff, second_turn = turns:turn_diff_for_message(2)
assert(
	first_diff == "final first-turn diff" and first_turn == "turn-1",
	"a turn should keep its latest cumulative diff"
)
assert(second_diff == "second-turn diff" and second_turn == "turn-2", "turn diffs must remain isolated")

local replay_turns = Session.new()
replay_turns:load({
	cwd = "/tmp/project",
	turns = {
		{ id = "replayed-turn", items = { { type = "agentMessage", id = "replayed", text = "Replay" } } },
	},
})
assert(replay_turns:messages()[1].turn_id == "replayed-turn", "replayed messages should keep their turn")
assert(replay_turns:cwd() == "/tmp/project", "the thread working directory should be retained")

print("session_spec: ok")
