# hajimi.nvim

哈基米是 Sidekick Codex 会话的实时阅读模式。

提问、确认操作和会话管理仍在 Sidekick 中完成。在 Sidekick Codex 窗口按下快捷键后，当前窗口切换为哈基米渲染页；再次按下快捷键或按 `q` 返回原来的 Sidekick 终端。Codex 在 tmux 中持续运行，不会因切换阅读模式而中断。

## 要求

- Neovim 0.11 或更高版本
- 已安装并登录的 `codex` 命令
- Node.js 22 或更高版本
- Sidekick 使用 tmux 保存 Codex 会话

## 本地安装

使用 lazy.nvim：

```lua
{
  dir = "/Users/mark/MyProjects/hajimi.nvim",
  name = "hajimi.nvim",
  opts = {
    registry_dir = vim.fs.joinpath(vim.fn.stdpath("state"), "hajimi"),
    width = 60,
  },
}
```

## 使用

- 在 Sidekick Codex 窗口按 `<C-]>`：切换哈基米阅读模式
- 在哈基米页面按 `<C-]>`：返回 Sidekick
- `<C-j>`：跳到下一条消息
- `<C-k>`：跳到上一条消息
- `q`：返回 Sidekick

## 当前范围

哈基米不解析 Sidekick 终端画面。Sidekick 启动 Codex 时会同时启动一个隔离的 App Server；Codex 终端和哈基米观察器连接同一个后台，因此渲染页可以读取原始消息并实时刷新，不受终端折行影响。

Codex 连接依据 [OpenAI 官方 App Server 说明](https://learn.chatgpt.com/docs/app-server)。

## 测试

```sh
for spec in tests/*_spec.lua; do
  nvim --headless -u tests/minimal_init.lua -l "$spec" || exit 1
done
```

真实 Codex 验证会发送一条简短测试消息：

```sh
nvim --headless -u tests/minimal_init.lua -l tests/real_codex_smoke.lua
```
