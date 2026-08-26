local M = {}
local ns = vim.api.nvim_create_namespace("sidekick_reader_view")
local timers = {}
local layouts = {}

local labels = { user = "You", assistant = "Sidekick Reader", tool = "Command" }

local function text(value)
	return type(value) == "string" and value or ""
end

local function content(message)
	if message.kind == "file_change" then
		local lines = {}
		for index, change in ipairs(message.changes or {}) do
			local kind = text(change.kind)
			lines[#lines + 1] = kind ~= "" and (kind .. "  " .. text(change.path)) or text(change.path)
			local diff = text(change.diff)
			if diff ~= "" then
				local diff_lines = vim.split(diff, "\n", { plain = true })
				if kind == "add" or kind == "delete" then
					local prefix = kind == "add" and "+" or "-"
					for line_index, line in ipairs(diff_lines) do
						diff_lines[line_index] = prefix .. line
					end
				end
				vim.list_extend(lines, diff_lines)
			end
			if index < #(message.changes or {}) then
				lines[#lines + 1] = ""
			end
		end
		return #lines > 0 and lines or { "Waiting for file changes" }
	end
	if message.role == "tool" then
		local lines = vim.split(text(message.command), "\n", { plain = true })
		local output = text(message.output)
		if output ~= "" then
			vim.list_extend(lines, vim.split(output, "\n", { plain = true, trimempty = true }))
		end
		return lines
	end
	return vim.split(text(message.text), "\n", { plain = true })
end

local function tool_label(message)
	if message.kind == "file_change" then
		local count = #(message.changes or {})
		local state = message.status == "completed" and "done" or message.status == "failed" and "failed" or "running"
		return ("Files  %s  (%d)"):format(state, count)
	end
	local done = message.status == "completed"
	return done and ((message.exit_code or 0) == 0 and "Command  done" or "Command  failed") or "Command  running"
end

local function build(messages)
	local lines, starts, decorations, folds = { "" }, {}, {}, {}
	for index, message in ipairs(messages) do
		local start = #lines + 1
		starts[#starts + 1] = start
		vim.list_extend(lines, content(message))
		local label = labels[message.role] or message.role
		if message.role == "tool" then
			label = tool_label(message)
		end
		local item = {
			line = start,
			finish = #lines,
			role = message.role,
			kind = message.kind,
			label = label,
			index = index,
		}
		decorations[#decorations + 1] = item
		if message.kind == "command" then
			folds[#folds + 1] = item
		end
		if index < #messages then
			lines[#lines + 1] = ""
		end
	end
	return lines, starts, decorations, folds
end

local function highlights()
	local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
	local cursor = vim.api.nvim_get_hl(0, { name = "CursorLine", link = false })
	local user = vim.api.nvim_get_hl(0, { name = "DiagnosticInfo", link = false })
	local assistant = vim.api.nvim_get_hl(0, { name = "Function", link = false })
	local tool = vim.api.nvim_get_hl(0, { name = "DiagnosticWarn", link = false })
	local header_bg = cursor.bg or normal.bg
	vim.api.nvim_set_hl(0, "SidekickReaderUser", { fg = user.fg, bg = header_bg, bold = true })
	vim.api.nvim_set_hl(0, "SidekickReaderAssistant", { fg = assistant.fg, bg = header_bg, bold = true })
	vim.api.nvim_set_hl(0, "SidekickReaderTool", { fg = tool.fg, bg = header_bg, bold = true })
	vim.api.nvim_set_hl(0, "SidekickReaderMuted", { link = "Comment", default = true })
end

local function decoration(buf, item, width)
	local group = item.role == "user" and "SidekickReaderUser"
		or item.role == "tool" and "SidekickReaderTool"
		or "SidekickReaderAssistant"
	local title = "  " .. item.label
	local padding = string.rep(" ", math.max(width - vim.fn.strdisplaywidth(title), 1))
	item.marks = {
		vim.api.nvim_buf_set_extmark(buf, ns, item.line - 1, 0, {
			virt_lines = { { { title .. padding, group } } },
			virt_lines_above = true,
		}),
	}
	if item.kind == "command" then
		item.marks[#item.marks + 1] = vim.api.nvim_buf_set_extmark(buf, ns, item.line - 1, 0, {
			virt_text = { { "$ ", "SidekickReaderTool" } },
			virt_text_pos = "inline",
		})
	elseif item.kind == "file_change" then
		for line = item.line, item.finish do
			local value = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1] or ""
			local line_group = value:match("^%+[^+]") and "DiffAdd"
				or value:match("^%-[^-]") and "DiffDelete"
				or value:match("^@@") and "DiffChange"
			if line_group then
				item.marks[#item.marks + 1] = vim.api.nvim_buf_set_extmark(buf, ns, line - 1, 0, {
					line_hl_group = line_group,
				})
			end
		end
	end
end

local function apply_folds(buf)
	local layout = layouts[buf]
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		vim.wo[win].foldmethod = "manual"
		vim.api.nvim_win_call(win, function()
			vim.cmd("silent! normal! zE")
			for _, range in ipairs(layout and layout.folds or {}) do
				if range.finish > range.line then
					vim.cmd(("silent! %d,%dfold"):format(range.line, range.finish))
					vim.cmd(("silent! %dfoldclose"):format(range.line))
				end
			end
		end)
	end
end

function M.attach(buf, win)
	highlights()
	vim.b[buf].sidekick_reader_view = true
	vim.wo[win].wrap = true
	vim.wo[win].linebreak = true
	vim.wo[win].breakindent = true
	vim.wo[win].showbreak = "  "
	vim.wo[win].smoothscroll = true
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].fillchars = "eob: "
	vim.wo[win].winhighlight = "Normal:Normal,WinBar:Normal"
	vim.wo[win].winbar = "%#Title#  Sidekick Reader%*%=%#Comment#Ready  %*"
end

function M.open(opts)
	opts = opts or {}
	local reuse = opts.buf and vim.api.nvim_buf_is_valid(opts.buf)
	if reuse then
		vim.cmd("botright vsplit")
	else
		vim.cmd("botright vnew")
	end
	local win = vim.api.nvim_get_current_win()
	local buf = reuse and opts.buf or vim.api.nvim_get_current_buf()
	if reuse then
		vim.api.nvim_win_set_buf(win, buf)
	end

	vim.api.nvim_win_set_width(win, opts.width or 60)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "sidekick-reader"
	if not reuse then
		vim.api.nvim_buf_set_name(buf, "sidekick-reader://conversation")
	end
	M.attach(buf, win)
	M.render(buf, opts.messages or {})
	return { buf = buf, win = win }
end

function M.render(buf, messages)
	local lines, starts, decorations, folds = build(messages)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.b[buf].sidekick_reader_message_lines = starts
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	local wins = vim.fn.win_findbuf(buf)
	local width = #wins > 0 and vim.api.nvim_win_get_width(wins[1]) or 60
	for _, item in ipairs(decorations) do
		decoration(buf, item, width)
	end
	layouts[buf] = { count = #messages, ranges = decorations, folds = folds }
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		vim.wo[win].wrap = true
		vim.wo[win].linebreak = true
		vim.wo[win].breakindent = true
		vim.wo[win].showbreak = "  "
	end
	apply_folds(buf)
end

function M.update(buf, messages, change)
	local layout = layouts[buf]
	if not layout or not change or change.type == "reset" then
		return M.render(buf, messages)
	end
	local message = messages[change.index]
	if not message then
		return
	end
	local lines = content(message)
	local wins = vim.fn.win_findbuf(buf)
	local width = #wins > 0 and vim.api.nvim_win_get_width(wins[1]) or 60

	if change.type == "append" and change.index == layout.count + 1 then
		local old_count = vim.api.nvim_buf_line_count(buf)
		local appended = { "" }
		vim.list_extend(appended, lines)
		vim.bo[buf].modifiable = true
		vim.api.nvim_buf_set_lines(buf, old_count, old_count, false, appended)
		vim.bo[buf].modifiable = false
		local item = {
			line = old_count + 2,
			finish = old_count + 1 + #lines,
			role = message.role,
			kind = message.kind,
			label = labels[message.role] or message.role,
			index = change.index,
		}
		if message.role == "tool" then
			item.label = tool_label(message)
		end
		decoration(buf, item, width)
		layout.count = change.index
		layout.ranges[change.index] = item
		if message.kind == "command" then
			layout.folds[#layout.folds + 1] = item
			apply_folds(buf)
		end
		local starts = vim.b[buf].sidekick_reader_message_lines or {}
		starts[#starts + 1] = item.line
		vim.b[buf].sidekick_reader_message_lines = starts
		return
	end

	if change.type == "update" and change.index == layout.count then
		local item = layout.ranges[change.index]
		vim.bo[buf].modifiable = true
		vim.api.nvim_buf_set_lines(buf, item.line - 1, item.finish, false, lines)
		vim.bo[buf].modifiable = false
		for _, mark in ipairs(item.marks or {}) do
			pcall(vim.api.nvim_buf_del_extmark, buf, ns, mark)
		end
		item.finish = item.line - 1 + #lines
		if message.role == "tool" then
			item.label = tool_label(message)
		end
		decoration(buf, item, width)
		if message.kind == "command" then
			apply_folds(buf)
		end
		return
	end

	M.render(buf, messages)
end

function M.set_status(buf, win, status)
	local old = timers[buf]
	if old then
		old:stop()
		old:close()
		timers[buf] = nil
	end
	if not vim.api.nvim_win_is_valid(win) then
		return
	end
	local unread = status and status.unread
	if status and status.type == "active" then
		local frames, index = { "-", "\\", "|", "/" }, 1
		local timer = assert((vim.uv or vim.loop).new_timer())
		timers[buf] = timer
		timer:start(
			0,
			120,
			vim.schedule_wrap(function()
				if not vim.api.nvim_win_is_valid(win) then
					timer:stop()
					return
				end
				local suffix = unread and " · New output" or ""
				vim.wo[win].winbar = "%#Title#  Sidekick Reader%*%=%#DiagnosticInfo#"
					.. frames[index]
					.. " Working"
					.. suffix
					.. "  %*"
				index = index % #frames + 1
			end)
		)
	else
		local label = unread and "New output" or "Ready"
		vim.wo[win].winbar = "%#Title#  Sidekick Reader%*%=%#Comment#" .. label .. "  %*"
	end
end

function M.latest_start(buf)
	local starts = vim.b[buf].sidekick_reader_message_lines or {}
	return starts[#starts] or 1
end

function M.message_index(buf, line)
	local layout = layouts[buf]
	if not layout or #layout.ranges == 0 then
		return
	end
	for index, item in ipairs(layout.ranges) do
		local next_item = layout.ranges[index + 1]
		if line <= item.finish or not next_item or line < next_item.line then
			return item.index
		end
	end
end

function M.follow(buf, win)
	if not (vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_win_is_valid(win)) then
		return
	end
	if vim.api.nvim_win_get_buf(win) ~= buf then
		return
	end
	local line = math.max(vim.api.nvim_buf_line_count(buf), 1)
	local value = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1] or ""
	vim.api.nvim_win_set_cursor(win, { line, math.max(#value - 1, 0) })
	vim.api.nvim_win_call(win, function()
		vim.cmd("silent! normal! zb")
	end)
end

function M.jump(buf, direction)
	local starts = vim.b[buf].sidekick_reader_message_lines or {}
	if #starts == 0 then
		return
	end
	local current, target = vim.api.nvim_win_get_cursor(0)[1]
	if direction > 0 then
		for _, line in ipairs(starts) do
			if line > current then
				target = line
				break
			end
		end
		target = target or starts[1]
	else
		for i = #starts, 1, -1 do
			if starts[i] < current then
				target = starts[i]
				break
			end
		end
		target = target or starts[#starts]
	end
	vim.api.nvim_win_set_cursor(0, { target, 0 })
end

function M.jump_edge(buf, edge)
	local starts = vim.b[buf].sidekick_reader_message_lines or {}
	if #starts == 0 then
		return
	end
	local target = edge == "first" and starts[1] or starts[#starts]
	vim.api.nvim_win_set_cursor(0, { target, 0 })
end

return M
