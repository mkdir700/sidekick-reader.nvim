local Protocol = require("hajimi.providers.codex.protocol")

local Client = {}
Client.__index = Client

function Client.new(opts)
	opts = opts or {}
	local self = setmetatable({
		cmd = opts.cmd or { "codex", "app-server", "--stdio" },
		cwd = opts.cwd or vim.fn.getcwd(),
		on_delta = opts.on_delta or function() end,
		on_error = opts.on_error or function() end,
		_thread_id = opts.thread_id,
		_initialized = false,
		_stopping = false,
	}, Client)

	self.protocol = Protocol.new({
		on_notification = function(method, params)
			self:_on_notification(method, params)
		end,
		on_error = self.on_error,
	})

	return self
end

function Client:start(callback)
	callback = callback or function() end

	self.process = vim.system(self.cmd, {
		cwd = self.cwd,
		stdin = true,
		text = true,
		stdout = function(err, data)
			vim.schedule(function()
				if err then
					self.on_error("Could not read from Codex: " .. err)
				elseif data then
					self.protocol:feed(data)
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
		if not self._stopping and result.code ~= 0 then
			vim.schedule(function()
				self.on_error("Codex stopped unexpectedly with exit code " .. result.code)
			end)
		end
	end)

	self:_write(self.protocol:request("initialize", {
		clientInfo = {
			name = "hajimi.nvim",
			title = "Hajimi",
			version = "0.1.0",
		},
	}, function(err)
		if err then
			callback(err)
			return
		end

		self:_write(Protocol.notification("initialized", {}))
		self._initialized = true
		callback(nil)
	end))
end

function Client:send(text, callback)
	callback = callback or function() end
	if not self._initialized then
		callback("Codex is not connected")
		return
	end

	local function start_turn()
		self._turn_callback = callback
		self:_write(self.protocol:request("turn/start", {
			threadId = self._thread_id,
			input = { { type = "text", text = text } },
			cwd = self.cwd,
		}, function(err)
			if err and self._turn_callback then
				local turn_callback = self._turn_callback
				self._turn_callback = nil
				turn_callback(err)
			end
		end))
	end

	if self._thread_id then
		start_turn()
		return
	end

	self:_write(self.protocol:request("thread/start", { cwd = self.cwd }, function(err, result)
		if err then
			callback(err)
			return
		end

		self._thread_id = result.thread.id
		start_turn()
	end))
end

function Client:thread_id()
	return self._thread_id
end

function Client:stop()
	self._stopping = true
	if self.process then
		self.process:kill(15)
		self.process = nil
	end
end

function Client:_write(message)
	self.process:write(message)
end

function Client:_on_notification(method, params)
	if method == "item/agentMessage/delta" then
		self.on_delta(params.delta, params)
		return
	end

	if method == "turn/completed" and self._turn_callback then
		local callback = self._turn_callback
		self._turn_callback = nil

		if params.turn and params.turn.status == "failed" then
			callback((params.turn.error and params.turn.error.message) or "Codex turn failed")
		else
			callback(nil)
		end
	end
end

return Client
