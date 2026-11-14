# Build 226 工作台首批验证

基线 Build225 / 3ce60422；版本保留1.1.1，内部构建226。完整路线图为 OPTIMIZATION_ROADMAP.md；本次不是全部12项的完成声明。

## 验证结果

- `tests/ISHRuntimeRun.py`：113项，通过。生产 ARM64 iSH/PTY/xterm、进程、STDIO MCP、DOM和浏览器基础回归；新增 skills 只读/热刷新/项目覆盖/会话隔离/无脚本，项目 cwd/源码副本/原项目不变/目录限额；另以四次重启验证 fakefs seed→backup→restore→reset，文件、硬链接和640权限均恢复。项目写回引擎为 harness 链接桩，不能据此声称重新验证写回。
- `tests/ISHEnvironmentRun.py`：24项，通过。真实生产离线维护类，临时目录/SQLite，预约不立刻修改、重复拒绝、取消、恢复、备份保留、宿主链接拒绝、路径祖先链接拒绝、未完成切换恢复、重建、指定快照删除。
- `tests/StorageSpaceRun.py`：42项，通过。新增 Linux 分类与不可整批误删；原文件指纹、链接、越界和受保护数据回归。
- `tests/ToolRegistryRun.py`：197项，通过。项目禁用 schema、在途调用拒绝、项目隔离及重新启用；原 A/B/C 隔离与审批条件回归。
- `tests/AgentExtensionsRun.py`：136项，通过。含20条技能元数据预算、按需正文、既有技能/记忆不覆盖、MCP和构建检查点回归。
- `tests/RuntimeAuditRun.py`：12项，通过。输出留存、进程保留与安装标记。
- `tests/MCPAccessRun.py`：29项，通过。真实 HTTP fixture；未授权、撤权与 SQL 修改调用未到达服务器。
- 环境 UI：iPhone 16 Pro Max 440×956pt、iPad Pro11 834×1210pt；生产环境页实际展示，四分组与自适应布局通过。截图为 `build/ish-regression/environment-iphone.png`、`environment-ipad.png`。
- 使用 iPhoneOS26.0.sdk 构建设备 IPA，LC_BUILD_VERSION sdk26.0、minos15.0；App/扩展由脚本 ad-hoc 签名，`codesign --verify --deep --strict`通过。安装需用户现有签名方式，未使用分发证书。

## 边界与待办

- 新增项目入口已通过完整设备编译；完整 App 模拟器目前受既有 LLVM framework 架构限制，本次 UI harness只验证生产终端/环境页，尚未覆盖首页点击、iOS26真机视觉或完整 iPad 分栏。
- rootfs 仍为内置 Alpine3.21.0。本次快照/恢复不是版本管理或跨版本迁移。
- 只读技能 mount 不等于外部目录 mount。外部目录新授权及逐项审核写回机制仍待单独实现。
- 工具开关只处理项目内置工具的可见性/执行，MCP仍沿用其现有逐工具/逐会话授权，未新增自动写权限。
- 本次未改模型、连接密钥、人设、项目记忆、构建链接和产物布局，未发布 GitHub。
