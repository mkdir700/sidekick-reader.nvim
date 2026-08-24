local Reader = require("hajimi.reader")

local M = {}
local config = {}
local reader

function M.setup(opts)
	config = vim.tbl_deep_extend("force", {
		registry_dir = vim.fs.joinpath(vim.fn.stdpath("state"), "hajimi"),
		reader_factory = Reader.new,
		layout = "replace",
		viewer_ratio = 0.8,
		width = 60,
	}, opts or {})
	reader = nil
end

local function get_reader()
	if not reader then
		reader = config.reader_factory({
			registry_dir = config.registry_dir,
			width = config.width,
			layout = config.layout,
			viewer_ratio = config.viewer_ratio,
		})
	end
	return reader
end

function M.toggle(pane_id, win)
	pane_id = pane_id or vim.b.hajimi_pane_id
	if not pane_id then
		return nil, "Open Hajimi from a Sidekick Codex window"
	end
	local ok, err = get_reader():toggle(pane_id, win)
	if err then
		vim.notify("Hajimi: " .. err, vim.log.levels.ERROR)
	end
	return ok, err
end

local function call_reader(method, pane_id, ...)
	pane_id = pane_id or vim.b.hajimi_pane_id
	if not pane_id then
		return nil, "Open Hajimi from a Sidekick Codex window"
	end
	local ok, err = get_reader()[method](get_reader(), pane_id, ...)
	if err then
		vim.notify("Hajimi: " .. err, vim.log.levels.ERROR)
	end
	return ok, err
end

function M.focus(pane_id, win, terminal)
	return call_reader("focus", pane_id, win, terminal)
end

function M.sidekick_show(pane_id, win, terminal)
	return call_reader("show", pane_id, win, terminal)
end

function M.sidekick_hide(pane_id)
	return call_reader("hide", pane_id)
end

function M.sidekick_close(pane_id)
	return call_reader("close", pane_id)
end

M.setup()
return M
