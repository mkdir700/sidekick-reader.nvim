local Observer = require("sidekick_reader.observer")
local FileReference = require("sidekick_reader.file_reference")
local Registry = require("sidekick_reader.registry")
local Session = require("sidekick_reader.session")
local View = require("sidekick_reader.view")

local Reader = {}
Reader.__index = Reader

function Reader.new(opts)
	opts = opts or {}
	return setmetatable({
		observer_factory = opts.observer_factory or Observer.new,
		layout = opts.layout or "replace",
		registry = opts.registry or Registry,
		registry_dir = opts.registry_dir,
		states = {},
		viewer_ratio = opts.viewer_ratio or 0.8,
		width = opts.width or 60,
	}, Reader)
end

local function is_visible(state)
	return state
		and (
			(state.split and state.split.winid and vim.api.nvim_win_is_valid(state.split.winid))
			or (state.win and vim.api.nvim_win_is_valid(state.win) and vim.api.nvim_win_get_buf(state.win) == state.buf)
		)
end

function Reader:show(pane_id, win, terminal)
	local current = vim.api.nvim_get_current_win()
	local state = self.states[pane_id]
	if state then
		state.terminal = terminal or state.terminal
		state.terminal_win = win or state.terminal_win
	end
	if not is_visible(state) then
		local ok, err = self:toggle(pane_id, win)
		if not ok then
			return ok, err
		end
		state = self.states[pane_id]
		state.terminal = terminal or state.terminal
		state.terminal_win = win or state.terminal_win
	end
	if vim.api.nvim_win_is_valid(current) then
		vim.api.nvim_set_current_win(current)
	end
	return true
end

function Reader:focus(pane_id, win, terminal)
	local ok, err = self:show(pane_id, win, terminal)
	if not ok then
		return ok, err
	end
	local state = self.states[pane_id]
	if state and is_visible(state) then
		vim.api.nvim_set_current_win(state.win)
	end
	return true
end

function Reader:hide(pane_id)
	local state = self.states[pane_id]
	if is_visible(state) then
		self:toggle(pane_id, state.win)
	end
end

function Reader:close(pane_id)
	local state = self.states[pane_id]
	if not state then
		return
	end
	self:hide(pane_id)
	if state.observer and state.observer.stop then
		state.observer:stop()
	end
	if state.split then
		state.split:unmount()
	elseif vim.api.nvim_buf_is_valid(state.buf) then
		vim.api.nvim_buf_delete(state.buf, { force = true })
	end
	self.states[pane_id] = nil
end

function Reader:toggle(pane_id, win)
	win = win or vim.api.nvim_get_current_win()
	local state = self.states[pane_id]
	local split_visible = state and state.split and state.split.winid and vim.api.nvim_win_is_valid(state.split.winid)
	if state and (split_visible or vim.api.nvim_win_get_buf(win) == state.buf) then
		local reader_win = split_visible and state.split.winid or win
		local cursor = vim.api.nvim_win_get_cursor(reader_win)[1]
		if cursor >= vim.api.nvim_buf_line_count(state.buf) then
			state.follow = true
			state.saved_view = nil
		elseif cursor < View.latest_start(state.buf) then
			state.follow = false
		end
		if not state.follow then
			state.saved_view = vim.api.nvim_win_call(reader_win, vim.fn.winsaveview)
		end
		if state.split then
			state.split:hide()
			if vim.api.nvim_win_is_valid(state.terminal_win) then
				vim.api.nvim_set_current_win(state.terminal_win)
			end
		else
			vim.api.nvim_win_set_buf(win, state.origin_buf)
		end
		return false
	end
	if state and state.split then
		state.split:update_layout({
			relative = { type = "win", winid = state.terminal_win },
			position = "top",
			size = (self.viewer_ratio * 100) .. "%",
		})
		state.split:show()
		state.win = state.split.winid
		View.attach(state.buf, state.win)
		if state.follow then
			View.follow(state.buf, state.win)
		end
		return true
	end

	if not state then
		local entry = self.registry.read(self.registry_dir, pane_id)
		if not entry then
			return nil, "No Sidekick Reader session is registered for this Sidekick pane"
		end

		local origin_buf = vim.api.nvim_win_get_buf(win)
		local split
		local buf
		local viewer_win = win
		if self.layout == "stacked" then
			local Split = require("nui.split")
			split = Split({
				relative = { type = "win", winid = win },
				position = "top",
				size = (self.viewer_ratio * 100) .. "%",
				enter = true,
			})
			split:mount()
			buf = split.bufnr
			viewer_win = split.winid
		else
			buf = vim.api.nvim_create_buf(false, true)
		end
		vim.bo[buf].buftype = "nofile"
		vim.bo[buf].bufhidden = "hide"
		vim.bo[buf].swapfile = false
		vim.bo[buf].filetype = "sidekick-reader"
		vim.b[buf].sidekick_reader_pane_id = pane_id
		vim.api.nvim_buf_set_name(buf, "sidekick-reader://" .. pane_id)

		state = {
			buf = buf,
			origin_buf = origin_buf,
			pane_id = pane_id,
			win = viewer_win,
			terminal_win = win,
			split = split,
			follow = true,
		}
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
				vim.notify("Sidekick Reader: " .. err, vim.log.levels.ERROR)
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
			if state.terminal and state.terminal.hide then
				state.terminal:hide()
			else
				self:hide(pane_id)
			end
		end, { buffer = buf, desc = "Hide Sidekick workspace" })
		vim.keymap.set("n", "<C-]>", function()
			if state.terminal and state.terminal.focus then
				state.terminal:focus()
			end
		end, { buffer = buf, desc = "Focus Sidekick input" })
		vim.keymap.set("n", "i", function()
			if state.terminal and state.terminal.focus then
				state.terminal:focus()
			end
		end, { buffer = buf, desc = "Focus Sidekick input" })
		vim.keymap.set("n", "]m", function()
			View.jump(buf, 1)
		end, { buffer = buf, desc = "Next Sidekick Reader message" })
		vim.keymap.set("n", "[m", function()
			View.jump(buf, -1)
		end, { buffer = buf, desc = "Previous Sidekick Reader message" })
		vim.keymap.set("n", "]g", function()
			View.jump_edge(buf, "last")
		end, { buffer = buf, desc = "Last Sidekick Reader message" })
		vim.keymap.set("n", "[g", function()
			View.jump_edge(buf, "first")
		end, { buffer = buf, desc = "First Sidekick Reader message" })
		vim.keymap.set("n", "gf", function()
			local ok, err = FileReference.open_under_cursor(state.win)
			if not ok then
				vim.notify("Sidekick Reader: " .. err, vim.log.levels.WARN)
			end
		end, { buffer = buf, desc = "Open file reference on the left" })
		vim.keymap.set("n", "G", function()
			state.follow = true
			state.unread = false
			state.saved_view = nil
			View.set_status(
				buf,
				state.win,
				vim.tbl_extend("force", {}, state.status or { type = "idle" }, { unread = false })
			)
			View.follow(buf, state.win)
		end, { buffer = buf, desc = "Follow Latest Sidekick Reader Message" })
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
		if split then
			vim.api.nvim_create_autocmd("VimResized", {
				callback = function()
					if vim.api.nvim_win_is_valid(state.terminal_win) then
						split:update_layout({
							relative = { type = "win", winid = state.terminal_win },
							position = "top",
							size = (self.viewer_ratio * 100) .. "%",
						})
					end
				end,
			})
		end
	end

	state.win = state.split and state.split.winid or win
	vim.api.nvim_win_set_buf(state.win, state.buf)
	View.attach(state.buf, state.win)
	if state.follow then
		View.follow(state.buf, state.win)
	elseif state.saved_view then
		vim.api.nvim_win_call(state.win, function()
			vim.fn.winrestview(state.saved_view)
		end)
	end
	return true
end

return Reader
