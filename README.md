# hajimi.nvim

哈基米是在 Neovim 中使用编程助手的原生对话界面。当前首个支持的助手是 Codex。

目前完成了第一条可用流程：打开对话、向 Codex 提问、实时显示回复、按消息跳转，并在关闭页面后继续同一次对话。消息使用普通 Neovim 页面显示，窗口折行不会改变复制出来的原文。

## 要求

- Neovim 0.11 或更高版本
- 已安装并登录的 `codex` 命令

## 本地安装

使用 lazy.nvim：

```lua
{
  dir = "/Users/mark/MyProjects/hajimi.nvim",
  name = "hajimi.nvim",
  opts = {
    width = 60,
  },
}
```

## 使用

- `:Hajimi`：打开当前对话
- `:Hajimi 你的问题`：打开并提问
- `i`：在哈基米页面中输入新问题
- `]m`：跳到下一条消息
- `[m`：跳到上一条消息
- `q`：暂时关闭页面

## 当前范围

第一版只接入 Codex。界面和对话内容不依赖 Codex 的终端画面，后续可以在不重做界面的情况下接入其他编程助手。

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
