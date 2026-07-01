# AI Project Template

一个面向 Codex / ChatGPT / Claude Code / Gemini CLI 的 AI Native 项目模板。

## 目标

- 统一多设备开发上下文
- 保留 AI 沟通细节和技术决策
- 让 Coding Agent 每次进入项目时先读文档再动代码
- 支持个人长期维护多个项目

## 推荐使用方式

1. 复制本模板作为新项目起点。
2. 修改 `docs/context.md` 里的项目背景。
3. 修改 `AGENTS.md` 里的技术栈和项目规则。
4. 每次开发结束后更新：
   - `docs/decisions.md`
   - `docs/todo.md`
   - `docs/sessions/YYYY-MM-DD.md`

## 目录结构

```txt
.
├── AGENTS.md
├── README.md
├── docs/
│   ├── architecture.md
│   ├── changelog.md
│   ├── context.md
│   ├── decisions.md
│   ├── prompts.md
│   ├── todo.md
│   └── sessions/
├── scripts/
└── src/
```

## 给 Codex 的常用提示

```txt
请先阅读 README.md、AGENTS.md、docs/context.md、docs/architecture.md、docs/decisions.md、docs/todo.md，
理解项目后再开始修改代码。完成后请更新 docs/decisions.md、docs/todo.md，如有必要新增 docs/sessions/YYYY-MM-DD.md。
```
