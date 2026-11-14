<div align="center">

# Dylix

**把插件开发工作台，放进口袋。**

iPhone / iPad 本机构建 · AI 开发助手 · 项目与 Git · 二进制工具

[![License: GPL v3+](https://img.shields.io/badge/License-GPLv3%2B-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%20%2F%20iPadOS-black.svg)](#构建与安装)
[下载 IPA](https://github.com/yangokok886/dylix/releases/latest) · [界面预览](#界面预览) · [更新日志](CHANGELOG.md) · [构建文档](docs/BUILDING.md) · [第三方许可](THIRD_PARTY_NOTICES.md) · [问题与建议](https://github.com/yangokok886/dylix/issues)

</div>

当前版本：**1.1.3（272）**，配套 **FLEX 插件 1.0.3**。本次改进上下文保留、定向历史读取、重复纠偏和回答风格，支持仅导出会话或携带附件导出；新增多档预算与真实 API 对照验证。终端工具与 iOS 26 SDK 按需安装。

[1.1.3 更新内容](docs/RELEASE_1.1.3.md) · [服务商与 Agent](docs/AGENT_EXTENSIONS.md) · [FLEX 联动](docs/FLEX_DYLIX_BRIDGE.md) · [连接传输](docs/CONNECTION_TRANSPORT.md)。

## 这是什么

Dylix 是原生 iOS 插件开发工作台：在手机上管理源码、编辑代码、调用内嵌 Clang / LLD 和 Logos，并生成 dylib 与 deb。AI 可以按权限读取头文件、解释代码、修改项目、检查构建结果；编译工作在设备本机完成。

它使用进程内 LLVM 工具链，并非完整 Theos shell 环境。现有 Theos 工程会经过受支持的 Makefile / 配置解析；任意脚本、Xcode 工程和完整 make 语义并不等同于已支持。

## Dylix Remote · 局域网远程工作台

Build 160：在手机「设置 → 远程开发 → 局域网远程」开启 HTTP 服务，同一 Wi-Fi 的电脑访问手机显示的地址。网页和 Monaco 随 App 离线打包，正确授权码即可连接；支持一次性随机码与钥匙串保存的固定码，倒计时每秒更新。默认关闭服务。

项目编辑、构建、Git、AI、分析与 WebDAV 已接入手机端业务入口；工作区权限由配对时勾选，写入与危险操作仍独立确认。工作台与 WebDAV 均采用 HTTP，局域网传输为明文；没有证书配置步骤。Remote 与 AI 共享音频辅助并分别管理使用状态，遵循音频开关及 iOS 后台限制。

后台先申请系统有限执行时间；开启音频辅助时由 Remote / AI 分别持有使用状态，避免互相提前停止。系统挂起或宽限耗尽时可能暂停监听，返回前台恢复服务与原授权。锁屏后受保护文件须解锁访问；不承诺永久后台。Finder / Windows 挂载及 iOS 15 / 26 真机长期锁屏仍待验证。

在线编辑支持多语言语法高亮、多标签、默认自动保存、撤销重做、修改前备份与冲突校验；导航可折叠，文件栏可拖动调整或收起，并支持全屏编辑。上传下载不设置固定文件大小上限，实际受设备存储、内存及系统网络状态影响。

<p align="center"><img src="docs/images/remote/editor-fullscreen159.png" width="100%" alt="Dylix Remote 全屏在线编辑实测界面" /></p>

[架构与实施方案](docs/LAN_WORKSPACE_ARCHITECTURE.md) · [接口文档](docs/LAN_WORKSPACE_API.md) · [测试记录](docs/LAN_WORKSPACE_TESTS.md)

## 可以做什么

- **本机构建**：Objective-C、Objective-C++、C、C++、Logos；dylib 与 deb；多种包布局与产物命名。
- **项目与编辑**：模板创建、源码导入、文件浏览、语法着色、查找替换、项目配置、构建诊断及修改备份。
- **AI 工作流**：多连接/多协议、流式 Markdown、代码块、思考与工具过程折叠、编辑重发、会话文件入口。
- **普通会话也能开发**：列出、创建、克隆及选择项目，经目标确认后在原会话中继续编辑与构建。Git、下载、写入等操作遵循当前权限策略。
- **文件与版本管理**：系统分享导入、只读目录授权、附件按需读取；libgit2 本地版本与 GitHub / Gitee 同步。
- **本地分析工具**：IPA Objective-C 头文件导出、Mach-O / dylib 静态信息检查、ARM64 反汇编、离线崩溃分析与符号匹配；导入的 Debian 包会在本机解开后按需分析。
- **后台辅助与存储**：系统后台任务、可选音频辅助、完成通知、分类及按文件清理。

## 界面预览

从打开项目、编写源码，到让 AI 协作、在本机生成产物，主要操作都在同一个原生工作台中完成。

### 写代码，也管理整个项目

<p align="center">
  <img src="docs/images/projects.png" width="280" alt="Dylix 项目模板与包信息设置" />
  &nbsp;&nbsp;
  <img src="docs/images/editor.png" width="280" alt="Dylix 原生源码编辑器" />
</p>

项目模板、最近项目、文件标签、语法着色与编辑快捷栏。当前架构、SDK 和最低系统版本直接显示在编辑器底部。

### AI 协作，过程和正文各有位置

<p align="center">
  <img src="docs/images/chat.png" width="280" alt="AI 会话中的 Markdown 与代码块" />
  &nbsp;&nbsp;
  <img src="docs/images/files.png" width="280" alt="会话文件与项目文件入口" />
</p>

回复支持 Markdown 与独立代码块，处理过程可以折叠；附件、项目文件和生成内容从会话文件入口查找。开发操作按当前权限执行，普通会话也能创建或选择项目。

### 本机构建，产物有据可查

<p align="center">
  <img src="docs/images/artifacts.png" width="280" alt="实际本机构建生成的 dylib 与 deb" />
  &nbsp;&nbsp;
  <img src="docs/images/sdk.png" width="280" alt="SDK、最低系统版本及产物构建设置" />
</p>

内嵌 Clang / LLD 与 Logos，在设备本机编译；查看构建记录、导出 dylib / deb。SDK 16.4 / 26.0 可选，最低系统和包布局按项目配置。

### 版本管理与工作台设置

<p align="center">
  <img src="docs/images/git.png" width="280" alt="本地 Git 变更、暂存与提交" />
  &nbsp;&nbsp;
  <img src="docs/images/settings.png" width="280" alt="Dylix 设置与开源许可证入口" />
</p>

本地 Git 管理变更、提交与历史，远程支持 GitHub / Gitee。工作台集中提供编辑器、存储空间、开发工具和许可证入口。

> 截图来自开源版 Build 134 的 iOS 模拟器；项目与 AI 对话使用演示数据。构建产物截图来自示例项目的实际本地编译；编译通过仍需在目标设备和宿主中验证运行效果。

## 会话 Linux 终端

Build212 新增内嵌 iSH ARM64 内核、Alpine 文件系统、PTY 和离线 xterm 页面，入口为“会话 → Agent 能力 → Linux 终端”。每个会话保留独立文件，AI 经确认后可以执行 Linux 命令、复制已选附件，并将生成文件导出到本会话文件列表；终端菜单也能直接分享沙盒文件。聊天 deb 附件可以在本机解开并按需浏览；小文本直接携带正文。

完整链路、复现命令和限制见 [iSH 集成说明](docs/ISH_SANDBOX_INTEGRATION.md)。Linux 终端不等于 iOS 宿主 Shell，不挂载原项目；插件构建继续使用已有审批和本机工具链。

## 构建与安装

开发主机为 macOS + Xcode / Apple Command Line Tools，另需 Python 3、CMake、Rust stable、Meson、Ninja 和 LLVM ld.lld。
App 最低目标为 iOS 15；部分界面和后台能力按系统版本启用。当前模拟器构建脚本使用 x86_64（Apple Silicon 主机需安装适用的模拟器运行环境或自行扩展架构）。

```sh
git clone https://github.com/yangokok886/dylix.git
cd dylix
python3 scripts/fetch_toolchain.py
rustup target add aarch64-apple-ios x86_64-apple-ios
python3 scripts/build.py --sdk-root LocalSDKs/iPhoneOS26.0.sdk
```

输出 `build/Dylix-1.1.1-build225-unsigned.ipa`。安装前使用自己的证书/适用安装方式处理主 App、Share Extension 和嵌套 framework 签名。仓库不包含个人证书、描述文件或共享 API 密钥。

设备版默认要求 SDK26+；旧 Xcode 可通过 `DYLIX_SDK_26_0` 指向完整 SDK26 目录，缺失时停止构建。

**两个 SDK 角色不同**：`--sdk-root` 决定 Dylix App 自身的构建 SDK；内嵌插件构建 SDK 可选 16.4 / 26.0，默认仍为 **SDK 16.4 + 最低 iOS 15**。

完整环境配置、模拟器构建、依赖来源、测试与签名说明见 [docs/BUILDING.md](docs/BUILDING.md)。仓库附带 SDK 16.4 与 26.0 构建输入；Apple SDK 保留 Apple 原有条款，不适用本项目 GPL。工具链通过下载脚本自动还原。

## AI、隐私与运行边界

模型连接由用户配置，API 密钥保存在系统钥匙串。发送聊天或调用读取工具时，相应文本会提交到选定模型服务；联网搜索也会访问对应服务。文件夹授权是按需只读访问，不会一开始把全部文件上传。

项目写入、构建和 Git 操作使用注册工具与范围校验；完全访问只针对当前项目。后台运行受 iOS 调度、音频中断、设备资源及用户设置影响，并非永久保活保证。

IPA 导出依据 Objective-C 元数据，不等于还原源码。加密镜像会被识别并跳过；本项目没有通用解密或任意二进制执行入口。编译成功也不证明插件在目标 App 内的运行效果。

设置中的“项目开源地址”打开本仓库，其下“软件许可证”可离线查看 GPL 完整条款。问题与建议请通过 GitHub Issues 提交并先脱敏。

## 许可证与致谢

**开发协作**：本项目由 Xuegao 主导开发，OpenAI Codex / ChatGPT 辅助实现、调试与文档编写。

Dylix 原创代码与修改采用 **GNU General Public License v3.0 or later（GPL-3.0-or-later）**，完整条款见 [LICENSE](LICENSE)。分发修改版或二进制时，请遵循 GPL 对相应源码、许可文本和必要构建材料的要求；软件按现状提供，不附带担保。

第三方代码保留原许可证，详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。感谢 LLVM / Clang / LLD、ios_system、Perl、Theos Logos、libgit2、REipa、Monaco Editor、MBProgressHUD、highlight.js、diff2html 等项目。第三方许可不因本项目采用 GPL 而被替换。

欢迎通过 [贡献说明](CONTRIBUTING.md) 一起改进 Dylix。

### Linux 终端与逆向分析（Build 213–215）

终端与 AI 共享会话隔离的 Alpine 文件系统，支持持续 PTY 进程、增量读写、状态列表、停止和实际本地 HTTP 网页预览。终端菜单可安装随包的官方签名 Python/Node/npm/Git/curl/分析工具离线套件。详见 [运行、测试及真实限制](docs/ISH_SANDBOX_INTEGRATION.md)。iOS 插件编译继续使用本机 Clang/LLD/Logos 和现有审批，不把 guest Linux 编译冒充 iOS 编译。

Build 214 新增终端菜单内的 Linux 文件管理、审核写回文本、本地 STDIO MCP，以及仅面向会话自有服务器的网页操作闭环。配置与边界见 [Linux 沙盒集成说明](docs/ISH_SANDBOX_INTEGRATION.md)。

Build 215 新增 Ghidra/radare2 真实近似 C 反编译、函数/CFG/xrefs/P-code 分析，Linux 批量文件与目录审核写回、MCP 向导与钥匙串环境变量，以及公开网页 DOM 交互和临时截图。仅对已选暂存二进制副本操作，分析有超时和取消；完整边界见 [Linux 沙盒集成说明](docs/ISH_SANDBOX_INTEGRATION.md)。


## OpenCode Go（独立 Fork 增强）

进入「AI 模型与连接」→「添加服务商」→「OpenCode Go」，填入从 OpenCode Console 获取的 Go API Key；默认模型为 `glm-5.3-flash`，也可获取实时模型列表重新选择。

正式对话、工具续轮与同源重定向均携带稳定的 `x-opencode-session`（使用本地会话 UUID）；模型发现和能力测试使用临时 UUID。默认 `User-Agent` 为 `Dylix-Go/1.0`，与上游自定义请求头功能共存，且会话头在自定义头之后写入，不会被覆盖。API Key 仍按原版机制保存在 iOS 钥匙串。

官方接口：`https://opencode.ai/inference/go/openai/v1/chat/completions`；模型列表：`https://opencode.ai/inference/go/v1/models`。OpenCode Go 主要服务于代码 Agent 场景，模型和能力按服务商当前政策、订阅权限和实际测试结果决定。

本 Fork 在 `.github/workflows/` 增加构建及上游同步：同步成功时自动触发新的无个人证书 IPA 编译；存在合并冲突时停止而非强制覆盖。构建生成的 `Dylix-Go-unsigned.ipa` 是需后续自行签名的安装包，不是已用个人开发者证书签署的包。
