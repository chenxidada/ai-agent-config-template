#!/bin/bash
# ============================================================
# shell-guard.sh — Shell 命令安全守卫
# 绑定: beforeShellExecution（Cursor 推荐的 shell 拦截事件）
# 输入: {"command":"..."} (stdin JSON)
# 输出: {"permission":"allow"|"deny","user_message":"..."}
#
# 职责：拦截危险 shell 命令（与流程门禁分离）
# - 危险命令守卫：全盘扫描 / 系统根递归修改 / 敏感路径访问
# - git 安全门禁：commit/push 需授权、stash 禁止
# - rm -rf / fork bomb 拦截
# ============================================================

INPUT=$(cat 2>/dev/null || echo '{}')
CMD=$(echo "$INPUT" | jq -r '.command // empty')

# 空命令放行
if [ -z "$CMD" ]; then
    echo '{"permission":"allow"}'
    exit 0
fi

# ── 辅助函数 ──
deny_cmd() {
    local MSG="$1"
    echo "{\"permission\":\"deny\",\"user_message\":\"$MSG\"}"
    exit 0
}

# ============================================================
# 1. rm -rf / fork bomb 硬拦截
# ============================================================
if echo "$CMD" | grep -qE 'rm -rf /[^a-z]|sudo rm -rf|:\(\)\{ :|:& \};:'; then
    deny_cmd "⛔ 危险命令被拦截"
fi

# ============================================================
# 2. 危险命令守卫（三类硬拦截）
# 单一维护点：新增危险模式只需在对应数组追加一行。
# ============================================================

# 共享遍历根分类器：裸 / / 顶层系统目录 / ~ / $HOME
DANGER_ROOT_RE='(^|[[:space:]"'\''])(/([[:space:]"'\'']|$)|/(etc|usr|var|sys|proc|bin|sbin|lib|lib64|opt|boot|dev|root|home)(/[^[:space:]"'\'']*)?([[:space:]"'\'']|$)|(~|\$HOME)(/[^[:space:]"'\'']*)?([[:space:]"'\'']|$))'
# 类别 1：全盘递归扫描工具
DANGER_SCAN_TOOLS=('find' 'grep -r' 'grep -R' 'ls -R' 'du' 'rg')
# 类别 2：系统根递归修改
DANGER_RECURSIVE_MODS=('chmod -R' 'chown -R' 'rm -rf')
# 类别 3：敏感路径（读或写均拦）
DANGER_SENSITIVE_PATHS=('/etc/shadow' '/etc/passwd' '/root/.ssh' '~/.ssh' 'id_rsa' 'id_ed25519' 'id_ecdsa')

_danger_tool_match() {
    echo "$1" | grep -qE "(^|[^[:alnum:]_])$2([^[:alnum:]_]|$)"
}

# 逃生舱：touch /tmp/command-guard-allowed 后 300s 内放行
if ! { [ -f /tmp/command-guard-allowed ] && [ $(($(date +%s) - $(stat -c %Y /tmp/command-guard-allowed 2>/dev/null || echo 0))) -lt 300 ]; }; then
    # 类别 3 — 敏感路径访问
    for p in "${DANGER_SENSITIVE_PATHS[@]}"; do
        if echo "$CMD" | grep -qF "$p"; then
            deny_cmd "⛔ 命令被拦截 [敏感路径访问]：检测到访问敏感路径（$p）。\\n\\n待执行命令：$CMD\\n\\n如确需执行，请回复「允许该命令」，我会 touch /tmp/command-guard-allowed 后重试放行。"
        fi
    done

    # 是否含危险遍历根参数
    has_danger_root=0
    if echo "$CMD" | grep -qE "$DANGER_ROOT_RE"; then
        has_danger_root=1
    fi

    if [ "$has_danger_root" -eq 1 ]; then
        # 类别 2 — 系统根递归修改
        for m in "${DANGER_RECURSIVE_MODS[@]}"; do
            if _danger_tool_match "$CMD" "$m"; then
                deny_cmd "⛔ 命令被拦截 [系统根递归修改]：检测到以系统目录为目标的递归修改（命中：$m）。\\n\\n待执行命令：$CMD\\n\\n如确需执行，请回复「允许该命令」，我会 touch /tmp/command-guard-allowed 后重试放行。"
            fi
        done
        # 类别 1 — 全盘递归扫描
        for t in "${DANGER_SCAN_TOOLS[@]}"; do
            if _danger_tool_match "$CMD" "$t"; then
                deny_cmd "⛔ 命令被拦截 [全盘扫描]：检测到以系统目录为起点的递归扫描（命中：$t），可能极慢。\\n\\n待执行命令：$CMD\\n\\n建议限定在项目内。如确需执行，请回复「允许该命令」，我会 touch /tmp/command-guard-allowed 后重试放行。"
            fi
        done
    fi
fi

# ============================================================
# 3. Git 安全门禁
# ============================================================

# git commit/push 必须经用户显式允许
if echo "$CMD" | grep -qE '\bgit (commit|push)\b'; then
    if [ -f /tmp/git-commit-allowed ] && [ $(($(date +%s) - $(stat -c %Y /tmp/git-commit-allowed 2>/dev/null || echo 0))) -lt 300 ]; then
        echo '{"permission":"allow"}'
        exit 0
    fi
    deny_cmd "⛔ git commit/push 被拦截。Agent 不允许未经用户明确同意的提交操作。\\n如你确实需要提交，请回复「允许提交」后由 Agent touch /tmp/git-commit-allowed 再执行。"
fi

# git stash 禁止
if echo "$CMD" | grep -qE '\bgit stash\b'; then
    deny_cmd "⛔ git stash 被禁止。不允许使用 stash 隐藏工作区改动，这会导致 Phase 实现代码丢失。如需切换分支，请先完成当前 Phase 的 commit + merge 流程。"
fi

# 全部通过 → 放行
echo '{"permission":"allow"}'
exit 0
