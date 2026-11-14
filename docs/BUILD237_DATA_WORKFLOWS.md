# Build 237 — 文件夹、数据备份与工具入口

## 任务与验证清单
- [x] 对照本地 OpenMinis 挂载与备份实现，明确 App 数据备份不等于 Linux 快照。
- [x] 设置独立「挂载文件夹」「备份与恢复」「安装工具」入口。
- [x] 文件夹页异步加载、空状态、错误反馈、系统文件夹选择器与持久授权。
- [x] 已授权目录自动出现在会话工具引用及 Linux 挂载中。
- [x] 终端主操作精简至 4 项，安装工具使用独立页面。
- [x] 本机 IPA 引用可在原会话导入 Linux，无需重复导入或换会话。
- [x] 项目、会话、附件、技能/记忆、供应商、MCP、设置分类备份。
- [x] 流式压缩与密码加密，可选加密凭据，分享/保存本机备份。
- [x] 选择分类恢复、逐文件校验、重启前恢复、覆盖前副本、失败回滚。
- [x] 备份往返、错误密码、篡改、恶意归档及跨容器测试（37 项）。
- [x] IPA 原文件导入链路回归（7 项；iSH 中真实 unzip 另行通过）。
- [x] iPhone / iPad 目录、备份、工具页面交互与布局检查（每台 15 项）。
- [x] SDK 26 设备包构建与资源/签名验证。

## 范围
项目备份包括 .git、项目技能和项目记忆；排除 .theos/build/DerivedData/node_modules/Caches。
全局技能、记忆、人设为独立分类。外部文件夹授权、设备配对、Linux 文件系统及构建缓存不迁移。
恢复采用合并并覆盖同名文件，保留备份中没有的现存文件；重启后在数据单例与 Linux 初始化前执行。
加密格式为版本化流式 AES-256-CBC + HMAC-SHA256，PBKDF2-HMAC-SHA256 600000 次，独立加密/认证密钥。
加密文件在解密前验证 HMAC。归档只允许清单内普通文件，拒绝越界路径、链接、重复条目与超限数据。

## 上游参考
OpenMinis/OpenMinis 本地快照 1a71df0f381cefde80bf912b723de6f9831bc177：
MountedFoldersSettingsView.swift、MountedFoldersManager.swift、BackupFormat.swift、BackupCrypto.swift。
本次以 Objective-C 适配 Dylix 数据布局；没有复制其 Swift 源码或声称 .minisbak 格式兼容。

## 验证记录
- `tests/BackupRun.py`：37 项通过。
- `tests/DirectoryRegistryRun.py`：47 项通过。
- `tests/IPAAttachmentBridgeRun.py`：7 项通过。
- `tests/ISHRuntimeRun.py --data237`：iPhone、iPad 各 15 项通过，含目录打开、系统选择器、原 IPA 导入及真实解压。
- `tests/DataSettings237Run.py`：iPhone、iPad 各 3 个真实设置入口及冷启动恢复通过（独立进程复核）。
- `tests/ChatNavigation235Run.py --skip-build`：完整 App 的 iPhone 17 项、iPad 20 项通过。
- 设备 IPA：1.1.1 / Build 237，LC_BUILD_VERSION SDK 26.0，最低 iOS 15；codesign 深层验证及 ZIP 完整性通过。
- 离线开发与逆向工具包均包含在 IPA 中。证据位于 `build/data237-evidence/`。
- 验证环境是模拟器和主机隔离测试，未声称完成真机 Files/iCloud 授权验证。

## 挂载范围
目录登记供全部会话按需使用；Linux 挂载为可撤销的只读文本视图，保留原有文本大小与敏感文件过滤。二进制文件使用“复制到 Linux”导入后分析，不是可写通用宿主文件系统。
