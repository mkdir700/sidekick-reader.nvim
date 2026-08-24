local App = require("hajimi.app")

local M = {}
local defaults = {
	width = 60,
}

local config = vim.deepcopy(defaults)
local app

local function get_app()
	if not app then
		app = App.new({
			cwd = config.cwd or vim.fn.getcwd(),
			provider_factory = config.provider_factory,
		})
	end

	return app
end

function M.setup(opts)
	config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
	app = nil
end

function M.open()
	local surface = get_app():open({ width = config.width })

	vim.keymap.set("n", "i", M.prompt, { buffer = surface.buf, desc = "Ask Hajimi" })
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_hide(0)
	end, { buffer = surface.buf, desc = "Hide Hajimi" })
	vim.keymap.set("n", "]m", function()
		require("hajimi.view").jump(surface.buf, 1)
	end, { buffer = surface.buf, desc = "Next Hajimi message" })
	vim.keymap.set("n", "[m", function()
		require("hajimi.view").jump(surface.buf, -1)
	end, { buffer = surface.buf, desc = "Previous Hajimi message" })

	return surface
end

function M.ask(text)
	M.open()
	get_app():ask(text, function(err)
		if err then
			vim.notify("Hajimi: " .. tostring(err), vim.log.levels.ERROR)
		end
	end)
end

function M.prompt()
	vim.ui.input({ prompt = "Ask Hajimi: " }, function(text)
		if text then
			M.ask(text)
		end
	end)
end

function M.app()
	return get_app()
end

return M
