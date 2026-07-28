---
description: 飞书 lark-cli 安全铁律 — 仅在涉及飞书操作的场景中手动引用
alwaysApply: false
---

# 飞书 / Lark — lark-cli 安全铁律

本规则仅在涉及飞书操作时使用。用法通过 `lark-cli --help` 动态发现。

## 安全铁律

- **禁止输出密钥**：appSecret、accessToken 绝不能打印到终端
- **exit 10 协议**：高风险写操作返回 exit code 10 → 必须向用户确认后追加 `--yes` 重试，禁止静默加 `--yes`

## 参考

完整业务域技能（calendar、im、mail 等 26 个）位于 `~/.claude/skills/lark-*/SKILL.md`，需要时按域读取。
