for line in io.lines() do
	local message = vim.json.decode(line)

	if message.method == "initialize" then
		io.write(vim.json.encode({ id = message.id, result = { userAgent = "fake-codex" } }) .. "\n")
	elseif message.method == "thread/start" then
		io.write(vim.json.encode({ id = message.id, result = { thread = { id = "thread-test" } } }) .. "\n")
	elseif message.method == "thread/resume" then
		io.write(vim.json.encode({ id = message.id, result = { thread = { id = message.params.threadId } } }) .. "\n")
	elseif message.method == "turn/start" then
		io.write(
			vim.json.encode({ id = message.id, result = { turn = { id = "turn-test", status = "inProgress" } } })
				.. "\n"
		)
		io.write(vim.json.encode({
			method = "item/agentMessage/delta",
			params = { threadId = "thread-test", turnId = "turn-test", itemId = "item-test", delta = "hello " },
		}) .. "\n")
		io.write(vim.json.encode({
			method = "item/agentMessage/delta",
			params = { threadId = "thread-test", turnId = "turn-test", itemId = "item-test", delta = "world" },
		}) .. "\n")
		io.write(vim.json.encode({
			method = "turn/completed",
			params = { thread = { id = "thread-test" }, turn = { id = "turn-test", status = "completed" } },
		}) .. "\n")
	end

	io.flush()
end
