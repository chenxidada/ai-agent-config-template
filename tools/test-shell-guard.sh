#!/bin/bash
# ============================================================
# test-shell-guard.sh — shell-guard.sh 行为测试
# ============================================================
# 覆盖三类处置：deny（硬禁止）/ ask（交用户当场裁决）/ allow
# ⚠️ 会临时创建并清理 /tmp 逃生舱标记（改动前先备份存在性）。
# ============================================================
cd "$(dirname "$0")/.." || exit 1
GUARD=".cursor/hooks/shell-guard.sh"

pass=0; fail=0
sg() { jq -nc --arg c "$1" '{command:$c}' | bash "$GUARD" 2>/dev/null | jq -r '.permission // "?"' 2>/dev/null; }
chk() {
    local got; got=$(sg "$2")
    if [ "$1" = "$got" ]; then printf '  ✅ %s → %s\n' "$3" "$got"; pass=$((pass+1))
    else printf '  ❌ %s → 期望[%s] 实际[%s]\n' "$3" "$1" "$got"; fail=$((fail+1)); fi
}

# 备份并移除逃生舱标记，确保基线干净
BAK_COMMIT=0; BAK_CMD=0
[ -f /tmp/git-commit-allowed ] && { mv /tmp/git-commit-allowed /tmp/.gca.bak; BAK_COMMIT=1; }
[ -f /tmp/command-guard-allowed ] && { mv /tmp/command-guard-allowed /tmp/.cga.bak; BAK_CMD=1; }

echo "── deny：硬禁止（无覆盖通道）──"
chk "deny" 'rm -rf / --no-preserve-root'   "rm -rf /"
chk "deny" 'sudo rm -rf /var'              "sudo rm -rf 系统目录"
chk "deny" 'git stash'                     "git stash（Phase 代码会丢）"
chk "deny" 'git stash push -m wip'         "git stash push"

echo "── ask：交用户当场裁决（旧实现为 deny+手工逃生舱）──"
chk "ask" 'cat /etc/shadow'                "敏感路径 /etc/shadow"
chk "ask" 'git commit -m "x"'              "git commit"
chk "ask" 'git push origin main'           "git push"
chk "ask" 'find / -name "*.log"'           "全盘递归扫描 find /"
chk "ask" 'chmod -R 777 /etc'              "系统根递归修改 chmod -R /etc"
chk "ask" 'grep -r foo /etc'               "grep -r /etc"

echo "── allow：正常命令不得被误伤 ──"
chk "allow" 'ls -la'                       "ls -la"
chk "allow" 'npm test'                     "npm test"
chk "allow" 'find . -name "*.ts"'          "项目内 find"
chk "allow" 'git status'                   "git status"
chk "allow" 'git add src/app.ts'           "git add（非 commit）"
chk "allow" 'rg TODO src/'                 "项目内 rg"

echo "── 逃生舱：事先同意的快速通道（300s 窗口）──"
touch /tmp/git-commit-allowed
chk "allow" 'git commit -m "x"'            "marker 新鲜 → commit 直接 allow（不再弹窗）"
chk "allow" 'git push'                     "marker 新鲜 → push 直接 allow"
rm -f /tmp/git-commit-allowed
chk "ask"   'git commit -m "x"'            "marker 移除 → commit 回到 ask"

touch /tmp/command-guard-allowed
chk "allow" 'cat /etc/shadow'              "marker 新鲜 → 敏感路径直接 allow"
rm -f /tmp/command-guard-allowed
chk "ask"   'cat /etc/shadow'              "marker 移除 → 敏感路径回到 ask"

echo "── 输出合法性：消息含引号/换行时仍须是合法 JSON（failClosed 前提）──"
OUT=$(jq -nc --arg c 'find / -name "a"b' '{command:$c}' | bash "$GUARD" 2>/dev/null)
if printf '%s' "$OUT" | jq -e '.permission' >/dev/null 2>&1; then
    printf '  ✅ 含双引号的命令 → 输出仍是合法 JSON\n'; pass=$((pass+1))
else
    printf '  ❌ 含双引号的命令 → 输出非法 JSON: %s\n' "$OUT"; fail=$((fail+1))
fi

# 还原逃生舱标记
[ "$BAK_COMMIT" -eq 1 ] && mv /tmp/.gca.bak /tmp/git-commit-allowed
[ "$BAK_CMD" -eq 1 ]    && mv /tmp/.cga.bak /tmp/command-guard-allowed

printf '\n结果：%d 通过 / %d 失败\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
