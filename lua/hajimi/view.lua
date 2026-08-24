local M = {}

local role_labels = {
	assistant = "Assistant",
	user = "You",
}

local function message_lines(messages)
	local lines = {}
	local starts = {}

	for index, message in ipairs(messages) do
		starts[#starts + 1] = #lines + 1
		lines[#lines + 1] = role_labels[message.role] or message.role
		vim.list_extend(lines, vim.split(message.text, "\n", { plain = true }))

		if index < #messages then
			lines[#lines + 1] = ""
		end
	end

	return lines, starts
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
	vim.bo[buf].filetype = "hajimi"
	if not reuse then
		vim.api.nvim_buf_set_name(buf, "hajimi://conversation")
	end

	vim.wo[win].wrap = true
	vim.wo[win].linebreak = true
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"

	M.render(buf, opts.messages or {})

	return { buf = buf, win = win }
end

function M.render(buf, messages)
	local lines, starts = message_lines(messages)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.b[buf].hajimi_message_lines = starts
end

function M.jump(buf, direction)
	local starts = vim.b[buf].hajimi_message_lines or {}
	if #starts == 0 then
		return
	end

	local current = vim.api.nvim_win_get_cursor(0)[1]
	local target
	if direction > 0 then
		for _, line in ipairs(starts) do
			if line > current then
				target = line
				break
			end
		end
		target = target or starts[1]
	else
		for index = #starts, 1, -1 do
			if starts[index] < current then
				target = starts[index]
				break
			end
		end
		target = target or starts[#starts]
	end

	vim.api.nvim_win_set_cursor(0, { target, 0 })
end

return M
