# Build228：终端会话权限与 Mach-O 工具

1. 当前项目会话选择“项目完全访问”后，sandbox_execute、Linux 进程启动/输入/缩放/停止、开发/逆向工具安装和有效附件副本导入/导出共用会话权限，不逐条弹确认。逐次批准/仅构建模式保持原审批。切回逐次批准、撤销、会话切换及失效项目根目录不再自动授权；模型参数、文件和工具输出不能授予权限。
2. 免确认范围是本会话隔离 Alpine guest。命令可以联网、改动 guest 文件；不增加 iOS 宿主 Shell、未授权目录、项目实时可写挂载。项目工具的上传/下载选项控制结构化项目工具，不是 guest 网络防火墙。FLEX、浏览器交互、记忆等独立授权未被终端权限放开。子任务仍使用自己的独立审批。
3. 扩充离线开发包：Alpine 官方签名 Bash、dpkg、LLVM19，提供 dpkg-deb、llvm-lipo、llvm-otool、llvm-nm；/usr/local/bin 的 lipo/otool/nm 对应 LLVM 原生实现。Git 已在开发包中。工具安装到每个会话持久环境，现有自动安装偏好复用于新会话，非临时 PATH 假命令。
4. Linux/aarch64 ldid 独立编译，不链接进 App；对应完整源码、AGPL COPYING、源码与二进制哈希、依赖哈希、构建脚本一起携带。APK 使用 Alpine 签名验证；独立 ldid 由完整包 SHA256 校验，不宣称它是 Alpine 官方签名包。
5. 终端菜单新增“检查 Mach-O / deb 工具”，开发工具安装入口同步说明。现有用户需安装/更新一次离线开发包；只更新 IPA 不会强行覆盖已运行的 guest 环境。macOS 的 /opt/homebrew 路径、Darwin 可执行文件和 GitHub Actions macOS 构建脚本仍需移植，不能原样作为 Linux 脚本运行；iOS 插件编译继续使用原生 build_project。
6. 修复真实测试暴露的 iSH/musl/GNU tar 目录权限恢复失败：实现 Linux ARM64 fchmodat2(452)，通过原有 VFS 执行，检查 flags、symlink nofollow、空路径和只读挂载，不添加 procfs 宿主路径别名。

验证：
- tests/TerminalPermissionTests.m 使用真实 AIPolicy 和 AIRuntime，Linux 执行适配器为 fixture；验证四种 full 变体免确认、逐次批准拒绝不执行、进程/工具安装、撤权、项目消失、浏览器权限未被扩展。
- ToolRegistryRuntime、SubtaskRuntime 回归通过，覆盖模块关闭、审批期间撤权与子任务权限隔离。
- tests/ISHRuntimeRun.py --packages 在 iOS18.3 ARM64 模拟器使用真实 iSH/PTY 和 production terminal/runtime；新增实际 arm64+arm64e FAT 合并/切片、otool 头、nm 符号、ldid 去签名/补签名、逐页 CodeDirectory 哈希校验、dpkg-deb 构建与解包、维护脚本未执行。MachOSignatureVerify.py --vfs 检查 syscall flags、nofollow、普通文件 chmod、空路径与 /skills 只读边界。
- App 使用 iOS26 SDK；上述模拟器不是 iOS26 真机。权限测试没有消费用户模型密钥，也不宣称联网模型或真实越狱加载验证。

最终回归：116 项全部通过；终端权限、注册表、子任务权限测试通过。

安装包：`build/Dylix-1.1.1-build228-unsigned.ipa`，315,853,263 bytes。
SHA256：`03b19119e37b5a86dd4f1cfe226545d57f432b363c793d3db88854d9d213a99a`。
IPA ZIP 完整性、App deep/strict 签名检查及内置工具哈希校验通过。验证结果见 `build/proof228/`。
