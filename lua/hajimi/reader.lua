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
		local cursor = vim.api.nvim_win_get_cursor(win)[1]
		if cursor >= vim.api.nvim_buf_line_count(state.buf) then
			state.follow = true
			state.saved_view = nil
		elseif cursor < View.latest_start(state.buf) then
			state.follow = false
		end
		if not state.follow then
			state.saved_view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
		end
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

		state = { buf = buf, origin_buf = origin_buf, pane_id = pane_id, win = win, follow = true }
		state.session = Session.new({
			on_change = function(messages, change)
				if vim.api.nvim_buf_is_valid(buf) then
					local visible = vim.api.nvim_win_is_valid(state.win) and vim.api.nvim_win_get_buf(state.win) == buf
					local saved = visible and not state.follow and vim.api.nvim_win_call(state.win, vim.fn.winsaveview)
						or nil
					View.update(buf, messages, change)
					if state.follow and visible then
						View.follow(buf, state.win)
					elseif not state.follow then
						state.unread = true
						if saved then
							vim.api.nvim_win_call(state.win, function()
								vim.fn.winrestview(saved)
							end)
							state.saved_view = saved
						end
						local status = vim.tbl_extend("force", {}, state.status or { type = "idle" }, { unread = true })
						View.set_status(buf, state.win or win, status)
					end
				end
			end,
			on_status = function(status)
				state.status = status
				local shown = vim.tbl_extend("force", {}, status, { unread = state.unread or false })
				View.set_status(buf, state.win or win, shown)
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
		vim.keymap.set("n", "<C-j>", function()
			View.jump(buf, 1)
		end, { buffer = buf, desc = "Next Hajimi message" })
		vim.keymap.set("n", "<C-k>", function()
			View.jump(buf, -1)
		end, { buffer = buf, desc = "Previous Hajimi message" })
		vim.keymap.set("n", "<C-f>", function()
			state.follow = true
			state.unread = false
			state.saved_view = nil
			View.set_status(
				buf,
				win,
				vim.tbl_extend("force", {}, state.status or { type = "idle" }, { unread = false })
			)
			View.follow(buf, win)
		end, { buffer = buf, desc = "Follow Latest Hajimi Message" })
		vim.api.nvim_create_autocmd("CursorMoved", {
			buffer = buf,
			callback = function()
				local cursor = vim.api.nvim_win_get_cursor(0)[1]
				if cursor >= vim.api.nvim_buf_line_count(buf) then
					state.follow = true
					state.unread = false
					state.saved_view = nil
					View.set_status(
						buf,
						state.win or win,
						vim.tbl_extend("force", {}, state.status or { type = "idle" }, { unread = false })
					)
				elseif state.follow and cursor < View.latest_start(buf) then
					state.follow = false
					state.saved_view = vim.fn.winsaveview()
				end
			end,
		})
	end

	state.win = win
	vim.api.nvim_win_set_buf(win, state.buf)
	View.attach(state.buf, win)
	if state.follow then
		View.follow(state.buf, win)
	elseif state.saved_view then
		vim.api.nvim_win_call(win, function()
			vim.fn.winrestview(state.saved_view)
		end)
	end
	return true
end

return Reader
