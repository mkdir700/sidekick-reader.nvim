local App = {}
App.__index = App

function App.new(opts)
	opts = opts or {}

	return setmetatable({
		cwd = opts.cwd or vim.fn.getcwd(),
		view = opts.view or require("hajimi.view"),
		provider_factory = opts.provider_factory or function(provider_opts)
			return require("hajimi.providers.codex.client").new(provider_opts)
		end,
		conversation = {},
	}, App)
end

function App:open(opts)
	opts = opts or {}

	if self.surface and vim.api.nvim_win_is_valid(self.surface.win) then
		vim.api.nvim_set_current_win(self.surface.win)
		return self.surface
	end

	opts.buf = self.surface and self.surface.buf or nil
	opts.messages = self.conversation
	self.surface = self.view.open(opts)
	return self.surface
end

function App:ask(text, callback)
	callback = callback or function() end
	if not text or vim.trim(text) == "" then
		callback("Message cannot be empty")
		return
	end

	self.conversation[#self.conversation + 1] = { role = "user", text = text }
	self.conversation[#self.conversation + 1] = { role = "assistant", text = "" }
	self.active_reply = #self.conversation
	self.active_item_id = nil
	self:_render()

	self:_connect(function(err)
		if err then
			callback(err)
			return
		end

		self.provider:send(text, function(send_err)
			self.active_reply = nil
			self.active_item_id = nil
			callback(send_err)
		end)
	end)
end

function App:messages()
	return vim.deepcopy(self.conversation)
end

function App:thread_id()
	return self.provider and self.provider:thread_id() or nil
end

function App:_connect(callback)
	if self.provider then
		callback(nil)
		return
	end

	self.provider = self.provider_factory({
		cwd = self.cwd,
		on_delta = function(delta, event)
			if self.active_reply then
				local item_id = event and event.itemId
				if item_id and self.active_item_id and item_id ~= self.active_item_id then
					self.conversation[#self.conversation + 1] = { role = "assistant", text = "" }
					self.active_reply = #self.conversation
				end
				self.active_item_id = item_id or self.active_item_id
				local message = self.conversation[self.active_reply]
				message.text = message.text .. delta
				self:_render()
			end
		end,
		on_error = function(err)
			vim.notify("Hajimi: " .. err, vim.log.levels.ERROR)
		end,
	})

	self.provider:start(callback)
end

function App:_render()
	if self.surface and vim.api.nvim_buf_is_valid(self.surface.buf) then
		self.view.render(self.surface.buf, self.conversation)
	end
end

return App
