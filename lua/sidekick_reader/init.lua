local Reader = require("sidekick_reader.reader")

local M = {}
local config = {}
local reader
local pending = {}

local registration_pending = "No Sidekick Reader session is registered for this Sidekick pane"

function M.setup(opts)
	config = vim.tbl_deep_extend("force", {
		registry_dir = vim.fs.joinpath(vim.fn.stdpath("state"), "sidekick-reader"),
		reader_factory = Reader.new,
		layout = "replace",
		viewer_ratio = 0.8,
		width = 60,
	}, opts or {})
	reader = nil
	pending = {}
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
	pane_id = pane_id or vim.b.sidekick_reader_pane_id
	if not pane_id then
		return nil, "Open Sidekick Reader from a Sidekick Codex window"
	end
	local ok, err = get_reader():toggle(pane_id, win)
	if err then
		vim.notify("Sidekick Reader: " .. err, vim.log.levels.ERROR)
	end
	return ok, err
end

local function call_reader(method, pane_id, ...)
	pane_id = pane_id or vim.b.sidekick_reader_pane_id
	if not pane_id then
		return nil, "Open Sidekick Reader from a Sidekick Codex window"
	end
	local ok, err = get_reader()[method](get_reader(), pane_id, ...)
	if err then
		vim.notify("Sidekick Reader: " .. err, vim.log.levels.ERROR)
	end
	return ok, err
end

function M.focus(pane_id, win, terminal)
	return call_reader("focus", pane_id, win, terminal)
end

function M.sidekick_show(pane_id, win, terminal)
	pane_id = pane_id or vim.b.sidekick_reader_pane_id
	if not pane_id then
		return nil, "Open Sidekick Reader from a Sidekick Codex window"
	end

	local token = {}
	local attempts = 0
	pending[pane_id] = token
	local function show_when_ready()
		if pending[pane_id] ~= token then
			return
		end
		local ok, err = get_reader():show(pane_id, win, terminal)
		if ok then
			pending[pane_id] = nil
			return
		end
		attempts = attempts + 1
		if err == registration_pending and attempts < 200 then
			vim.defer_fn(show_when_ready, 50)
			return
		end
		pending[pane_id] = nil
		if err then
			vim.notify("Sidekick Reader: " .. err, vim.log.levels.ERROR)
		end
	end
	show_when_ready()
	return true
end

function M.sidekick_hide(pane_id)
	local resolved = pane_id or vim.b.sidekick_reader_pane_id
	if resolved then
		pending[resolved] = nil
	end
	return call_reader("hide", pane_id)
end

function M.sidekick_close(pane_id)
	local resolved = pane_id or vim.b.sidekick_reader_pane_id
	if resolved then
		pending[resolved] = nil
	end
	return call_reader("close", pane_id)
end

M.setup()
return M
