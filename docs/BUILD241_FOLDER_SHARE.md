# Build 241 — 文件夹分享与挂载诊断

## 已确认的问题与边界

- 用户提供的 build 240 分享诊断显示主 App 和扩展有五个共同可用共享组；不能继续把问题归为缺少 App Group。
- 分享接收器之前主动拒绝目录，错误为“只接收普通文件，不接收目录或符号链接”。这是 Dylix 的确定缺陷。
- 用户报告 iOS 27.0.1 系统 Picker 中点“打开/✅”无响应。当前无该真机日志，根因未定；本机仅有 iOS 18.3 模拟器，不能宣称已修复该系统上的故障。
- 尚无已核实官方依据支持“iOS 26 起禁止 in-place 文件夹授权”这个笼统判断。

## 修改

1. 分享扩展支持 public.file-url 目录和仅声明 public.folder 的来源。协调读取期间流式生成 ZIP 副本，再交给原有接收链路；原目录不移动。导入副本不等于持续挂载。
2. 目录归档逐项拒绝链接与特殊文件，使用 openat/O_NOFOLLOW 和 inode 校验；限制 10000 项、512 MiB 内容、128 层。每次读取检查时间预算，错误时删除临时 ZIP。保留中文名、隐藏文件、嵌套和空目录。
3. 挂载页“…”新增兼容选择与授权诊断。兼容模式仍使用 UTTypeFolder、asCopy:NO，允许系统多选交互但应用一次只接受一个目录；此入口为待真机验证的备选，不能当作已证实的系统修复。
4. 诊断显示系统版本、构建号、Picker/授权状态和阶段日志，不包含目录路径、书签、密钥。分享诊断增加接收阶段、来源 UTI、错误类型，区分未开始唤起和接收失败。
5. 文件提供方保存慢时给出等待状态；选择器关闭但无回调时提示错误并允许重新选择。

## 验证

- 文件提供器/单文件导入回归：85 项通过，含文件 URL 的 NSURL/Data/String 表示、真实 NSItemProvider、目录 UTI、嵌套 ZIP、中文与空目录、链接拒绝、超限拒绝、临时文件清理。
- 目录登记/只读挂载：47 项通过。
- 原生 ARM64 iOS 18.3 生产代码测试：25 项通过，含兼容 Picker、目录提供器 ZIP、目录浏览、错误/取消和现有 IPA/终端链路。自动化目录测试会调用生产 Delegate，不代替真正的系统按钮测试。
- 另行通过 CUA 实际点击兼容入口、系统“打开”，授权外部 Dylix App Documents/Folder241；回到列表显示已挂载；重启后依然可用，进入可见 verify241.txt。截图与阶段日志保存在 build/data241-evidence。
- 另行通过 CUA 从系统分享面板把 FolderShare241 文件夹交给完整 App 的 build 241 分享扩展；真实接收成功，诊断显示 files=1、bytes=752、error={}、phase=awaitingManualExport。模拟器 ad-hoc 无可用共享组，因此进入预期的手动保存回退；未将其宣称为真机共享组自动唤起通过。
- 会话导出/恢复回归通过；iPhone/iPad 模拟器各 10 项既有会话/UI 集成测试通过。
- iOS 26.0 SDK 构建真机 IPA 与模拟器 App 成功；build 241，版本 1.1.1，最低 iOS 15。IPA ZIP 完整性和主程序/分享扩展 ad-hoc 签名验证通过；安装仍需用户正常签名。

## 官方参考

- https://developer.apple.com/documentation/uikit/providing-access-to-directories
- https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller/init(foropeningcontenttypes:ascopy:)
- https://developer.apple.com/documentation/foundation/nsfilecoordinator/readingoptions/foruploading
- https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes

苹果目录文档仍描述选择目录、获取 security-scoped URL、协调读写与保存书签。asCopy 参数控制复制行为。官方 ForUploading 可对目录生成 ZIP；本次为实施项目数/字节数与链接检查采用自有受限流式 ZIP，而未直接无界委托打包。

## 真机仍需验证

安装 build 241 后重现：挂载文件夹 → + → 系统打开。若不返回，取消后选择“…”→授权诊断→复制诊断。若日志仅有 picker_presented 而无 selection_callback，定位到系统 Picker/文件提供方回传之前；若有回调而 registration_failed，则继续核查具体授权保存错误。不能用改 asCopy:YES 的复制导入替代真实挂载。
