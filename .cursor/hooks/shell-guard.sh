#!/bin/bash
# ============================================================
# shell-guard.sh — Shell 命令安全守卫
# 绑定: beforeShellExecution（Cursor 推荐的 shell 拦截事件，failClosed:true）
# 输入: {"command":"...", ...} (stdin JSON)
# 输出: {"permission":"allow"|"deny"|"ask","user_message":"..."}
#
# 职责：拦截危险 shell 命令（与流程门禁 pipeline-gate.sh 分离）
# - 危险命令守卫：全盘扫描 / 系统根递归修改 / 敏感路径访问
# - git 安全门禁：commit/push 需授权、stash 禁止
# - rm -rf / fork bomb 拦截
#
# ── 三类处置（v2 引入 ask）──
#   deny  硬禁止，无覆盖通道  → rm -rf / · fork bomb · git stash
#   ask   交用户当场裁决      → 敏感路径 · 系统根递归修改 · 全盘扫描 · git commit/push
#   allow 放行
#
# ⚠️ 为何这里可以用 `ask` 而 pipeline-gate.sh 不能：
#    官方文档（https://cursor.com/docs/hooks）中 `permission:"ask"` 的支持矩阵是
#    逐事件不一致的 —— beforeShellExecution / beforeMCPExecution **支持**（文档自身的
#    示例即「gh 命令需批准」「kubectl apply 生产需人工批准」），而 preToolUse 是
#    「accepted by the schema but not enforced」（等于 allow）。同一原语在不同事件上
#    语义不同，是这套 hook 最容易踩的坑。
#
# ⚠️ 逃生舱保留：/tmp/command-guard-allowed 与 /tmp/git-commit-allowed 仍在生效
#    （300s 窗口）。两者语义现在是「用户已事先明确同意」→ 直接 allow、不再弹窗，
#    用于避免重复确认。ask 是「当场确认」，marker 是「事先确认」，两者互补而非替代。
# ============================================================

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/emit.sh
source "$HOOK_DIR/lib/emit.sh"

INPUT=$(cat 2>/dev/null || echo '{}')
CMD=$(printf '%s' "$INPUT" | jq -r '.command // empty' 2>/dev/null)

# 空命令放行
if [ -z "$CMD" ]; then
    emit_allow
fi

# ── 消息输出包装 ──
# `%b` 先展开消息里的 \n 转义，再交 emit_* 用 jq --arg 安全转义为合法 JSON。
# 必须走 jq：MSG 里含未转义的 "（命令串中极常见）或换行时会产出非法 JSON，
# 而本 hook 配置为 failClosed → 表现为「hook 返回非法 JSON」黑盒报错，
# 真正想传达的拦截原因完全丢失，且无法用逃生舱自查。
_deny_cmd() { emit_deny "$(printf '%b' "$1")"; }
_ask_cmd()  { emit_ask  "$(printf '%b' "$1")"; }

# ── 辅助函数 ──

# 跨平台文件 mtime（Unix 秒）：`stat -c` 是 GNU 扩展，macOS 自带 BSD stat 会以
# 「illegal option」失败（stdout 空、退出码 1）→ 回落 echo 0 → `now - 0` 远大于窗口
# → 两个逃生舱标记（command-guard-allowed / git-commit-allowed）**恒不生效**。
# 探测手段：BSD stat 无 --version（GNU stat 有）。
_file_mtime() {
    if stat --version >/dev/null 2>&1; then
        stat -c %Y "$1" 2>/dev/null || echo 0
    else
        stat -f %m "$1" 2>/dev/null || echo 0
    fi
}

# 标记文件「存在且在 N 秒内创建」（逃生舱统一判定，默认 300s 窗口）
_marker_fresh() {
    local f="$1" win="${2:-300}" mt
    [ -f "$f" ] || return 1
    mt=$(_file_mtime "$f")
    case "$mt" in ''|*[!0-9]*) return 1 ;; esac
    [ $(( $(date +%s) - mt )) -lt "$win" ]
}

# ============================================================
# 1. rm -rf / fork bomb 硬拦截（无覆盖通道）
# ============================================================
if printf '%s' "$CMD" | grep -qE 'rm -rf /[^a-z]|sudo rm -rf|:\(\)\{ :|:& \};:'; then
    _deny_cmd "⛔ 危险命令被拦截 [破坏性操作]：检测到 rm -rf 根目录 / fork bomb。\n\n待执行命令：$CMD\n\n此类命令没有任何覆盖通道。如确有需要，请用户手工执行。"
fi

# ============================================================
# 2. 危险命令守卫
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
    printf '%s' "$1" | grep -qE "(^|[^[:alnum:]_])$2([^[:alnum:]_]|$)"
}

# 逃生舱：touch /tmp/command-guard-allowed 后 300s 内放行（事先同意的快速通道）
if ! _marker_fresh /tmp/command-guard-allowed 300; then
    # 类别 3 — 敏感路径访问
    for p in "${DANGER_SENSITIVE_PATHS[@]}"; do
        if printf '%s' "$CMD" | grep -qF "$p"; then
            _ask_cmd "⚠️ 命令需你确认 [敏感路径访问]：检测到访问敏感路径（${p}）。\n\n待执行命令：$CMD\n\n批准则本次执行；拒绝则不会执行。若要长期放行，可在对话中回复「允许该命令」，由 Agent touch /tmp/command-guard-allowed 后重试。"
        fi
    done

    # 是否含危险遍历根参数
    has_danger_root=0
    if printf '%s' "$CMD" | grep -qE "$DANGER_ROOT_RE"; then
        has_danger_root=1
    fi

    if [ "$has_danger_root" -eq 1 ]; then
        # 类别 2 — 系统根递归修改
        for m in "${DANGER_RECURSIVE_MODS[@]}"; do
            if _danger_tool_match "$CMD" "$m"; then
                _ask_cmd "⚠️ 命令需你确认 [系统根递归修改]：检测到以系统目录为目标的递归修改（命中：${m}）。\n\n待执行命令：$CMD\n\n批准则本次执行；拒绝则不会执行。"
            fi
        done
        # 类别 1 — 全盘递归扫描
        for t in "${DANGER_SCAN_TOOLS[@]}"; do
            if _danger_tool_match "$CMD" "$t"; then
                _ask_cmd "⚠️ 命令需你确认 [全盘扫描]：检测到以系统目录为起点的递归扫描（命中：${t}），可能极慢。\n\n待执行命令：$CMD\n\n建议限定在项目内。批准则本次执行；拒绝则不会执行。"
            fi
        done
    fi
fi

# ============================================================
# 3. Git 安全门禁
# ============================================================

# git commit/push 必须经用户显式允许
if printf '%s' "$CMD" | grep -qE '\bgit (commit|push)\b'; then
    if _marker_fresh /tmp/git-commit-allowed 300; then
        emit_allow
    fi
    _ask_cmd "⚠️ 命令需你确认 [git 提交]：Agent 不应未经用户明确同意就 commit/push。\n\n待执行命令：$CMD\n\n批准则本次执行。规范流程：仅在 HG-3 用户确认「通过」后提交本 Phase 改动，且用显式文件清单（禁止 git add -A）。"
fi

# git stash 禁止（无覆盖通道 —— stash 会隐藏工作区改动，导致 Phase 实现代码丢失）
if printf '%s' "$CMD" | grep -qE '\bgit stash\b'; then
    _deny_cmd "⛔ git stash 被禁止。不允许使用 stash 隐藏工作区改动，这会导致 Phase 实现代码丢失。如需切换分支，请先完成当前 Phase 的 commit + merge 流程。"
fi

# 全部通过 → 放行
emit_allow
