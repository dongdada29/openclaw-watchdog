# OpenClaw Watchdog 🐕

OpenClaw 的守护工具，包含自动更新和健康监控。

## 组件

| 组件 | 功能 | 时间 |
|------|------|------|
| **Watchdog** | 自动更新 + 回滚 | 每周日 09:00 |
| **Health Monitor** | 健康检查 + 清理 | 每天 09:00 |

## 特性

### Watchdog (自动更新)
- ✅ 每周日凌晨 09:00 自动检查更新
- ✅ 更新失败自动回滚到之前版本
- ✅ 配置自动备份
- ✅ 模型配置保护

### Health Monitor (健康监控)
- ✅ Gateway 状态检测 + 自动修复
- ✅ 磁盘空间监控
- ✅ 内存使用检查
- ✅ 配置完整性验证
- ✅ Session 文件清理
- ✅ 日志文件清理

## 快速安装

```bash
curl -fsSL https://raw.githubusercontent.com/dongdada29/openclaw-watchdog/main/install.sh | bash
```

## 手动安装

```bash
# 克隆仓库
git clone https://github.com/dongdada29/openclaw-watchdog.git
cd openclaw-watchdog

# 复制脚本
cp scripts/openclaw-watchdog.sh ~/workspace/scripts/

# 安装定时任务
cp launchd/com.dongdada.openclaw-watchdog.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.dongdada.openclaw-watchdog.plist
```

## 使用方式

### 自动更新

安装后，每周日凌晨 09:00 会自动检查更新。

### 手动更新

```bash
# 手动运行更新
~/workspace/scripts/openclaw-watchdog.sh

# 检查日志
cat ~/workspace/logs/openclaw-watchdog.log
```

### 查看状态

```bash
# 查看定时任务状态
launchctl list | grep openclaw-watchdog

# 查看当前版本
openclaw --version
```

## 工作流程

```
┌─────────────────────────────────────────────────────────────┐
│                   OpenClaw Watchdog                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. 记录当前版本                                             │
│     ↓                                                        │
│  2. 备份配置 (~/.openclaw)                                   │
│     ↓                                                        │
│  3. 执行 npm update -g openclaw                              │
│     ↓                                                        │
│  4. 测试新版本                                               │
│     ├─✅ 成功 → 完成                                         │
│     └─❌ 失败 → 自动回滚                                     │
│                 ↓                                            │
│           恢复配置 + 重启 Gateway                            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 文件说明

```
openclaw-watchdog/
├── README.md                    # 本文档
├── LICENSE                      # MIT License
├── install.sh                   # 一键安装脚本
├── scripts/
│   └── openclaw-watchdog.sh     # 更新脚本
├── launchd/
│   └── com.dongdada.openclaw-watchdog.plist  # 定时任务配置
└── docs/
    └── SKILL.md                 # OpenClaw Skill 文档
```

## 日志文件

- **更新日志**: `~/workspace/logs/openclaw-watchdog.log`
- **版本记录**: `~/workspace/logs/openclaw-version.txt`
- **配置备份**: `~/workspace/logs/openclaw-config-backup.tar.gz`

## 故障排除

### npm: command not found

如果日志中出现这个错误，说明脚本找不到 npm。修复：

```bash
# 检查脚本开头的 PATH 设置
head -10 ~/workspace/scripts/openclaw-watchdog.sh
```

### Gateway 未授权

```bash
openclaw gateway restart
```

### 手动回滚

```bash
# 恢复配置备份
cd ~
tar -xzf ~/workspace/logs/openclaw-config-backup.tar.gz

# 安装特定版本
npm install -g openclaw@2026.2.26
```

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.1.0 | 2026-03-02 | 重命名为 openclaw-watchdog |
| 1.0.1 | 2026-03-02 | 修复 launchd PATH 问题 |
| 1.0.0 | 2026-02-24 | 初始版本 |

## License

MIT License - 详见 [LICENSE](LICENSE)

## 相关项目

- [OpenClaw](https://github.com/openclaw/openclaw) - AI Agent 框架
- [openclaw-model-proxy](https://github.com/dongdada29/openclaw-model-proxy) - LLM API 代理
