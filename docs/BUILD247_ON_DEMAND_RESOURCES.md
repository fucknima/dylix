# Build 247：工具与 SDK 按需下载

版本保持 1.1.1，构建号 247。按用户要求，把可选 Linux 工具与 iOS 26 SDK 从 IPA 移到 dylib.cn 静态资源目录。

## 安装包变化

- Build 246：316,018,129 字节，301.38 MiB。
- Build 247：103,582,450 字节，98.78 MiB。
- 减少 67.22%。这是 IPA 压缩包大小，不是安装后占用；按需安装后工具仍占本地存储。
- 移出：开发工具 TAR、逆向工具 TAR、重复的 GuestTools、SDK26.zip。
- 保留：小型 Alpine 基础环境、iOS 16.4 SDK、原生签名 Clang/LLVM/LLD 等编译组件、资源清单和许可说明。

## 行为与 UI

1. 安装工具页直接显示未安装、检查、下载百分比、校验、安装、已安装、卸载及错误状态。
2. 点击未安装单元格开始准备，安装不自动跳转终端。需要时可主动打开任务输出。
3. 已安装点击弹出卸载菜单；Linux 工具可单独清除下载缓存并保留安装。
4. 安装结果由进程退出状态和实际可执行文件检测决定，不把任务启动当作安装成功。
5. 工具持久保存在对应 Linux 环境；App 重启仍存在。下载缓存全局共享，新环境按已选套件自动配置。卸载当前环境并关闭新环境自动安装，其他已有独立环境保留。
6. 旧版开发工具没有包所有权记录时，拒绝盲目卸载用户包，提示重建该环境；新版使用 apk 虚拟包记录套件依赖。
7. AI 原有开发/逆向工具安装入口连接同一下载器；选择 iOS 26 SDK 构建时，工作线程自动获取并解压 SDK。主线程不等待网络。
8. iOS 26 SDK 保存于 Application Support；兼容迁移旧缓存。iOS 16.4 继续支持离线准备。

## 下载与完整性

固定资源位于 `https://dylib.cn/downloads/dylix/v1/`，文件名包含哈希前缀。App 内清单固定完整 SHA-256 和字节数。HTTPS 下载拒绝跳转，使用临时会话，不保存 Cookie；大小或哈希不符不安装。同一资源并发请求合并，支持取消及重新点击重试；暂不提供断点续传。

下载内容限 SDK 数据和隔离 Linux 环境归档，不下载加载替代 iOS 原生签名 Framework。

## 实际验证

- 最新真机目标 IPA：使用 iPhoneOS 26.0 SDK 重新编译成功，版本/构建号核对通过。
- 最新完整模拟器 App：编译成功。
- 生产下载器、SDK 提取器和真实 guest runtime：本地 HTTPS 服务集成检查 16 项通过；重启及卸载检查 8 项通过。包含 404、超大响应、错误哈希拒绝、并发 SDK 请求、真实工具执行、重复安装跳过、状态 UI 及持久安装。
- Python、Node、Git、ldid、radare2 在下载安装后真实执行成功。
- 完整 App 挂载附件回归：iPhone 模拟器 12 项、iPad 模拟器 12 项通过。
- 最终 IPA ZIP 完整性、可选大资源缺席、三份部署文件大小/哈希一致、iOS 16.4 SDK 真实离线提取和缓存复用、codesign 深层严格校验全部通过。
- 资源部署 ZIP 完整性通过，不含测试证书、私钥、localhost 配置或测试 fixture。
- 证据：`build/data247-evidence/`；完整挂载回归证据位于 `build/data246-evidence/`。
- 未在本轮验证 iOS 27 实机安装，也未用云端模型实际发起安装调用；不将模拟器结果表述为实机通过。

## 官网部署条件

本轮复查三条生产资源 URL 均为 HTTP 404，尚未上传服务器。App 按需下载不能在部署前对外宣称可用。

将 `build/Dylix-1.1.1-build247-website-resources.zip` 的 `downloads` 文件夹合并到 `/www/wwwroot/dylib.cn/`，保留文件名及 notices。无需数据库、PHP 接口、Token 或覆盖整份 Nginx 配置。使用部署包内的校验脚本执行完整下载校验，三项 PASS 后再分发精简版。

## 主要实现文件

- `App/AI/Resources/DXResourceStore.h/.m`：固定清单下载、状态、进度、校验与共享缓存。
- `App/AI/Sandbox/TFAIISHToolResources.inc`：持久安装探测、去重、完成观察、卸载与所有权。
- `App/AI/Sandbox/TFAIISHRuntime.h/.m`：安装入口接入下载、套件虚拟包。
- `App/AI/Sandbox/TFAIISHHub.m`：安装状态 UI 与管理菜单。
- `App/SDKResources.m`：可选 SDK 下载、持久提取、旧缓存迁移。
- `scripts/build.py`：精简包资源排除及 build247。
- `scripts/prepare_download_resources.py`、`scripts/verify_download_deployment.py`：资源生成及部署验收。
- `tests/OptionalResources247IOS.inc`、`tests/OptionalResources247Run.py`、`tests/OptionalResources247Package.py`：运行时与打包回归。

参考核对 OpenMinis 本地源码提交 `1a71df0f381cefde80bf912b723de6f9831bc177` 的 OnDemandBash、RootfsManagementView 和系统提示词中的持久安装处理；本次未复制其新代码，沿用现有原生 UI 与 iSH 集成。

最终 IPA SHA-256：`90efd8e27b75d45ab56c44578d8777f93952942403cec4094d12253a0e99c353`。
