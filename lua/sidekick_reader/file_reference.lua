local M = {}

local function file_path(value, cwd)
	value = value:gsub("^<", ""):gsub(">$", "")
	local path, line, column = value:match("^(.-):(%d+):(%d+)$")
	if not path then
		path, line = value:match("^(.-):(%d+)$")
	end
	path = path or value
	if path == "" then
		return
	end
	if vim.fn.isabsolutepath(path) == 0 then
		path = vim.fs.joinpath(cwd, path)
	end
	path = vim.fs.normalize(path)
	local stat = (vim.uv or vim.loop).fs_stat(path)
	if not stat or stat.type ~= "file" then
		return
	end
	return { path = path, line = tonumber(line) or 1, column = tonumber(column) or 1 }
end

function M.resolve(text, column, cwd)
	local byte = column + 1
	local search = 1
	while true do
		local start_at, end_at, _, target = text:find("%[([^%]]-)%]%(([^%)]+)%)", search)
		if not start_at then
			break
		end
		if byte >= start_at and byte <= end_at then
			return file_path(target, cwd)
		end
		search = end_at + 1
	end

	local function is_path_character(char)
		return char:match("[%w_%.%-%/\\~:]") ~= nil
	end
	if not is_path_character(text:sub(byte, byte)) then
		return
	end
	local first, last = byte, byte
	while first > 1 and is_path_character(text:sub(first - 1, first - 1)) do
		first = first - 1
	end
	while last < #text and is_path_character(text:sub(last + 1, last + 1)) do
		last = last + 1
	end
	return file_path(text:sub(first, last), cwd)
end

local function left_window(reader_win)
	local reader_position = vim.api.nvim_win_get_position(reader_win)
	local best, best_column, best_distance
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local config = vim.api.nvim_win_get_config(win)
		local buf = vim.api.nvim_win_get_buf(win)
		local position = vim.api.nvim_win_get_position(win)
		local column = position[2]
		local distance = math.abs(position[1] - reader_position[1])
		if
			win ~= reader_win
			and config.relative == ""
			and column < reader_position[2]
			and vim.bo[buf].buftype ~= "terminal"
			and vim.bo[buf].filetype ~= "sidekick-reader"
			and (not best or column > best_column or (column == best_column and distance < best_distance))
		then
			best, best_column, best_distance = win, column, distance
		end
	end
	return best
end

function M.open_in_left(reference, reader_win)
	local win = left_window(reader_win)
	if not win then
		return nil, "No editor window is available to the left of Sidekick Reader"
	end
	vim.api.nvim_set_current_win(win)
	vim.cmd.edit({ args = { reference.path } })
	local line = math.min(math.max(reference.line or 1, 1), vim.api.nvim_buf_line_count(0))
	local value = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1] or ""
	local column = math.min(math.max((reference.column or 1) - 1, 0), #value)
	vim.api.nvim_win_set_cursor(win, { line, column })
	return true
end

function M.open_under_cursor(reader_win)
	local cursor = vim.api.nvim_win_get_cursor(reader_win)
	local text = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(reader_win), cursor[1] - 1, cursor[1], false)[1]
	local cwd = vim.api.nvim_win_call(reader_win, vim.fn.getcwd)
	local reference = M.resolve(text or "", cursor[2], cwd)
	if not reference then
		return nil, "No readable file reference under the cursor"
	end
	return M.open_in_left(reference, reader_win)
end

return M
