#!/bin/bash
# OpenClaw Health Monitor - 健康监控
# 使用 OpenClaw 内置 health/doctor 命令

# 设置 PATH（launchd 环境需要）
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

LOG_FILE="$HOME/workspace/logs/openclaw-health.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== OpenClaw Health Monitor Started ==="

# 1. 运行 openclaw doctor（自动修复）
log "运行健康检查..."
if openclaw doctor 2>&1 | tee -a "$LOG_FILE"; then
    log "✅ 健康检查通过"
else
    log "⚠️ 发现问题，请查看日志"
fi

# 2. 检查 Gateway 状态
log ""
log "检查 Gateway 状态..."
if openclaw gateway status > /dev/null 2>&1; then
    log "✅ Gateway 正常运行"
else
    log "⚠️ Gateway 状态异常，尝试重启..."
    openclaw gateway restart 2>&1 | tee -a "$LOG_FILE"
    sleep 5
    
    if openclaw gateway status > /dev/null 2>&1; then
        log "✅ Gateway 已恢复"
    else
        log "❌ Gateway 仍然失败"
    fi
fi

# 3. 清理旧日志（保留 7 天）
log ""
log "清理旧日志..."
find ~/workspace/logs -name "*.log" -mtime +7 -delete 2>/dev/null
find ~/Library/Logs -name "*.log" -mtime +7 -delete 2>/dev/null
log "✅ 清理完成"

log ""
log "=== Health Check Complete ==="
echo "---" >> "$LOG_FILE"
