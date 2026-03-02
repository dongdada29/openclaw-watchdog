# OpenClaw Auto Updater

自动检查并更新 OpenClaw 到最新版本，支持自动回滚。

## 特性

- ✅ **自动更新**: 每周日凌晨 09:00 自动检查更新
- ✅ **安全回滚**: 更新失败自动回滚到之前版本
- ✅ **配置备份**: 更新前自动备份配置文件
- ✅ **模型保护**: 保护模型配置不被覆盖
- ✅ **日志记录**: 完整的更新日志

## 快速安装

```bash
# 一键安装
curl -fsSL https://raw.githubusercontent.com/dongdada29/openclaw-updater/main/install.sh | bash
```

## 手动安装

```bash
# 克隆仓库
git clone https://github.com/dongdada29/openclaw-updater.git
cd openclaw-updater

# 复制脚本
cp scripts/openclaw-updater.sh ~/workspace/scripts/

# 安装定时任务
cp launchd/com.dongdada.openclaw-updater.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.dongdada.openclaw-updater.plist
```

## 使用方式

### 自动更新

安装后，每周日凌晨 09:00 会自动检查更新。

### 手动更新

```bash
# 手动运行更新
~/workspace/scripts/openclaw-updater.sh

# 检查日志
cat ~/workspace/logs/openclaw-updater.log
```

### 查看状态

```bash
# 查看定时任务状态
launchctl list | grep openclaw-updater

# 查看当前版本
openclaw --version
```

## 卸载

```bash
# 停止定时任务
launchctl unload ~/Library/LaunchAgents/com.dongdada.openclaw-updater.plist

# 删除文件
rm ~/Library/LaunchAgents/com.dongdada.openclaw-updater.plist
rm ~/workspace/scripts/openclaw-updater.sh
rm -rf ~/workspace/logs/openclaw-updater.*
```

## 工作流程

```
┌─────────────────────────────────────────────────────────────┐
│                   OpenClaw Auto Updater                      │
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
openclaw-updater/
├── README.md                    # 本文档
├── LICENSE                      # MIT License
├── install.sh                   # 一键安装脚本
├── scripts/
│   └── openclaw-updater.sh      # 更新脚本
├── launchd/
│   └── com.dongdada.openclaw-updater.plist  # 定时任务配置
└── docs/
    └── SKILL.md                 # OpenClaw Skill 文档
```

## 日志文件

- **更新日志**: `~/workspace/logs/openclaw-updater.log`
- **版本记录**: `~/workspace/logs/openclaw-version.txt`
- **配置备份**: `~/workspace/logs/openclaw-config-backup.tar.gz`

## 故障排除

### npm: command not found

如果日志中出现这个错误，说明脚本找不到 npm。修复：

```bash
# 编辑脚本，确保 PATH 正确
nano ~/workspace/scripts/openclaw-updater.sh

# 检查前几行是否包含：
# export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
```

### Gateway 未授权

```bash
# 重启 Gateway
openclaw gateway restart
```

### 手动回滚

```bash
# 恢复配置备份
cd ~
tar -xzf ~/workspace/logs/openclaw-config-backup.tar.gz

# 安装特定版本
npm install -g openclaw@2026.2.23
```

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0.0 | 2026-02-24 | 初始版本 |
| 1.0.1 | 2026-03-02 | 修复 launchd PATH 问题 |

## License

MIT License - 详见 [LICENSE](LICENSE)

## 相关项目

- [OpenClaw](https://github.com/openclaw/openclaw) - AI Agent 框架
- [openclaw-model-proxy](https://github.com/dongdada29/openclaw-model-proxy) - LLM API 代理
