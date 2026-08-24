local Protocol = {}
Protocol.__index = Protocol

function Protocol.new(opts)
	opts = opts or {}

	return setmetatable({
		buffer = "",
		next_id = 1,
		pending = {},
		on_notification = opts.on_notification or function() end,
		on_error = opts.on_error or function() end,
	}, Protocol)
end

function Protocol:request(method, params, callback)
	local id = self.next_id
	self.next_id = id + 1
	self.pending[id] = callback

	return vim.json.encode({
		id = id,
		method = method,
		params = params or {},
	}) .. "\n"
end

function Protocol.notification(method, params)
	return vim.json.encode({
		method = method,
		params = params or {},
	}) .. "\n"
end

function Protocol:feed(chunk)
	self.buffer = self.buffer .. chunk

	while true do
		local newline = self.buffer:find("\n", 1, true)
		if not newline then
			return
		end

		local line = self.buffer:sub(1, newline - 1)
		self.buffer = self.buffer:sub(newline + 1)

		if line ~= "" then
			self:_dispatch(line)
		end
	end
end

function Protocol:_dispatch(line)
	local ok, message = pcall(vim.json.decode, line)
	if not ok then
		self.on_error("Invalid response from Codex: " .. message)
		return
	end

	if message.id ~= nil then
		local callback = self.pending[message.id]
		self.pending[message.id] = nil
		if callback then
			callback(message.error, message.result)
		end
		return
	end

	if message.method then
		self.on_notification(message.method, message.params or {})
	end
end

return Protocol
