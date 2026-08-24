local M = {}

local function header_path(value)
	value = value:match("^(.-)\t") or value
	if value == "/dev/null" then
		return
	end
	if value:sub(1, 1) == '"' then
		local ok, decoded = pcall(vim.json.decode, value)
		if ok then
			value = decoded
		end
	end
	return value:gsub("^[ab]/", "")
end

local function finish_file(result, file)
	if not file then
		return
	end
	local path = file.new_path or file.old_path or file.path
	if not path then
		return
	end
	file.path = path
	file.status = file.status or "M"
	local entry = {
		path = path,
		oldpath = file.old_path ~= file.new_path and file.old_path or nil,
		status = file.status,
		stats = { additions = file.additions, deletions = file.deletions },
		left_null = file.status == "A",
		right_null = file.status == "D",
		selected = #result.files.working == 0,
	}
	result.files.working[#result.files.working + 1] = entry
	result.data[path] = { left = file.left, right = file.right }
end

function M.parse(diff)
	if type(diff) ~= "string" or diff == "" then
		return nil, "This turn has no file changes"
	end
	local result = { files = { working = {} }, data = {} }
	local file
	local in_hunk = false
	local hunk_count = 0
	for _, line in ipairs(vim.split(diff, "\n", { plain = true })) do
		local old_hint, new_hint = line:match("^diff %-%-git a/(.-) b/(.+)$")
		if old_hint then
			finish_file(result, file)
			file = {
				path = new_hint,
				old_path = old_hint,
				new_path = new_hint,
				left = {},
				right = {},
				additions = 0,
				deletions = 0,
			}
			in_hunk = false
			hunk_count = 0
		elseif file then
			if line:match("^new file mode ") then
				file.status = "A"
			elseif line:match("^deleted file mode ") then
				file.status = "D"
			elseif line:match("^rename from ") then
				file.status = "R"
				file.old_path = line:sub(13)
			elseif line:match("^rename to ") then
				file.status = "R"
				file.new_path = line:sub(11)
			elseif line:match("^%-%-%- ") then
				file.old_path = header_path(line:sub(5))
			elseif line:match("^%+%+%+ ") then
				file.new_path = header_path(line:sub(5))
			elseif line:match("^@@ ") then
				if hunk_count > 0 then
					file.left[#file.left + 1] = "... unchanged lines ..."
					file.right[#file.right + 1] = "... unchanged lines ..."
				end
				hunk_count = hunk_count + 1
				in_hunk = true
			elseif in_hunk then
				local prefix, value = line:sub(1, 1), line:sub(2)
				if prefix == " " then
					file.left[#file.left + 1] = value
					file.right[#file.right + 1] = value
				elseif prefix == "-" then
					file.left[#file.left + 1] = value
					file.deletions = file.deletions + 1
				elseif prefix == "+" then
					file.right[#file.right + 1] = value
					file.additions = file.additions + 1
				end
			end
		end
	end
	finish_file(result, file)
	if #result.files.working == 0 then
		return nil, "This turn has no reviewable file changes"
	end
	return result
end

local function open_diffview(options)
	local git_root = vim.fs.root(options.cwd, ".git")
	if not git_root then
		return nil, "Diffview requires the conversation directory to be inside a Git repository"
	end
	local ok, api = pcall(require, "diffview.api.views.diff.diff_view")
	if not ok then
		return nil, "Diffview is not available"
	end
	local Rev = require("diffview.vcs.adapters.git.rev").GitRev
	local rev = require("diffview.vcs.rev")
	local view = api.CDiffView({
		git_root = git_root,
		left = Rev(rev.RevType.COMMIT, string.rep("1", 40)),
		right = Rev(rev.RevType.COMMIT, string.rep("2", 40)),
		rev_arg = options.title,
		files = options.files,
		update_files = function()
			return options.files
		end,
		get_file_data = function(_, path, side)
			return options.data[path] and options.data[path][side] or {}
		end,
	})
	if not view:is_valid() then
		return nil, "Diffview could not open this turn"
	end
	for _, entry in ipairs(view.files.working) do
		entry.layout.a.file.binary = false
		entry.layout.b.file.binary = false
		entry.layout.a.file.nulled = entry.status == "A"
		entry.layout.b.file.nulled = entry.status == "D"
	end
	require("diffview.lib").add_view(view)
	view:open()
	return view
end

function M.open(diff, cwd, opts)
	opts = opts or {}
	local parsed, err = (opts.parse or M.parse)(diff)
	if not parsed then
		return nil, err
	end
	return (opts.open_view or open_diffview)({
		cwd = cwd,
		data = parsed.data,
		files = parsed.files,
		title = opts.title or "AI turn changes",
	})
end

return M
