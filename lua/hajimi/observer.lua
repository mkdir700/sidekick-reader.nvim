local Observer = {}
Observer.__index = Observer

function Observer.new(opts)
	opts = opts or {}
	return setmetatable({
		buffer = "",
		on_error = opts.on_error or function() end,
		on_event = opts.on_event or function() end,
		on_response = opts.on_response or function() end,
	}, Observer)
end

function Observer:start(url)
	local script = vim.api.nvim_get_runtime_file("scripts/bridge.mjs", false)[1]
	assert(script, "Hajimi bridge script is missing")
	self.process = vim.system({ "node", script, "observe", url }, {
		text = true,
		stdout = function(err, data)
			vim.schedule(function()
				if err then
					self.on_error(tostring(err))
				elseif data then
					self:feed(data)
				end
			end)
		end,
		stderr = function(_, data)
			if data and data ~= "" then
				vim.schedule(function()
					self.on_error(vim.trim(data))
				end)
			end
		end,
	}, function(result)
		if not self.stopping and result.code ~= 0 then
			vim.schedule(function()
				self.on_error("Hajimi observer stopped with exit code " .. result.code)
			end)
		end
	end)
end

function Observer:feed(chunk)
	self.buffer = self.buffer .. chunk
	while true do
		local newline = self.buffer:find("\n", 1, true)
		if not newline then
			return
		end
		local line = self.buffer:sub(1, newline - 1)
		self.buffer = self.buffer:sub(newline + 1)
		if line ~= "" then
			local ok, message = pcall(vim.json.decode, line)
			if not ok then
				self.on_error("Invalid Hajimi bridge event")
			elseif message.method then
				self.on_event(message.method, message.params or {})
			elseif message.result then
				self.on_response(message.result)
			end
		end
	end
end

function Observer:stop()
	self.stopping = true
	if self.process then
		self.process:kill(15)
		self.process = nil
	end
end

return Observer
