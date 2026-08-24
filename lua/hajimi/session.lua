local Session = {}
Session.__index = Session

local function text(value)
	return type(value) == "string" and value or ""
end

local function message_text(content)
	local parts = {}
	for _, part in ipairs(content or {}) do
		if part.type == "text" and type(part.text) == "string" then
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
		on_status = opts.on_status or function() end,
		values = {},
	}, Session)
end

function Session:messages()
	return vim.deepcopy(self.values)
end

function Session:load(thread)
	self.loading = true
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
	self.loading = false
	self.on_change(self.values, { type = "reset" })
end

function Session:_insert(id, message)
	if self.by_id[id] then
		local index = self.by_id[id]
		return self.values[index], index, false
	end
	self.values[#self.values + 1] = message
	self.by_id[id] = #self.values
	return message, #self.values, true
end

function Session:handle(method, params)
	if method == "thread/status/changed" then
		self.on_status(params.status or {})
		return
	end
	local item = params.item
	local change

	if method == "item/started" and item then
		if item.type == "userMessage" then
			local _, index, added =
				self:_insert(item.id, { id = item.id, role = "user", text = message_text(item.content) })
			change = { type = added and "append" or "update", index = index }
		elseif item.type == "agentMessage" then
			local _, index, added =
				self:_insert(item.id, { id = item.id, role = "assistant", text = text(item.text), phase = item.phase })
			change = { type = added and "append" or "update", index = index }
		elseif item.type == "commandExecution" then
			local _, index, added = self:_insert(item.id, {
				id = item.id,
				role = "tool",
				kind = "command",
				command = text(item.command),
				cwd = item.cwd,
				output = text(item.aggregatedOutput),
				status = item.status,
			})
			change = { type = added and "append" or "update", index = index }
		end
	elseif method == "item/agentMessage/delta" then
		local index = self.by_id[params.itemId]
		if index then
			self.values[index].text = self.values[index].text .. text(params.delta)
			change = { type = "update", index = index }
		end
	elseif method == "item/commandExecution/outputDelta" then
		local index = self.by_id[params.itemId]
		if index then
			self.values[index].output = self.values[index].output .. text(params.delta)
			change = { type = "update", index = index }
		end
	elseif method == "item/completed" and item then
		local index = self.by_id[item.id]
		if index and item.type == "commandExecution" then
			local message = self.values[index]
			message.status = item.status
			message.exit_code = item.exitCode
			message.duration_ms = item.durationMs
			if type(item.aggregatedOutput) == "string" then
				message.output = item.aggregatedOutput
			end
			change = { type = "update", index = index }
		elseif index and item.type == "agentMessage" and type(item.text) == "string" then
			self.values[index].text = item.text
			change = { type = "update", index = index }
		end
	end

	if change and not self.loading then
		self.on_change(self.values, change)
	end
end

return Session
