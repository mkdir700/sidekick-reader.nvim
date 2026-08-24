local Observer = require("hajimi.observer")
local Registry = require("hajimi.registry")
local Session = require("hajimi.session")
local View = require("hajimi.view")

local Reader = {}
Reader.__index = Reader

function Reader.new(opts)
	opts = opts or {}
	return setmetatable({
		observer_factory = opts.observer_factory or Observer.new,
		registry = opts.registry or Registry,
		registry_dir = opts.registry_dir,
		states = {},
		width = opts.width or 60,
	}, Reader)
end

function Reader:toggle(pane_id, win)
	win = win or vim.api.nvim_get_current_win()
	local state = self.states[pane_id]
	if state and vim.api.nvim_win_get_buf(win) == state.buf then
		vim.api.nvim_win_set_buf(win, state.origin_buf)
		return false
	end

	if not state then
		local entry = self.registry.read(self.registry_dir, pane_id)
		if not entry then
			return nil, "No Hajimi session is registered for this Sidekick pane"
		end

		local origin_buf = vim.api.nvim_win_get_buf(win)
		local buf = vim.api.nvim_create_buf(false, true)
		vim.bo[buf].buftype = "nofile"
		vim.bo[buf].bufhidden = "hide"
		vim.bo[buf].swapfile = false
		vim.bo[buf].filetype = "hajimi"
		vim.b[buf].hajimi_pane_id = pane_id
		vim.api.nvim_buf_set_name(buf, "hajimi://" .. pane_id)

		state = { buf = buf, origin_buf = origin_buf, pane_id = pane_id, win = win }
		state.session = Session.new({
			on_change = function(messages)
				if vim.api.nvim_buf_is_valid(buf) then
					View.render(buf, messages)
				end
			end,
		})
		state.observer = self.observer_factory({
			on_event = function(method, params)
				state.session:handle(method, params)
			end,
			on_error = function(err)
				vim.notify("Hajimi: " .. err, vim.log.levels.ERROR)
			end,
			on_response = function(result)
				if result.thread then
					state.session:load(result.thread)
				end
			end,
		})
		state.observer:start(entry.url)
		self.states[pane_id] = state

		vim.keymap.set("n", "q", function()
			self:toggle(pane_id, win)
		end, { buffer = buf, desc = "Return to Sidekick" })
		vim.keymap.set("n", "<C-]>", function()
			self:toggle(pane_id, win)
		end, { buffer = buf, desc = "Return to Sidekick" })
	end

	state.win = win
	vim.api.nvim_win_set_buf(win, state.buf)
	vim.wo[win].wrap = true
	vim.wo[win].linebreak = true
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	return true
end

return Reader
