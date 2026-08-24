local M = {}

function M.read(dir, pane_id)
	if not dir or not pane_id then
		return nil
	end

	local path = vim.fs.joinpath(dir, pane_id .. ".json")
	if not (vim.uv or vim.loop).fs_stat(path) then
		return nil
	end
	local lines = vim.fn.readfile(path)
	if #lines == 0 then
		return nil
	end

	local ok, entry = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not ok or entry.pane ~= pane_id or type(entry.url) ~= "string" then
		return nil
	end
	return entry
end

return M
