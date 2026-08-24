local Session = {}
Session.__index = Session

local function message_text(content)
	local parts = {}
	for _, part in ipairs(content or {}) do
		if part.type == "text" and part.text then
			parts[#parts + 1] = part.text
		end
	end
	return table.concat(parts, "\n")
end

function Session.new(opts)
	opts = opts or {}
	return setmetatable({
		by_id = {},
		on_change = opts.on_change or function() end,
		values = {},
	}, Session)
end

function Session:messages()
	return vim.deepcopy(self.values)
end

function Session:load(thread)
	self.by_id = {}
	self.values = {}
	for _, turn in ipairs(thread.turns or {}) do
		for _, item in ipairs(turn.items or {}) do
			self:handle("item/started", { item = item })
			if item.status or item.text then
				self:handle("item/completed", { item = item })
			end
		end
	end
	self.on_change(self.values)
end

function Session:_insert(id, message)
	if self.by_id[id] then
		return self.values[self.by_id[id]]
	end
	self.values[#self.values + 1] = message
	self.by_id[id] = #self.values
	return message
end

function Session:handle(method, params)
	local item = params.item
	local changed = false

	if method == "item/started" and item then
		if item.type == "userMessage" then
			self:_insert(item.id, { id = item.id, role = "user", text = message_text(item.content) })
			changed = true
		elseif item.type == "agentMessage" then
			self:_insert(item.id, { id = item.id, role = "assistant", text = item.text or "", phase = item.phase })
			changed = true
		elseif item.type == "commandExecution" then
			self:_insert(item.id, {
				id = item.id,
				role = "tool",
				kind = "command",
				command = item.command,
				cwd = item.cwd,
				output = item.aggregatedOutput or "",
				status = item.status,
			})
			changed = true
		end
	elseif method == "item/agentMessage/delta" then
		local index = self.by_id[params.itemId]
		if index then
			self.values[index].text = self.values[index].text .. params.delta
			changed = true
		end
	elseif method == "item/commandExecution/outputDelta" then
		local index = self.by_id[params.itemId]
		if index then
			self.values[index].output = self.values[index].output .. params.delta
			changed = true
		end
	elseif method == "item/completed" and item then
		local index = self.by_id[item.id]
		if index and item.type == "commandExecution" then
			local message = self.values[index]
			message.status = item.status
			message.exit_code = item.exitCode
			message.duration_ms = item.durationMs
			message.output = item.aggregatedOutput or message.output
			changed = true
		elseif index and item.type == "agentMessage" and item.text then
			self.values[index].text = item.text
			changed = true
		end
	end

	if changed then
		self.on_change(self.values)
	end
end

return Session
