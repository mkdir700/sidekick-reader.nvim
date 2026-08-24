local Reference = require("sidekick_reader.file_reference")

local target = vim.fn.tempname() .. ".rs"
vim.fn.writefile({ "one", "two", "three", "four" }, target)

local markdown = ("Update [durable/tests.rs](%s:3) in four places"):format(target)
local label_col = assert(markdown:find("durable", 1, true)) - 1
local resolved = assert(Reference.resolve(markdown, label_col, vim.fn.getcwd()))
assert(resolved.path == vim.fs.normalize(target), "the markdown target path should be resolved")
assert(resolved.line == 3, "the markdown target line should be resolved")

local plain = target .. ":4"
resolved = assert(Reference.resolve(plain, 2, vim.fn.getcwd()))
assert(resolved.path == vim.fs.normalize(target), "a plain absolute path should be resolved")
assert(resolved.line == 4, "a plain path line should be resolved")

local left_win = vim.api.nvim_get_current_win()
vim.cmd("rightbelow vnew")
local reader_win = vim.api.nvim_get_current_win()
vim.bo.filetype = "sidekick-reader"

local opened, err = Reference.open_in_left({ path = target, line = 3 }, reader_win)
assert(opened, err)
assert(vim.api.nvim_get_current_win() == left_win, "the file should open in the left editor window")
assert(
	(vim.uv or vim.loop).fs_realpath(vim.api.nvim_buf_get_name(0)) == (vim.uv or vim.loop).fs_realpath(target),
	"the left editor should contain the referenced file"
)
assert(vim.api.nvim_win_get_cursor(0)[1] == 3, "the left editor should jump to the referenced line")
assert(vim.api.nvim_win_is_valid(reader_win), "opening a file must keep the reader visible")

vim.fn.delete(target)
print("file_reference_spec: ok")
