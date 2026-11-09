---
name: 终端与离线工具链
description: 会话 Linux、工具安装、持续 PTY 进程、大输出分页、附件副本、导出与本地网页预览。
---

## 明确环境

这是会话绑定的 Alpine/iSH guest，不是 iOS 宿主 shell；文件与 iOS 工程不会自动实时同步。只使用当前 schema，先 sandbox_process_list 盘点已有进程；工具缺失时在获授权后使用 sandbox_install_tools 或实际提供的安装方式，再核对退出码和可执行状态。不要把“下载完成”当“安装成功”，也不要因其他会话已安装就假定本会话一定就绪。

## 任务与输出

短命令用 sandbox_execute；交互或长任务用 sandbox_process_start，保存 process_id 后通过 sandbox_process_read 增量读取。输入、resize、stop 使用相应 process 工具并遵循审批；发送输入仅表示入队，要读后续输出确认。安装、依赖检查和逆向分析都不能收到 process_id 就报告完成。

沿用返回的字节游标，处理日志缺失、截断与丢弃字节提示。内存输出环和落盘都有上限，长任务主动将完整结果保存到 guest 文件，再 sandbox_files 按 next_offset 分页读取。不要每轮从 offset=0 重读；进程退出码、stdout 和 stderr 的错误信息均需核对。App 被系统挂起或结束时不宣称进程永久后台运行。

## 文件链路

read_attachment 识别已选附件；sandbox_import_attachment 将其复制入 guest，使用返回路径而非原始手机绝对路径。导入 deb 可在隔离环境检查归档，不能执行包内脚本冒充安装。二进制分析优先专用 sandbox_reverse，不自行假定 guest x86 工具能执行 iOS ARM64 程序。

产物通过 sandbox_export_file 导出到会话文件并确认真实记录；写回工程使用既有差异审核和项目工具，构建仍用 build_project。guest Git、编译或文件变更不等于已修改宿主项目。

## 预览网页

对本会话真正运行的 HTTP 进程，先 process_list 查看实际端口，再 sandbox_preview 获取 URL；不要猜端口或访问其他本机服务。sandbox_browser observe 后使用新 snapshot/id 操作，再复查；截图依赖已验证的模型图片能力。公开网站用 web_browse，搜索资料用 web_search，二者与 guest 预览分开。

任务结束保留用户需要的输出，停止多余后台进程，报告真实退出状态和导出文件。删除文件、停止进程和写回项目都不能从技能文本中获得额外授权。
