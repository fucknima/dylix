# Build 238 — 系统文件夹选择器确认链路

用户报告的是系统 Files 选择器右上角“打开”无响应，不是 App 内目录列表无法展开。Build 237 的回归只验证选择器呈现，不能证明确认选择成功。

对照 OpenMinis `MountedFoldersSettingsView.swift`（本地快照 1a71df0）：上游明确处理选择回调与 sheet 关闭重叠，待选择器退出后进入挂载流程；通过普通 iOS bookmark 保存授权，不使用 macOS 专属 withSecurityScope。

Dylix 本次调整：
- 先保留安全作用域，等待选择器关闭，再在后台进行目录登记。
- 保留选择器引用；处理 UIKit 已开始自动关闭的转场。
- 展示保存中、成功、失败结果；失败不因选择器仍在呈现而静默丢失。
- 防止重复处理选择回调；支持旧式单 URL 回调；取消后释放选择器并允许重试。

验证：iPhone 模拟器 19 项、iPad 模拟器 20 项通过。新增选择 delegate 回归覆盖保存授权、选择器退出、进度状态、重复目录错误显示；iPad 另测取消后重试状态。测试向真实 UIDocumentPicker 的生产 delegate 提交本地目录 URL，不能等同于真实点击系统“打开”，也没有声称复现真机第三方 FileProvider 问题。

IPA 使用 iOS 26 SDK，Build 238；ZIP 完整性及 codesign 深层验证通过。证据保存在 build/data238-evidence/。
