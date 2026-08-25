# sidekick-reader.nvim

A readable, live view of your [Sidekick](https://github.com/folke/sidekick.nvim) Codex conversation.

Sidekick's terminal remains the place where you type, approve actions, and manage sessions. Sidekick Reader adds a normal Neovim buffer for reading the conversation: responses wrap like regular text, commands stay out of the way, file changes are highlighted, and familiar motions work as expected.

> [!IMPORTANT]
> Sidekick Reader currently supports **Codex sessions managed by Sidekick with tmux**. It is not a standalone chat client.

## Features

- Streams prompts, Codex responses, command output, and file changes without parsing terminal text
- Wraps long responses cleanly and follows new output while you stay at the bottom
- Pauses automatic scrolling while you read earlier messages and shows a `New output` notice
- Folds command details by default and highlights live file diffs
- Opens file references from the conversation with `gf`
- Reviews the file changes from one AI turn with `gd`
- Shows the reader above the Sidekick terminal, or temporarily replaces it
- Hides and restores together with the Sidekick workspace while Codex keeps running in tmux

## Requirements

- Neovim 0.11.2 or newer
- [sidekick.nvim](https://github.com/folke/sidekick.nvim)
- [Codex CLI](https://github.com/openai/codex), installed and signed in
- Node.js 22 or newer
- tmux
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) for the stacked layout
- [diffview.nvim](https://github.com/sindrets/diffview.nvim) for per-turn reviews

## Installation

The example below is a complete [lazy.nvim](https://github.com/folke/lazy.nvim) setup. It connects Sidekick and Sidekick Reader, starts Codex through the included bridge, and adds `<C-]>` for moving between the terminal and reader.

```lua
{
  "folke/sidekick.nvim",
  dependencies = {
    {
      "mkdir700/sidekick-reader.nvim",
      dependencies = {
        "MunifTanjim/nui.nvim",
        "sindrets/diffview.nvim",
      },
    },
  },
  opts = function(_, opts)
    local registry_dir = vim.fs.joinpath(vim.fn.stdpath("state"), "sidekick-reader")
    local bridge = vim.api.nvim_get_runtime_file("scripts/bridge.mjs", false)[1]

    local function pane_for(terminal)
      local ok, states = pcall(require("sidekick.cli.state").get, {
        attached = true,
        name = "codex",
      })
      if not ok then
        return
      end
      for _, state in ipairs(states) do
        if state.terminal == terminal and state.session then
          local session = state.session.parent or state.session
          return session.tmux_pane_id
            or (session.pane_id and session:pane_id())
        end
      end
    end

    opts.cli = opts.cli or {}
    opts.cli.mux = {
      enabled = true,
      backend = "tmux",
    }
    opts.cli.tools = opts.cli.tools or {}
    opts.cli.tools.codex = vim.tbl_deep_extend("force", opts.cli.tools.codex or {}, {
      cmd = { "node", bridge, "launch" },
      env = { SIDEKICK_READER_REGISTRY_DIR = registry_dir },
    })

    opts.cli.win = opts.cli.win or {}
    local user_config = opts.cli.win.config
    opts.cli.win.config = function(terminal)
      if user_config then
        user_config(terminal)
      end
      if terminal._sidekick_reader_wrapped then
        return
      end
      terminal._sidekick_reader_wrapped = true

      local show = terminal.show
      local hide = terminal.hide
      local close = terminal.close

      terminal.show = function(self, ...)
        local result = show(self, ...)
        local pane = pane_for(self)
        if pane and self.win then
          require("sidekick_reader").sidekick_show(pane, self.win, self)
        end
        return result
      end
      terminal.hide = function(self, ...)
        local pane = pane_for(self)
        if pane then
          require("sidekick_reader").sidekick_hide(pane)
        end
        return hide(self, ...)
      end
      terminal.close = function(self, ...)
        local pane = pane_for(self)
        if pane then
          require("sidekick_reader").sidekick_close(pane)
        end
        return close(self, ...)
      end
    end

    opts.cli.win.keys = opts.cli.win.keys or {}
    opts.cli.win.keys.sidekick_reader = {
      "<C-]>",
      function(terminal)
        local pane = pane_for(terminal)
        if pane and terminal.win then
          require("sidekick_reader").focus(pane, terminal.win, terminal)
        end
      end,
      mode = { "n", "t" },
      desc = "Focus Sidekick Reader",
    }

    require("sidekick_reader").setup({
      registry_dir = registry_dir,
      layout = "stacked",
      viewer_ratio = 0.8,
    })
  end,
  keys = {
    {
      "<leader>aa",
      function()
        require("sidekick.cli").toggle({ name = "codex" })
      end,
      desc = "Toggle Sidekick Codex",
    },
  },
}
```

Restart Neovim, run `:Lazy sync`, then use `<leader>aa` to open Codex.

## Usage

Sidekick Reader opens with the Sidekick Codex terminal. Type and approve actions in the terminal; use the reader when you want to follow or review the conversation.

| Key | Action |
| --- | --- |
| `<C-]>` in Sidekick | Focus the reader |
| `i` or `<C-]>` in the reader | Return to Sidekick input |
| `]m` / `[m` | Next / previous message |
| `]g` / `[g` | Last / first message |
| `G` | Jump to the latest output and resume following |
| `gf` | Open the file reference under the cursor in the editor window on the left |
| `gd` | Review the current turn's file changes in Diffview |
| `q` | Hide the Sidekick workspace |

Commands are folded automatically. Standard Neovim fold commands such as `za`, `zo`, and `zc` can expand or collapse them.

## Layouts

`stacked` keeps both views visible, with the reader above the Sidekick terminal:

```lua
require("sidekick_reader").setup({
  layout = "stacked",
  viewer_ratio = 0.8, -- 80% reader, 20% terminal
})
```

`replace` uses the Sidekick terminal window for the reader and restores the terminal when you leave:

```lua
require("sidekick_reader").setup({
  layout = "replace",
})
```

The default layout is `replace`.

## How it works

The included bridge starts a local Codex App Server and connects the normal Codex terminal to it. Sidekick Reader observes the same session and renders the structured events in a Neovim buffer. This is why long lines, command output, and file changes remain readable without scraping the terminal screen.

The `gd` review uses the changes reported by Codex for the selected turn. It does not use the repository's current diff, so changes that already existed in your working tree are not mixed into the review.

## Troubleshooting

**The Sidekick terminal opens, but the reader does not**

- Confirm that Sidekick is using the `tmux` backend.
- Confirm `node --version` reports 22 or newer.
- Confirm `codex` works and is signed in when run directly.
- Check `:messages` for a Sidekick Reader error.

**`gf` cannot open a file**

The reference must point to an existing local file. Sidekick Reader opens it in a normal editor window to the left of the reader.

**`gd` says there are no recorded changes**

Place the cursor inside a turn where Codex changed files. Diffview also requires the conversation directory to be inside a Git repository.

## Development

Run the automated test suite:

```sh
for spec in tests/*_spec.lua; do
  nvim --headless -u tests/minimal_init.lua -l "$spec" || exit 1
done
```

Run the bridge tests:

```sh
node --test tests/bridge_spec.mjs
```

The real Codex smoke test sends a short prompt using your signed-in Codex CLI:

```sh
nvim --headless -u tests/minimal_init.lua -l tests/real_codex_smoke.lua
```
