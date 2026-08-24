# hajimi.nvim

哈基米是 Sidekick Codex 会话的实时阅读模式。

提问、确认操作和会话管理仍在 Sidekick 中完成。Sidekick 打开时，哈基米阅读区会在上方同时出现；Sidekick 隐藏或关闭时，阅读区也会一起消失。Codex 在 tmux 中持续运行，不会因隐藏界面而中断。

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
    layout = "stacked",
    viewer_ratio = 0.8,
    width = 60,
  },
}
```

## 使用

- 在 Sidekick Codex 窗口按 `<C-]>`：进入哈基米阅读区
- 在哈基米页面按 `i` 或 `<C-]>`：回到 Sidekick 输入区
- `]m`：跳到下一条消息
- `[m`：跳到上一条消息
- `G`：回到最新消息并继续跟随
- `q`：隐藏整个 Sidekick 工作区

## 当前范围

Hajimi 提供两种显示布局：

- `stacked`：上方 Viewer、下方 Sidekick 终端；`viewer_ratio = 0.8` 表示 80/20。
- `replace`：Viewer 临时替换 Sidekick 所在窗口。

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
