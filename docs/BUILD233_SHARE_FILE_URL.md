# Build233：单文件分享接收修复

## 故障

从系统「文件」分享 KOOKNoAds.xm 后，Dylix 接收记录变成「file URL / 167 字节」，新建项目提示「工程没有配置可编译的源码文件」。用户原始文件实际为 6784 字节。旧扩展对所有 provider 请求 public.data 文件表示，可能把 public.file-url 的地址文本物化为附件，丢失真实文件名与内容。

## 源码对照

实际阅读本机上游源码快照，未依赖 README 推断：

- OpenMinis 提交 `1a71df0f381cefde80bf912b723de6f9831bc177`：`src/ios/ShareExtension/ShareViewModel.swift` 的 processURL/copyFileToShared/processFile 使用 loadItem 取得 URL，对本地 URL 开启 security scope 并复制真实文件。`src/ios/Shared/ExternalFileImporter.swift` 对打开文件入口使用 NSFileCoordinator。
- Kelivo 提交 `edd184a3324eb68dd9f33af5fd0ef4dddd54b8c0`：`ios/ShareExtension/ShareViewController.swift` 优先 public.file-url 的 loadItem，普通媒体使用具体类型 loadFileRepresentation；两条分支均在 provider 回调内复制。`ios/IncomingShare/IncomingShareInbox.swift` 统一协调读取、保留名称、流式复制并记录实际大小。`lib/features/workspace/widgets/files/file_browser.dart` 的文件选择器返回路径后调用 CopyIntoMutation，不把路径文本当作内容。

结论：使用文件 URL 是正常的平台机制，错误是把 URL 序列化文本当作文件字节。未引入这两个项目的业务代码。

## 修改

- 新增 TFShareFileProvider：明确区分文件 URL 与数据副本，优先真实本地 URL，协调读取，在回调有效期内复制；支持声明为 public.file-url 的 NSURL / NSData / NSString 表示。
- 数据副本优先具体类型，保留文件名与扩展名；不在文件 URL 解析失败后回退成地址文本。
- 拒绝远程 URL、目录和符号链接；继续保留每批 20 文件、总计 4 GiB、原文件不修改、共享组与无共享组导出路径、整批失败回滚。
- iCloud 文件先允许系统协调下载，再验证真实文件；不因下载前缺少属性直接判失败。
- 非源码普通附件不显示「用此文件新建项目」，源码支持 x/xm/m/mm/c/cpp。
- 主 App 与分享扩展构建号均为 233；版本仍 1.1.1。

## 验证

- 新增 46 项 provider/单文件项目检查，使用用户真实 6784 字节文件：文件名和字节完全一致，生成的 MobileCompiler.json sources 包含 KOOKNoAds.xm；未执行或修改用户 Hook。
- 覆盖真实 NSItemProvider(NSURL)、三种声明文件 URL 表示、无效 URL、不存在文件、符号链接、具体类型与 public.data 副本、回调结束临时副本删除后的持久性。
- 既有分享传输 31 项、共享组 95 项、唤起 21 项通过。
- 使用 iOS 26.0 SDK 构建；安装包验证见同名 verification JSON。
- 未在用户真机上走系统「文件」分享完整交互，不能将真实设备验收标为完成。旧 167 字节记录不包含源码，须重新分享原始 xm。
