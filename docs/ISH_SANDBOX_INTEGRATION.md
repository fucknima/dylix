# 内嵌 Linux 终端与逆向分析 · Build 215

## 实现

Dylix 静态链接 `OpenMinis/ish-arm64` 的 ARM64 Asbestos 内核、模拟器与 fakefs，运行官方 Alpine 3.21.0 aarch64 minirootfs。未启用 JIT，不依赖独立 iSH App，也不把 ios_system 或本机 Clang 冒充 Linux Shell。

入口：会话 → Agent 能力 → Linux 终端。终端使用离线 xterm.js、原生 WKWebView 和 PTY，支持键盘、ANSI、中文、窗口尺寸变化、Ctrl-C、Tab 和历史方向键。返回聊天保留当前 shell；App 被系统结束后只保留文件，不自动重放未完成命令。

一个 App 内核管理多个会话文件系统。会话 ID 经 SHA-256 映射到 Application Support 下的目录，首次原子导入 fakefs，之后复用。默认工作目录 `/workspace`，文件副本位于 `/workspace/imports`。聊天 AI 的命令和同一会话终端共享文件，但使用独立进程。

## AI 与文件链路

- `sandbox_execute`：执行 Linux 命令，1–600 秒超时，最多 8 个并发 AI 命令；结果包含退出码、取消、超时、截断状态。一次性命令仍返回有界尾部，超长结果应重定向到 guest 文件后分段读取。
- `sandbox_import_attachment`：仅复制用户已选附件或授权目录内的一个普通文件；再次验证授权和副本哈希。不会挂载原项目或赋予原文件写权限。
- `sandbox_export_file`：将本会话 Linux 普通文件复制到本机会话文件列表；返回会话绑定的 opaque ID，不向模型开放宿主目标路径。终端菜单也可输入 guest 路径后直接分享。拒绝目录、符号链接及越界路径，单文件上限 1 GiB。
- 所有 Linux 工具均受独立“Linux 沙盒”开关、运行库可用性、会话和人工确认控制。只读模式不下发，授权后执行前重新检查；停止 AI 取消该会话的 AI 命令。
- 终端菜单可以直接选择本机单文件副本。拒绝符号链接，按打开的 fd 读取，单文件上限 1 GiB。已有项目写入、构建及 Git 仍使用原工具和审批流程。
- 聊天导入 `.deb` 使用原生 libarchive 解开 ar、data 和控制层，脚本仅作为文件保留，不执行或安装。小文本附件直接携带正文，大文本和解包目录继续按需读取。

## 持续进程和真实网页预览

- `sandbox_process_start/list/read/write/resize/stop` 使用会话绑定的 opaque process ID，支持交互式 PTY、增量字节游标、非 UTF-8 的 base64、退出码、取消和可选超时。默认不设置任务超时，App 结束不会伪装继续运行。默认最多 8 个 AI 进程（可在 4–8 间配置），单次读取不超过 16 KiB；持久 AI 进程默认保留 1 MiB 内存环（可配置为 256 KiB–8 MiB），并自动把输出落盘到当前会话日志，最多 64 MiB/进程。`process_read` 使用同一 offset/next_offset 分页读取日志，只有超出日志保留范围才报告 `missed_bytes`。交互式人工终端仍使用独立的短内存回放环。
- 终端菜单“会话进程 / AI 运行输出”可打开同一进程进行查看和输入；切换页面不停止任务。停止进程会清理其同一上下文的子进程。输入确认仅表示排入 PTY，不冒充命令实际成功。
- 重启保留最多 32 条不含命令/输出/环境秘密的状态记录；运行中任务标记为 `interrupted_by_app_restart`，不自动重放。文件系统继续保留。
- `sandbox_preview` 先校验运行中进程实际持有的监听端口，再使用隔离 WKWebView 读取真实 JS 渲染正文和链接。需前台运行，不使用公共浏览器账号 Cookie。UI 菜单“预览本地网页”打开同一真实服务器，可刷新及分享截图。
- TCP 通配监听绑定到设备 loopback，不能意外暴露到局域网；首版预览 URL 使用 IPv4，服务器请绑定 `127.0.0.1`。停止后不能再使用该进程的预览权限。此模块不声称是经过安全审计的网络容器。
- start/write/resize/stop/install 仍逐次确认；list/read/preview 不修改项目，执行前重新检查开关、会话和前台条件。

## 隔离与稳定性

不注册宿主 offload、任意宿主 Shell 或 live project mount。guest 的 `..`、绝对符号链接和 getcwd 受会话 root 约束；禁用 guest mount/umount/chroot/ptrace，信号与 PTY 不能操作其他命令上下文或 PID 1。这里是 App 内嵌的用户态模拟器，不应当作经过独立安全审计的虚拟机。

内存用专用队列持续采样，并在 App 恢复后首次内存分配时刷新，避免采样过期造成假性 OOM。输出保留有界尾部和终端回放；启动失败释放未运行进程资源。文件系统初始化失败保留原环境，不清除已有人设、技能、记忆和项目。

## 工具安装与限制

Alpine minirootfs 是最小系统。本版另带官方签名的离线开发工具包：终端菜单“安装 Python / Node / 开发工具”，或由 AI 调用 `sandbox_install_tools`。首次确认安装后记录为 App 级工具能力；后续新会话第一次打开终端或启动 Linux AI 进程时自动补齐到自己的会话文件系统，不共享 `/workspace` 和进程。安装先校验归档 SHA-256，再由 guest apk 按 Alpine 内置可信密钥校验每个 APK，禁止 `--allow-untrusted`。过程作为任务返回，可增量查看进度。

包含 Python/pip、Node/npm、Git、curl、binutils、file、make、patch、tar、xz、zip、unzip 及依赖。包版本、官方地址、哈希、许可证和 origin 在 `Resources/iSH/developer-tools.json`。其他 Alpine 软件仍可自行通过官方 apk 仓库安装，是否可运行取决于模拟器实现的 syscall 和资源，并非任意 Linux 软件均兼容。

真实网页示例（先安装离线工具）：

```sh
python3 -m http.server 0 --bind 127.0.0.1 --directory /workspace
```

用进程列表读取实际端口，再打开预览，不能把任意地址冒充自己的服务器。DNS 在每次准备会话时跟随设备系统 resolver；仅当无配置时使用 fallback。
原生聊天 deb 解包无需先安装 binutils。Linux 包管理器安装的是 Linux 用户态工具；iOS 插件编译仍使用 Dylix 现有 Clang/LLD/Logos 工具链。ARM64 解释执行速度低于原生；网络、iOS 后台调度和内存仍受设备与系统限制。

Build 212–214 没有集成反编译器；Build 215 新增下述 Ghidra/radare2 引擎。未加入未知密钥恢复、FairPlay 解密或宿主动态注入。

## 构建与复现

需要 Apple Clang、Python、Meson、Ninja 和 LLVM `ld.lld`（仅用于 guest ELF VDSO）。`DYLIX_LLD` 指定 ELF linker，不要把下载的 clang/ld64 全局覆盖 Apple 工具链。

```sh
python3 scripts/build_ish.py --platform device
python3 scripts/build.py --sdk-root LocalSDKs/iPhoneOS26.0.sdk
python3 tests/ISHRuntimeRun.py --packages --network
python3 tests/ToolRegistryRun.py
python3 tests/ToolRegistryRuntimeRun.py
```

设备和模拟器静态库分别输出；manifest 记录源码指纹、架构、平台、JIT 状态与归档 SHA-256。源码变化会触发增量重建，App 构建再次校验归档。

`tests/ISHRuntimeRun.py` 使用实际生产 runtime 和 terminal 文件，在 ARM64 iOS 模拟器 UIKit harness 中执行。Dylix 原有 LLVM 模拟器框架只有 x86_64，所以不能将此测试冒称为完整 Dylix ARM64 模拟器端到端测试。真机安装运行仍需单独验证。结果保存在 `build/ish-regression/results.json`，终端截图为同目录 `terminal.png`。

## 验证与交付

测试包含真实进程交互、跨会话拒绝、环形缓冲、UTF-8 字节游标、超时、离线 APK 签名安装、Python/Node/npm/Git/curl、真实 HTTP 监听端口与 WKWebView JS 预览、停止回收、终端 UI 和重启持久化。Build 213 最终通过 47 项（含独立测试应用中使用生产终端页面输入/读取 AI 进程、真实 DNS/HTTPS）、190 项注册表检查、107 项附件检查和 27 组解包测试。逐项结果随构建交付，位于 `build/ish-regression/results.json`。`--network` 为额外联网检查，离线环境可不传该参数。

工具注册表与真实 AIRuntime 审批分发另有 Foundation harness；附件和原生 deb 解包回归继续保留。生产源文件在 ARM64 iOS 模拟器 harness 中运行，不能冒称完整 Dylix 真机或 ARM64 模拟器 App 端到端测试。真机键盘、低内存和长时间后台需在目标设备验证。

## 来源与许可证

iSH 固定 revision `c5c264da19148512167aa493d7bd4e50aae1b74e`，完整对应源码和原有声明保存在 `Vendor/iSH`，修改清单见 `Vendor/iSH/DYLIX-NOTICE.md`。遵循 GPLv3 与 LICENSE.IOS；仓库 LICENSE 附完整 GPL 文本。

Alpine 官方 minirootfs 原始归档未经改写，SHA-256：`f31202c4070c4ef7de9e157e1bd01cb4da3a2150035d74ea5372c5e86f1efac1`，在导入前校验。xterm 5.5.0 与 addon-fit 0.10.0 的 MIT 原始声明在 `Resources/Terminal`。原生 Objective-C 适配层参考 OpenMinis / Kelivo 的内核与 PTY 结构，未复制其 Swift/Flutter 页面。

## Build 214：文件、STDIO MCP、本地网页操作

- **文件管理**：终端右上角菜单 → Linux 文件管理。通过 guest VFS 列目录、浏览父目录、创建目录/文本、编辑 UTF-8、导入副本、导出分享。目录最多返回 2000 项；文本预览/编辑上限 256 KiB，其他文件可导出。拒绝 `..`、特殊设备和符号链接。保存使用内容 SHA-256 前置条件和同目录临时文件原子替换。
- **写回项目**：从关联项目的会话进入终端，打开 Linux 文本后点「写回项目」，输入项目相对路径；复用 `TFAIToolbox` 的 propose/apply/create 计划、`TFAIRuntimePolicy`、原生差异审批、Git 租约、哈希复核、备份和撤销。仅支持文本单文件，不能直接挂载项目目录，也不自动导回构建产物。当前没有将文件夹整批写回项目的入口。
- **本地 MCP**：Agent → MCP 服务 → 导入 JSON。HTTP 原配置和钥匙串请求头保持兼容；STDIO 必须显式声明 transport，由用户在本会话确认启动。程序和依赖必须已安装在该会话的 Linux 内。使用独立原始 stdin/stdout/stderr，而非 PTY；参数直接传递给 guest exec，无宿主子进程、shell 字符串拼接或项目挂载。stderr 只留 16 KiB 本地内存尾部，不混入协议；单响应 8 MiB、30 秒超时，拒绝错误匹配，支持分片 JSON/通知和串行请求。关闭会话开关、删除服务或关闭 MCP 总开关会回收本地进程；App 重启不自动执行服务器。
- **只读约束**：工具必须同时有 `readOnlyHint:true`、`destructiveHint:false`，通过工具名/参数检查并由用户逐项启用。声明不是可信执行隔离；服务器仍可修改自己的 Linux 沙盒文件，所以只运行可信服务。工具不能绕过 Dylix 的项目写入、构建和 Git 审批。暂不导入 STDIO `env` 或密钥参数。
- **网页闭环**：先 `sandbox_preview` 打开真实进程端口，再 `sandbox_browser` 做 observe/click/type/select/scroll。页面按会话与进程保留，返回新快照、元素 ID、正文和坐标；旧快照、失效元素、跨会话、已停止服务器、外部地址、密码和文件输入会被拒绝。操作走人工审批，派发后自动重新观察，不能仅凭 dispatched 宣布业务成功。仅支持当前会话自己的本地开发预览，不是公共网站自动登录器。
- **截图**：本地预览可人工分享截图；AI screenshot 仅在模型图片能力验证为 supported 时出现在 schema，且需要批准。JPEG 最多 120 KiB，仅作为下一轮临时图片输入，结果和聊天历史不保存图片正文。

STDIO 配置示例（路径需替换成你在 Linux 安装的服务器）：

```json
{"mcpServers":{"本地查询":{"transport":"stdio","command":"/usr/bin/python3","args":["-u","/workspace/server.py"]}}}
```

验证覆盖生产 VFS、raw pipe、完整 MCP 发现/授权/调用、原生文件列表、WKWebView 操作与原有终端；项目写回底层另跑真实 toolbox 回归。模拟器 harness 的项目写回 UI 依赖只作链接替身，不能把它算成完整 Dylix 真机端到端验证。

## Build 215：四项补齐

### 真实反编译与静态分析

终端菜单「安装 Ghidra / radare2 逆向工具」会将官方 Alpine 签名的 16 个 aarch64 APK 安装到本会话 `/opt/dylix-reverse`。独立 musl loader 和库路径，不更新基础 Alpine 3.21 或其开发工具；归档 SHA-256、包校验、版本、来源和源配方 commit 见 `Resources/iSH/reverse-tools.json`。没有 `--allow-untrusted`，不运行 APK maintainer scripts。

AI 的 `sandbox_reverse` 仅在用户选择了二进制附件且 Linux 可用时下发。先 install 并读取 process_id 的退出码，再选择 functions、decompile、cfg、xrefs、disassemble、strings、imports、sections 或 pcode。slice 可选择 FAT 的 ARM64/arm64e 切片（默认 0），先验证并提取为独立薄文件，避免引擎选错架构。地址必须来自对应切片的可执行节；加密映像会拒绝，输入只复制进会话沙盒，不执行输入二进制。使用 radare2 6.2.6 和 r2ghidra 6.2.6 的原生 Ghidra 引擎；无需 Java。

每次返回 process_id 和 `/workspace/analysis/<UUID>/` 下的结果文件，不把整份反编译结果直接塞进上下文。用 process_read 确认完成，再用 sandbox_files read 的 offset/next_offset 逐页读取（最多 16 KiB），支持 UTF-8 边界；可在 Linux 文件管理中导出分享。单次分析最多 120 秒，可 process_stop 取消。错误、空/null 结果不能当作成功。原生 binary_inspect 也新增 functions、cfg、xrefs，入口来自符号及 LC_FUNCTION_STARTS，直接 ARM64 分支含 B/BL、B.cond、CBZ/CBNZ、TBZ/TBNZ；间接目标仍明确标记未解析。

Ghidra 输出近似 C，不恢复原始 Swift/Objective-C 项目，类型、变量名、函数边界与间接引用可能不完整。原生 CFG 是有界候选图，不证明可达性或间接目标；xrefs 原生快速路径只扫描当前指令节的直接代码引用。复杂混淆、巨型函数、低内存和 ARM64 解释执行仍有限制，不能保证所有输入都能反编译。真机性能与安装需实测。

### 文件与项目回写

Linux 文件管理菜单可多选复制/移动、单项改名、递归搜索文件名/路径。目标仅 `/workspace`，移动源同样限制在 `/workspace`；不覆盖已有目标，不跟随链接或特殊设备。批次预检后执行，失败回滚已创建/移动项；最多 50 源、1000 条目、24 层、64 MiB。

「审核目录并写回项目」收集最多 24 个 UTF-8 文件、单项 256 KiB、总计 1 MiB，二进制和超限项明确跳过。保留目录相对路径，只处理新增/修改，不删除项目文件。目标父目录须先通过现有项目界面/工具创建。整个批次交给现有项目差异界面，可选择修改，批准前不写入；使用原有 Git 租约、构建保护、哈希复核、事务备份和撤销。不挂载项目目录。

### MCP 设置与密钥

MCP 服务新增本地 STDIO 向导和 JSON 导入，支持依赖探测（可执行文件、Python、Node、npm）和手动安装官方离线开发工具。服务专用 npm/pip 依赖由用户在终端明确安装，不自动执行导入配置中的安装脚本。配置菜单显示运行状态、环境变量名、工具数量与依赖诊断，不显示变量值。

STDIO env 使用钥匙串与现有 HTTP 请求头同级保存，JSON 文件只记录环境变量名。启动时结构化传给 guest exec，不拼 shell，不保存到进程历史；总计最多 64 项、32 KiB。拒绝 PATH/HOME/ENV/BASH_ENV/IFS/PWD、LD_*、DYLD_* 等运行时覆盖变量。钥匙串失败会拒绝保存，不退回明文。修改 env/配置或关闭开关会回收旧进程、撤销本会话旧 schema；重启不自动启动服务器。只读工具声明与显式名单仍是选择策略，不是对恶意服务器的安全证明，保持 Linux 与项目审批隔离。

### 公开网页交互

公开浏览器增加 observe/click/type/select/screenshot，与原有导航、正文、链接、滚动和历史配合。观察最多 120 个可见控件与 16K 正文，不返回输入值。操作要求本次 snapshot/id、当前节点签名、可见性、前台、功能开关与用户确认；只读会话不下发点击/输入/选择。拒绝密码、文件、敏感表单和 POST 表单，不保存网站账户，不自动登录。

点击/输入/选择触发真实 DOM 事件后重新观察；dispatched 只表示已投递，不是业务成功。导航、页面变化或授权撤销使旧令牌无效。截图使用真实 WKWebView snapshot，缩为最多 640 像素长边、JPEG 不超过 120 KiB；仅向已验证图片能力的模型下发，沿用临时图片通道，不把 base64 写进聊天历史。页面内容始终是不可信数据，不能授予项目操作权限。

### Build 215 验证

ARM64 iOS 模拟器中使用生产代码的 UIKit harness：104 项 Linux/PTY/文件/MCP/真实 WebKit DOM/截图/取消/重启检查通过；单独 17 项签名包安装和真实逆向引擎检查通过（含 ARM64e），测试 Mach-O 的算术函数恢复为 `return arg1 * 3 + 7;`，并验证 functions/CFG/xrefs/disassembly/P-code。真实项目工具 366 项、附件 107 项、原生二进制/导入 122 项通过。AIRuntime 审批与撤销另有 fixture 测试。测试结果随构建交付。

这不是完整 Dylix ARM64 模拟器 App 或真机端到端测试：旧 LLVM simulator frameworks 仅有 x86_64。公开浏览器网络导航保护与已有模块保持，新增 DOM 事件及截图使用生产 helper 在真实 WKWebView 测试。设备性能、后台及键盘交互仍需用户设备验证。
