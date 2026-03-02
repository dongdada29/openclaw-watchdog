#!/bin/bash
# OpenClaw Health Monitor - 健康监控
# 功能: 检测 Gateway、磁盘、内存、配置、清理旧文件

# 设置 PATH（launchd 环境需要）
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

LOG_FILE="$HOME/workspace/logs/openclaw-health.log"
WARN_THRESHOLD_DISK=80
WARN_THRESHOLD_MEMORY=90
SESSION_DIR="$HOME/.openclaw/sessions"
LOG_DIR="$HOME/workspace/logs"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== OpenClaw Health Monitor Started ==="

# 1. 检查 Gateway 状态
check_gateway() {
    log "检查 Gateway 状态..."
    
    if openclaw gateway status > /dev/null 2>&1; then
        log "✅ Gateway 正常运行"
        return 0
    else
        log "⚠️ Gateway 状态异常"
        
        # 尝试修复
        log "尝试重启 Gateway..."
        openclaw gateway restart 2>&1 | tee -a "$LOG_FILE"
        sleep 5
        
        if openclaw gateway status > /dev/null 2>&1; then
            log "✅ Gateway 已恢复"
            return 0
        else
            log "❌ Gateway 仍然失败，需要手动检查"
            return 1
        fi
    fi
}

# 2. 检查磁盘空间
check_disk() {
    log "检查磁盘空间..."
    
    local usage=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
    
    if [ "$usage" -gt "$WARN_THRESHOLD_DISK" ]; then
        log "⚠️ 磁盘空间不足: ${usage}%"
        
        # 尝试清理
        log "尝试清理旧文件..."
        find ~/Library/Logs -name "*.log" -mtime +7 -delete 2>/dev/null
        find ~/.npm/_logs -name "*.log" -mtime +7 -delete 2>/dev/null
        
        local new_usage=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
        log "清理后磁盘使用: ${new_usage}%"
    else
        log "✅ 磁盘空间充足: ${usage}%"
    fi
}

# 3. 检查内存使用
check_memory() {
    log "检查内存使用..."
    
    # macOS 内存检查
    local mem_free=$(vm_stat | head -5 | tail -1 | awk '{print $3}' | tr -d '.')
    local mem_total=$(sysctl hw.memsize | awk '{print $2}')
    
    # Gateway 进程内存
    local gateway_mem=$(ps aux | grep -i "openclaw gateway" | grep -v grep | awk '{sum+=$4} END {print int(sum)}')
    
    if [ -n "$gateway_mem" ] && [ "$gateway_mem" -gt 10 ]; then
        log "⚠️ Gateway 内存使用较高: ${gateway_mem}%"
    else
        log "✅ 内存使用正常"
    fi
}

# 4. 检查配置完整性
check_config() {
    log "检查配置完整性..."
    
    local config_file="$HOME/.openclaw/config.json"
    
    if [ -f "$config_file" ]; then
        if python3 -c "import json; json.load(open('$config_file'))" 2>/dev/null; then
            log "✅ 配置完整性检查通过"
        else
            log "❌ 配置文件损坏"
            
            # 尝试从备份恢复
            if [ -f "$HOME/.openclaw/config.json.backup" ]; then
                cp "$HOME/.openclaw/config.json.backup" "$HOME/.openclaw/config.json"
                log "✅ 已从备份恢复配置"
            fi
        fi
    else
        log "⚠️ 配置文件不存在"
    fi
}

# 5. 检查并清理 Session 文件
check_sessions() {
    log "检查 Session 文件..."
    
    if [ -d "$SESSION_DIR" ]; then
        local count=$(find "$SESSION_DIR" -type f | wc -l | tr -d ' ')
        log "当前 Session 文件数: $count"
        
        # 清理 30 天前的文件
        local old_count=$(find "$SESSION_DIR" -type f -mtime +30 | wc -l | tr -d ' ')
        if [ "$old_count" -gt 0 ]; then
            log "清理 $old_count 个旧 Session 文件..."
            find "$SESSION_DIR" -type f -mtime +30 -delete
        fi
    fi
}

# 6. 检查日志文件
check_logs() {
    log "检查日志文件..."
    
    if [ -d "$LOG_DIR" ]; then
        local size=$(du -sh "$LOG_DIR" 2>/dev/null | awk '{print $1}')
        log "日志目录大小: $size"
        
        # 清理 7 天前的日志
        find "$LOG_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null
    fi
}

# 执行所有检查
errors=0

check_gateway || ((errors++))
check_disk
check_memory
check_config
check_sessions
check_logs

log "=== Health Check Complete ==="

if [ $errors -eq 0 ]; then
    log "✅ 所有检查通过"
else
    log "⚠️ 发现 $errors 个问题"
fi

echo "---" >> "$LOG_FILE"
