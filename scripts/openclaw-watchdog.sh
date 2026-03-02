#!/bin/bash
# OpenClaw Watchdog - 智能守护
#
# 功能:
#   1. 自动更新 OpenClaw（每周日）
#   2. 保护 model-proxy 配置
#   3. 检测 proxy 故障并自动切换
#   4. 配置备份与恢复

# 设置 PATH（launchd 环境需要）
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 配置
LOG_FILE="$HOME/workspace/logs/openclaw-watchdog.log"
VERSION_FILE="$HOME/workspace/logs/openclaw-version.txt"
CONFIG_BACKUP="$HOME/workspace/logs/openclaw-config-backup.tar.gz"
PROXY_PORT=3456
PROXY_HEALTH_URL="http://localhost:$PROXY_PORT/_health"

# 原始配置备份（用于回滚）
PROXY_CONFIG_BACKUP="$HOME/workspace/logs/openclaw-models-original.json"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 检测 model-proxy 是否运行
check_model_proxy() {
    if curl -s --max-time 3 "$PROXY_HEALTH_URL" > /dev/null 2>&1; then
        return 0  # proxy 正常
    else
        return 1  # proxy 故障
    fi
}

# 保存原始配置
backup_original_config() {
    local models_file="$HOME/.openclaw/agents/main/agent/models.json"
    if [ -f "$models_file" ] && [ ! -f "$PROXY_CONFIG_BACKUP" ]; then
        cp "$models_file" "$PROXY_CONFIG_BACKUP"
        log "✅ 已备份原始 models.json"
    fi
}

# 如果 proxy 故障，恢复直连配置
restore_direct_connection() {
    local models_file="$HOME/.openclaw/agents/main/agent/models.json"
    
    if [ -f "$PROXY_CONFIG_BACKUP" ]; then
        log "⚠️ model-proxy 故障，恢复直连配置..."
        cp "$PROXY_CONFIG_BACKUP" "$models_file"
        log "✅ 已恢复原始配置"
        
        # 重启 Gateway
        openclaw gateway restart 2>&1 | tee -a "$LOG_FILE"
        log "✅ Gateway 已重启"
    fi
}

# 检查并保护 model-proxy
protect_model_proxy() {
    log "检查 model-proxy 状态..."
    
    if ! check_model_proxy; then
        log "⚠️ model-proxy 无响应"
        restore_direct_connection
    else
        log "✅ model-proxy 正常运行"
    fi
}

# 主流程
log "=== OpenClaw Watchdog Started ==="

# 1. 备份原始配置
backup_original_config

# 2. 检查 model-proxy 状态
protect_model_proxy

# 3. 记录当前版本
CURRENT_VERSION=$(openclaw --version 2>/dev/null)
log "当前版本: $CURRENT_VERSION"
echo "$CURRENT_VERSION" > "$VERSION_FILE"

# 4. 备份配置
log "备份配置..."
tar -czf "$CONFIG_BACKUP" -C ~ .openclaw 2>/dev/null && \
    log "配置已备份" || \
    log "⚠️ 配置备份失败"

# 5. 尝试升级
log "开始升级 OpenClaw..."
npm update -g openclaw 2>&1 | tee -a "$LOG_FILE"
sleep 3

# 6. 测试新版本
NEW_VERSION=$(openclaw --version 2>/dev/null)
log "新版本: $NEW_VERSION"

if [ "$CURRENT_VERSION" != "$NEW_VERSION" ]; then
    log "检测到新版本，测试启动..."
    
    # 测试 Gateway
    if openclaw gateway status > /dev/null 2>&1; then
        log "✅ 升级成功! Gateway 正常运行"
    else
        log "⚠️ Gateway 启动失败，尝试修复..."
        openclaw gateway restart 2>&1 | tee -a "$LOG_FILE"
        sleep 5
        
        if openclaw gateway status > /dev/null 2>&1; then
            log "✅ Gateway 重启成功"
        else
            log "❌ Gateway 仍然失败，开始回滚..."
            
            # 回滚
            log "回滚到版本: $CURRENT_VERSION"
            npm install -g "openclaw@$CURRENT_VERSION" 2>&1 | tee -a "$LOG_FILE"
            sleep 3
            
            # 恢复配置
            log "恢复配置..."
            tar -xzf "$CONFIG_BACKUP" -C ~ 2>/dev/null
            
            # 重启 Gateway
            openclaw gateway restart 2>&1 | tee -a "$LOG_FILE"
            log "✅ 回滚完成"
        fi
    fi
else
    log "ℹ️ 已是最新版本，无需升级"
fi

# 7. 再次检查 model-proxy
protect_model_proxy

log "=== Watchdog Finished ==="
echo "---" >> "$LOG_FILE"
