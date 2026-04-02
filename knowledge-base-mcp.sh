#!/usr/bin/env bash
# ============================================
# Knowledge Base MCP Server 启动脚本
# ============================================
#
# 使用方式：
#   1. Docker 模式（推荐）：通过 docker exec 连接到运行中的 MCP Server 容器
#   2. 本地模式：需要设置 KNOWNBASE_ROOT 环境变量
#
# 环境变量：
#   KB_API_URL     - 知识库 API 地址（默认 http://localhost:4000/api/v1）
#   MCP_MODE       - 运行模式：docker 或 local（默认自动检测）
#   KNOWNBASE_ROOT - 本地模式时的 knownbase 项目根目录
#
# ============================================

set -euo pipefail

KB_API_URL="${KB_API_URL:-http://localhost:4000/api/v1}"
MCP_MODE="${MCP_MODE:-auto}"

# ============================================
# Docker 模式
# ============================================
run_docker_mode() {
  local container_name="${MCP_CONTAINER:-kb-mcp-server}"
  
  # 检查容器是否运行
  if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
    echo "[knowledge-base-mcp] Container '${container_name}' is not running." >&2
    echo "Start it with: docker-compose up -d mcp-server" >&2
    echo "Or switch to local mode: export MCP_MODE=local" >&2
    exit 1
  fi
  
  # 通过 docker exec 连接到容器，保持 stdio 通信
  exec docker exec -i "${container_name}" node /app/dist/index.js
}

# ============================================
# 本地模式
# ============================================
run_local_mode() {
  local knownbase_root=""
  
  # 尝试检测 knownbase 根目录
  if [[ -n "${KNOWNBASE_ROOT:-}" ]]; then
    knownbase_root="${KNOWNBASE_ROOT}"
  else
    # 候选路径（按优先级）
    local candidates=(
      "$HOME/workspace/code/knownbase/AI-Chat"
      "$HOME/code/knownbase/AI-Chat"
      "/workspace/chendecheng/code/need/APP2"
    )
    
    for candidate in "${candidates[@]}"; do
      if [[ -f "$candidate/packages/mcp-server/dist/index.js" ]]; then
        knownbase_root="$candidate"
        break
      fi
    done
  fi
  
  if [[ -z "$knownbase_root" ]]; then
    echo "[knowledge-base-mcp] Could not locate Knownbase root in local mode." >&2
    echo "Set KNOWNBASE_ROOT to your AI-Chat project root:" >&2
    echo "  export KNOWNBASE_ROOT=/path/to/knownbase/AI-Chat" >&2
    echo "" >&2
    echo "Or use Docker mode:" >&2
    echo "  export MCP_MODE=docker" >&2
    exit 1
  fi
  
  export KB_API_URL
  exec node "$knownbase_root/packages/mcp-server/dist/index.js"
}

# ============================================
# 自动检测模式
# ============================================
detect_mode() {
  # 如果明确指定了模式
  if [[ "$MCP_MODE" == "docker" ]]; then
    echo "docker"
    return
  fi
  
  if [[ "$MCP_MODE" == "local" ]]; then
    echo "local"
    return
  fi
  
  # 自动检测：优先 Docker
  local container_name="${MCP_CONTAINER:-kb-mcp-server}"
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container_name}$"; then
    echo "docker"
    return
  fi
  
  # 回退到本地模式
  echo "local"
}

# ============================================
# 主逻辑
# ============================================
main() {
  local mode
  mode="$(detect_mode)"
  
  case "$mode" in
    docker)
      run_docker_mode
      ;;
    local)
      run_local_mode
      ;;
    *)
      echo "[knowledge-base-mcp] Unknown mode: $mode" >&2
      exit 1
      ;;
  esac
}

main
