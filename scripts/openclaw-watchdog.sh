#!/bin/bash
# OpenClaw Watchdog - 自动更新看门狗
# 功能: 自动检查更新、安全回滚、配置备份

# 设置 PATH（launchd 环境需要）
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

LOG_FILE="$HOME/workspace/logs/openclaw-watchdog.log"
VERSION_FILE="$HOME/workspace/logs/openclaw-version.txt"
CONFIG_BACKUP="$HOME/workspace/logs/openclaw-config-backup.tar.gz"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== OpenClaw Watchdog Started ==="

# 1. 记录当前版本
CURRENT_VERSION=$(openclaw --version 2>/dev/null)
log "当前版本: $CURRENT_VERSION"

# 保存当前版本
echo "$CURRENT_VERSION" > "$VERSION_FILE"

# 2. 备份配置（包含模型配置）
log "备份配置..."
tar -czf "$CONFIG_BACKUP" -C ~ .openclaw 2>/dev/null && \
    log "配置已备份到: $CONFIG_BACKUP" || \
    log "⚠️ 配置备份失败"

# 3. 备份模型配置文件
MODEL_CONFIG="$HOME/.openclaw/defaults.json"
if [ -f "$MODEL_CONFIG" ]; then
    cp "$MODEL_CONFIG" "$HOME/.openclaw/defaults.json.backup"
    log "模型配置已备份"
fi

# 4. 尝试升级
log "开始升级 OpenClaw..."
npm update -g openclaw 2>&1 | tee -a "$LOG_FILE"

# 等待一下
sleep 3

# 5. 测试新版本
NEW_VERSION=$(openclaw --version 2>/dev/null)
log "新版本: $NEW_VERSION"

# 检查是否需要更新模型配置
check_model_config() {
    log "检查模型配置..."
    
    # 检查当前模型配置
    CURRENT_MODEL=$(cat ~/.openclaw/defaults.json 2>/dev/null | grep -o '"model"[^,}]*' | head -1)
    log "当前模型: $CURRENT_MODEL"
}

if [ "$CURRENT_VERSION" != "$NEW_VERSION" ]; then
    log "检测到新版本，测试启动..."
    
    # 6. 测试 Gateway 状态
    if openclaw gateway status > /dev/null 2>&1; then
        log "✅ 升级成功! Gateway 正常运行"
        check_model_config
    else
        log "⚠️ Gateway 启动失败，尝试修复..."
        
        # 尝试重启 Gateway
        openclaw gateway restart 2>&1 | tee -a "$LOG_FILE"
        sleep 5
        
        if openclaw gateway status > /dev/null 2>&1; then
            log "✅ Gateway 重启成功"
        else
            log "❌ Gateway 仍然失败，开始回滚..."
            
            # 7. 回滚到之前版本
            log "回滚到版本: $CURRENT_VERSION"
            npm install -g "openclaw@$CURRENT_VERSION" 2>&1 | tee -a "$LOG_FILE"
            
            sleep 3
            
            # 8. 恢复配置
            log "恢复配置..."
            tar -xzf "$CONFIG_BACKUP" -C ~ 2>/dev/null
            
            # 恢复模型配置
            if [ -f "$HOME/.openclaw/defaults.json.backup" ]; then
                mv "$HOME/.openclaw/defaults.json.backup" "$HOME/.openclaw/defaults.json"
                log "模型配置已恢复"
            fi
            
            ROLLBACK_VERSION=$(openclaw --version 2>/dev/null)
            log "已回滚到: $ROLLBACK_VERSION"
            
            # 重启 Gateway
            openclaw gateway restart 2>&1 | tee -a "$LOG_FILE"
            
            if openclaw gateway status > /dev/null 2>&1; then
                log "✅ 回滚成功，系统正常运行"
            else
                log "🚨 回滚后仍有问题，需要手动检查"
            fi
        fi
    fi
else
    log "ℹ️ 已是最新版本，无需升级"
    check_model_config
fi

log "=== Watchdog Finished ==="
echo "---" >> "$LOG_FILE"
