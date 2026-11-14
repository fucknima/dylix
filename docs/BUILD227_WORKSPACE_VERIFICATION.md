# Build 227 工作台验证

源码基线：`3ce60422`，版本 1.1.1，内部构建 227。所有测试使用当前源码，不使用旧 IPA 代替。

## 结果

- Mac 合约回归：AgentExtensions 154、DirectoryRegistry 47、Subtask manager 20、Subtask runtime 12、BuildQueue 10、MCP HTTP 35、ToolRegistry 197、RuntimeAudit 12、StorageSpace 42。
- iOS ARM64 模拟器：真实 iSH/PTY、进程、文件、网页预览、MCP STDIO、技能和 fakefs 维护完整回归 114 项通过；iPhone 与 iPad 外部目录和远程终端通过；iPad 工作台分栏/折叠/编辑草稿保留 26 项通过；浏览器会话/登录门控 UI 两设备通过。
- 浏览器终端：真实 xterm 资源、ANSI 输出、会话切换、撤权提示、Ctrl-C、显式尺寸同步、在途旧输出丢弃 9 项通过。
- 产物：`build/Dylix-1.1.1-build227-unsigned.ipa`，用 iPhoneOS26.0 SDK 构建，设备部署目标 iOS15；脚本完成包布局、扩展和签名结构检查。

## 设计边界

外部目录 guest 挂载是只读的；复制/写回继续经过现有审批。MCP 不直接执行项目写入、构建或 Git。技能正文、记忆和终端输出只在需要时读取；本地记忆不会自动上传。局域网远程没有公网中继和 Tailscale。模拟器是 iOS18.3 ARM64，不能宣称完成 iOS26 真机视觉测试。

## 复核证据与运行方式

- iPhone iOS18.3：A406534F-7D2B-4F72-AB5D-AC9AF178049C；iPad iOS18.3：740A5459-AA5D-4F93-BBC6-94FB9F8809C1。
- `python3 tests/AgentRuntimeRun.py SubtaskRuntimeTests.m`：真实 AIRuntime，隔离父历史与模型快照、分析/构建 allowlist、独立审批、消息组边界回注、原项目检查。传输/工具协作者使用确定性 fixture，不宣称做了真实商业模型请求。
- `python3 tests/BuildQueueRun.py`：直接包含生产 `TFAIBuildQueueCore.inc`，验证现有本机构建占用、父子任务互斥、取消边界、去重与关闭队列后的互斥。
- `python3 tests/ISHRuntimeRun.py --device <UDID>`：ARM64 iSH 实际执行，114 项通过；含真实 guest STDIO MCP 与元数据审计；四次启动验证完整 fakefs backup→restore→reset。
- `--workspace227`：iPhone23 / iPad26 检查，真实外部目录与远程PTY、启动中撤权、设备隔离；生产分栏源码引用，宽窄变化保留同一编辑器实例。附加固定镜像目录、最快源选择、原配置备份与实际 guest apk 应用，并测试匿名 HEAD 连接结束。
- `--directory-check227 1` 后再 `--directory-check227 2`：跨进程恢复已选目录挂载；已打开 FD 在撤权后拒绝读取，两阶段共6条记录通过。
- `--root227` 与 `--root-check227 1/2/3`：官方3.22归档下载/固定哈希、真实3.22启动、切回3.21、原3.22快照文件数据恢复均通过。
- `--browser-ui`：iPhone/iPad 各10条检查；真实WKWebView、标签归属、单会话8标签上限、手动登录暂停所有标签AI操作、失效tab引用拒绝、清理会话不影响其他会话。
- `python3 tests/RemoteTerminalUI.py`：真实 Chromium + xterm + 生产 renderer；Job API 是fixture，真实PTY与撤权另由上述iSH测试验证。界面测试不冒充完整手机网络服务集成。
- `node --check Resources/RemoteWeb/remote.js` 和 `git diff --check` 通过。
- `codesign --verify --deep --strict build/device/TheosMobileCompiler.app` 通过；`vtool -show-build` 显示 sdk26.0 / minos15.0。App与两个扩展版本均为1.1.1 /227。IPA ZIP完整性、xterm/远程页面/rootfs资源存在性均已检查。

## 可见性与限制

项目首页/编辑器的终端入口已经整包编译。完整App含既有x86_64 LLVM模拟器framework，无法作为ARM64完整App运行，因此模拟器UI采用引用生产UIKit源码的小型harness；编辑器内容用草稿fixture替代。横竖屏转移路径、regular宽度/窄度变化与容器所有权已测试，iOS26真机玻璃效果和实际用户工程仍需设备安装复核。

各镜像测速是本机HEAD连接耗时，只对成功HTTP源选最快；并非实测guest下载带宽。切换源先确认/备份，未关闭TLS或apk签名验证。下载可使用NSURLSession续传，服务端拒绝Range时重新完整下载；只有完整固定SHA-256通过才可安装。长期记忆不自动注入；用户按需读取时才会进入所选模型请求。

截图/结构化结果位于 `build/proof227/`。归档不能替代生产签名安装，未发布GitHub。

IPA SHA-256：`56660dd4530a3cdbe1319586509c3b8688b538c06eb45c9238026c1237417586`（224804745 字节）。
