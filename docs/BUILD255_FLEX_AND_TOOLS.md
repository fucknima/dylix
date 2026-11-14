# Build255

根因：FLEX ai_send 缺少 reasoningEffort，远程接口又把未传值重置 auto。修复为未传值且同 connectionID/model 时读取会话 reasoningEffort；显式 auto 清理连接 override；模型变更不继承旧档位。FLEX 从 ai_connections.efforts 构建原生选项，未手动修改时不覆盖主App会话设置。

工具安装：DXLinuxToolBatch 在主线程维护每环境顺序队列，先等实际安装状态，再启动下一项；跳过已安装、失败计数、停止待处理任务，离页继续。全部包括22个单独包、两套完整工具与缺失SDK26；确认前说明资源大小，安装不自动打开终端。APK与归档签名/哈希校验仍保留。

SDK：TMCSDKIsInstalled 仅检查随包SDK或匹配哈希的完成标记与头文件，不执行下载。手动选择缺失SDK不会保存偏好，显示前往工具页；现有工程首次构建按需准备SDK逻辑继续支持。

开源：独立staging生成，不修改私有源；排除发布版私有客户端、服务端及反馈端点。

可选工具归档不包含在源码快照中。干净检出构建直接使用 `Resources/DownloadResources.json` 固定的下载地址、大小与 SHA-256，不需要预先下载工具。运行时安装仍核验这些信息。仅部署官网资源（`prepare_download_resources.py --stage`）时需要本地归档；缺失或与清单不符会明确失败。
