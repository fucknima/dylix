# Build 240：目录打开与会话导出无反馈

## 本轮定位与处理

- 目录保存原先依赖文件选择器退场完成回调。现改为选择回调到达即在后台处理安全作用域/持久化，选择器退出独立处理，不让动画回调阻塞保存。
- UIKit picker 的 delegate 为弱引用。页面通常由导航栈持有，本轮未证明页面曾提前释放；另增加 picker 对 delegate 的明确持有，完成/取消时解除。
- 回归测试实际捕获：重复目录授权快速失败时，错误结果发生在 picker 尚未退场期间，弹窗可能丢失。现加入过渡后的错误展示重试，错误文本也保留在页面。
- 长按菜单动作排队到菜单 animator 完成后再启动导出；分享弹窗等待导航过渡完成。增加导出中提示与防重复触发。
- 导出只遍历本会话引用的顶层资源 ID，跳过无关会话的大量头文件/构建目录，避免无反馈的全量扫描。保留原先 ZIP 限额和路径校验，正确处理应用容器路径别名。
- 外部 Bookmark 可解析但 stale 时尝试刷新；损坏记录返回可理解错误。目录读取通过 NSFileCoordinator，安全作用域覆盖完整读取周期。
- 阶段诊断保存在 Documents/DylixDiagnostics/file-ui.log，仅记录阶段及错误 domain/code，不记录目录路径、Bookmark、消息和密钥。

## 源码核对

- OpenMinis/OpenMinis，提交 1a71df0f381cefde80bf912b723de6f9831bc177：MountedFoldersSettingsView.swift 的 FolderPicker/Coordinator，以及 MountedFoldersManager.swift 的 Bookmark 恢复。其代码使用 .folder 与 asCopy=false，将选择结果处理与后续 sheet 展示分开。
- readest/readest，NativeBridgePlugin.swift：select_directory / FolderPickerDelegate / FolderBookmarkStore，核对弱 delegate 的强持有、作用域和持久化设计。只参考设计，没有移植整个 Tauri 模块。
- 继续使用现有 Objective-C/UIKit 结构及多目录 Registry，没有引入另一个单目录全局管理器；本轮没有扩展成外部文件的写入/删除管理器。

## 验证与边界

- DirectoryRegistryRun.py：47 项检查通过。
- SessionArchive239Run.py：消息、图片、工具记录、附件、目录资源、新 ID、恶意 ZIP 拒绝；新增 4000 个无关头文件目录场景通过。
- SessionArchive239SimulatorRun.py：iPhone/iPad 各 10 项生产设置/菜单排队/原生分享/识别导入/刷新检查通过。
- ISHRuntimeRun.py --data237：目录授权、重复错误展示、取消后重试、独立页面及 guest 文件链路通过。
- 实际 UI：在 iOS 18.3 ARM64 验证程序（使用生产目录代码）中，通过系统 Files 进入另一个 App 的测试目录 FolderOpen240，真正点击右上角「打开」，返回列表显示已挂载，目录含 verify.txt；终止并重启后仍可用、仍能列出文件。
- 实际 UI：完整 Dylix 模拟器 App，长按会话，点击导出，真实显示系统 ZIP 分享面板。
- 完整模拟器 App 为 x86_64/Rosetta；其系统 Files 远程选择器出现空白，故目录的实际点击验证使用原生 ARM64 验证程序，未将其伪称为完整 App 全流程真机验证。
- 设备包用 iOS 26 SDK 编译，最低 iOS 15；验证 ZIP 完整性和 ad-hoc 签名。本机只有 iOS 18.3 runtime，未验证 iOS 26 真机、iOS 15–17 或 iCloud Drive。
