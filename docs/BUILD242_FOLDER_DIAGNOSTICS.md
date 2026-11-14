# Build 242 — 文件夹选择现场日志

## 用户证据

build 241 / iOS 27.0.1 (24A446)，普通和显式多选两种路径都只有 choose_requested、picker_presented、cancelled，没有 selection_callback。可确认尚未进入授权书签保存；不能据此证明是整个系统禁止目录授权，或已确定签名根因。主 App 与扩展共享组可用也不能证明其他签名标识一定正确。

## 本轮实现

- 点击 + / 独立窗口选择时创建 Documents/DylixDiagnostics/FolderPicker/<时间>-<随机编号>.log，逐条追加并同步落盘。保留最近12次，每份最多1 MiB。
- 记录系统/构建/模式、展示守卫、Picker 和 Delegate 存活、窗口/场景状态、App 活动状态、选择/取消/保存阶段、嵌套 NSError 的 domain/code/经清理描述。
- 选择器停留期间每15秒记录一次，最长约5分钟；选择完成、取消、回到前台时也采集。
- 通过公开 OSLogStoreCurrentProcessIdentifier 尝试采集 Dylix 本进程中包含 documentpicker/documentmanager/fileprovider/sandbox/security-scoped/entitlement 的系统消息；按时间和条数限制，去重，记录读取成功或错误信息。
- 日志明确声明：普通 App 无法用 iOS 公开 API 读取 Files、fileproviderd 等其他进程的完整日志。读取到0条不等于系统无故障。不使用私有 entitlement，不冒称获得系统全局日志。
- 挂载页 … → 导出授权日志，可直接分享 .log；重启后仍可导出最近文件。原始文件始终保存在 App Documents。
- 自动清理路径、URL、Bearer/Token 等凭据样式文本；不记录选中目录路径、文件内容、安全书签或证书。
- 增加安装包签名应用标识与 Bundle ID、profile 声明关系的布尔诊断；只读取已有包中的元数据，不验证 CMS 信任，不修改签名。解析不到 XML（包括仅DER情况）显示未知，不误报缺失。
- “兼容”入口替换为独立原生 UIWindow 展示同一 UTTypeFolder / asCopy:NO 选择器。它只隔离展示链；尚不能认定解决用户真机故障。不采用复制导入冒充挂载。

## 实机调试限制

电脑可以读到已配对 iPhone 的系统版本 27.0.1 / 24A446，但 Xcode16 的 DDI 缺少适用 variant（0xe800010f），不能启动开发调试。已装旧 libimobiledevice 日志通道报 lockdownd -21，未取得此次复现的系统日志。不得把这次抓取说成成功。

## 验证

- 签名元数据诊断18项通过。
- 文件接收/目录 ZIP 85项、目录授权47项通过。
- 原生 ARM64 iOS18.3生产代码集成测试31项通过，包括独立窗口取消释放、真实日志文件导出、错误链、敏感字符串清理，以及本进程系统日志读取结果落盘。Picker 自动化回调测试不替代真机点确认。
- 另行重启原生模拟器 App，通过 CUA 点击 … → 导出授权日志，实际出现包含6KB日志文件的系统分享面板，确认重启后可导出；截图在 build/data242-evidence/log-export-share.png。
- iOS26 SDK真机IPA构建、ZIP完整性、主程序/分享扩展ad-hoc签名校验通过。安装仍需正常重签名。
- 本轮交付用于采集用户真机证据；iOS27目录授权故障根因仍未确定，未声称修复。

## 复现与交付日志

1. 安装并签名 build242。
2. 挂载文件夹 → + → 进入文件夹 → 点击打开/✅，等5–10秒。
3. 若无响应，取消 → … → 导出授权日志，发送该 .log。
4. 若导出不可用，也可在系统文件 App → 我的 iPhone → Dylix → DylixDiagnostics → FolderPicker 分享最新日志。

参考：Apple Providing access to directories；OSLogStore storeWithScope:error:；OpenMinis FolderPicker 原生目录选择；SpeedyNote IOS_BUG_TRACKING 中的独立窗口案例（其根因是 Qt 触摸事件链，不等同于 Dylix 根因，只用于设计对照）。
