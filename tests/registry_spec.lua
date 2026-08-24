local registry = require("hajimi.registry")

local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
vim.fn.writefile({ vim.json.encode({ pane = "%7", url = "ws://127.0.0.1:4567", pid = 123 }) }, dir .. "/%7.json")
vim.fn.writefile({ vim.json.encode({ pane = "%8", url = "ws://127.0.0.1:4568", pid = 124 }) }, dir .. "/%8.json")

local selected = registry.read(dir, "%7")
assert(selected, "the matching Sidekick pane should resolve")
assert(selected.url == "ws://127.0.0.1:4567", "the wrong Codex endpoint was selected")
assert(registry.read(dir, "%9") == nil, "an unknown pane must not fall back to another session")

print("registry_spec: ok")
