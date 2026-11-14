# Build 253：设置分区与单项工具安装

## 设置页面

- 顶层移除“工具链与本机”；Clang / LLD、SDK / Perl、设备 / 系统移入“关于 Dylix”同名分区。
- “存储空间”位于“数据与工具”，与挂载文件夹、备份与恢复、安装工具并列。
- 关于页保留版本检测更新、作者、功能说明、诊断适配和第三方许可证。

## 工具页

- 单项工具 22 种：Python3、pip、Node.js、npm、Git、curl、wget、Bash、Make、Patch、File、Binutils、LLVM19、dpkg、libplist-util、ZIP、Unzip、XZ、GNU Tar、jq、Ripgrep、OpenSSL。
- 每项有用途、APK 包名、安装状态，安装在本页发起，不强制打开终端。处理中可查看任务输出；已由本页安装的工具支持卸载。
- 保留原完整开发 / 逆向离线套件及 SDK 下载入口；旧安装及自动安装选择继续保留。
- 单项使用用户配置的 Alpine 软件源，通过 apk 官方签名校验安装，不增加 IPA 内置体积。不绕过签名；不将这条下载链路声称为 dylib.cn 独立包资源。
- 工具选择本机持久化，新会话按选择自动注册安装。APK 操作按顺序进行，避免批量自动恢复时同时抢数据库锁。
- 按 apk 已安装数据库和实际可执行文件共同判断状态，避免将 BusyBox 自带 tar/wget 当成完整 GNU 工具。
- 每项使用独立虚拟包 .dylix-item-<package> 记录依赖所有权；卸载只删除这项虚拟包，仍被其他包需要的依赖保留。套件、手动安装或依赖已有的工具可登记为自动安装选择，不直接删除外部管理的包。
- 卸载影响当前环境和未来自动安装选择，不删除其他已存在会话的独立 Linux 环境。未选择的软件源缺包、网络失败、取消或超时会显示失败，不标成成功。

## 开源对照

参考 OpenMinis iOS 的 RootfsManagementView.swift（本机核对 commit 1a71df0f）中“状态、源、环境维护”分离的做法。本次代码独立实现，无直接复制该 UI；单项包操作使用 Alpine apk，而不是仅把原两个套件重复渲染成多个假条目。

## 验证

- iPhone / iPad（iOS18.3 模拟器）设置与工具页各 16 项通过，包含新分区、存储空间跳转、关于信息与逐项工具列表。
- 真实 iSH ARM64 模拟器运行时 12 项通过：单独下载 jq、签名包安装、实际命令执行、选择持久化、新会话自动安装、卸载、取消未来安装选择、其他会话环境保留、非法标识拒绝和 BusyBox 误判检查。
- 22 个单项包名均在 Alpine 3.21 官方 main/community 索引中核对存在；并非已实装验证全部 22 种工具或所有 Alpine 版本。失败按实际错误呈现。
- iOS26.0 SDK 构建成功，IPA ZIP CRC 与签名完整性校验通过，交付待重签名 IPA。
- 证据位于 build/settings253-evidence。


产物：build/Dylix-1.1.1-build253-unsigned.ipa，103636752 bytes。
SHA-256：7f46f08c0e34f5900cd0f875eb06bf0cadd80ad51bfdafe1a7b7ae1d940edf0b。
