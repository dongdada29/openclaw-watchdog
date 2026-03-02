#!/bin/bash
# Model Proxy 切换工具
# 用于在 proxy 模式和直连模式之间切换

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

PROXY_PORT=3456
PROXY_URL="http://localhost:$PROXY_PORT"
MODELS_FILE="$HOME/.openclaw/agents/main/agent/models.json"
BACKUP_FILE="$HOME/workspace/logs/openclaw-models-original.json"

usage() {
    echo "用法: $0 <命令> [选项]"
    echo ""
    echo "命令:"
    echo "  enable      启用 proxy 模式"
    echo "  disable     禁用 proxy 模式（恢复直连）"
    echo "  status      查看当前状态"
    echo "  backup      备份当前配置"
    echo "  test        测试 proxy 是否可用"
    echo ""
    echo "示例:"
    echo "  $0 enable     # 切换到 proxy 模式"
    echo "  $0 disable    # 切换回直连模式"
    echo "  $0 status     # 查看当前配置"
}

check_proxy() {
    if curl -s --max-time 3 "$PROXY_URL/_health" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

backup_config() {
    if [ -f "$MODELS_FILE" ]; then
        cp "$MODELS_FILE" "$BACKUP_FILE"
        echo "✅ 已备份配置到: $BACKUP_FILE"
    else
        echo "❌ 配置文件不存在: $MODELS_FILE"
        exit 1
    fi
}

enable_proxy() {
    echo "🔄 切换到 proxy 模式..."
    
    # 检查 proxy 是否运行
    if ! check_proxy; then
        echo "❌ model-proxy 未运行，请先启动: cd ~/workspace/openclaw-model-proxy && npm start"
        exit 1
    fi
    
    # 备份原始配置
    if [ ! -f "$BACKUP_FILE" ]; then
        backup_config
    fi
    
    # 修改 baseUrl
    if [ -f "$MODELS_FILE" ]; then
        # 使用 sed 替换 baseUrl
        sed -i.tmp "s|\"baseUrl\": \"https://[^\"]*\"|\"baseUrl\": \"$PROXY_URL\"|g" "$MODELS_FILE"
        rm -f "$MODELS_FILE.tmp"
        
        echo "✅ 已切换到 proxy 模式"
        echo "   Proxy URL: $PROXY_URL"
        
        # 重启 Gateway
        echo "🔄 重启 Gateway..."
        openclaw gateway restart
    else
        echo "❌ 配置文件不存在"
        exit 1
    fi
}

disable_proxy() {
    echo "🔄 恢复直连模式..."
    
    if [ -f "$BACKUP_FILE" ]; then
        cp "$BACKUP_FILE" "$MODELS_FILE"
        echo "✅ 已恢复直连模式"
        
        # 重启 Gateway
        echo "🔄 重启 Gateway..."
        openclaw gateway restart
    else
        echo "❌ 备份文件不存在: $BACKUP_FILE"
        echo "   请手动修改 $MODELS_FILE"
        exit 1
    fi
}

show_status() {
    echo "=== Model Proxy 状态 ==="
    echo ""
    
    # 检查 proxy 进程
    if check_proxy; then
        echo "Proxy: ✅ 运行中 ($PROXY_URL)"
    else
        echo "Proxy: ❌ 未运行"
    fi
    
    echo ""
    
    # 检查配置
    if [ -f "$MODELS_FILE" ]; then
        echo "当前 baseUrl:"
        grep -o '"baseUrl": "[^"]*"' "$MODELS_FILE" | head -5
        
        if grep -q "localhost:$PROXY_PORT" "$MODELS_FILE"; then
            echo ""
            echo "模式: 🔀 Proxy 模式"
        else
            echo ""
            echo "模式: 🔗 直连模式"
        fi
    fi
    
    echo ""
    
    if [ -f "$BACKUP_FILE" ]; then
        echo "备份: ✅ $BACKUP_FILE"
    else
        echo "备份: ❌ 无"
    fi
}

test_proxy() {
    echo "测试 model-proxy..."
    
    if check_proxy; then
        echo "✅ Proxy 健康检查通过"
        curl -s "$PROXY_URL/_stats" | head -20
    else
        echo "❌ Proxy 无响应"
        exit 1
    fi
}

# 主逻辑
case "${1:-}" in
    enable)
        enable_proxy
        ;;
    disable)
        disable_proxy
        ;;
    status)
        show_status
        ;;
    backup)
        backup_config
        ;;
    test)
        test_proxy
        ;;
    *)
        usage
        exit 1
        ;;
esac
