---
name: FLEX 现场与插件取证
description: AI 自主观察页面、截图/控件树、导航滚动、按钮定位、生命周期证据及大日志读取。
---

## 先确认现场

读取 flex_current_context 与 flex_live_read(operation=capabilities/current)，核对 bundleID、当前页面和可用操作。只有已下发操作才能调用；连接配置存在不等于目标在线。当前选中 UIWindow 不妨碍继续用 screen_elements / view_tree 自主观察，不能只靠用户最后点选的对象猜界面。

需要操作目标页面时，先经当前授权调用 flex_control(operation=minimize_chat,surface=target)，确认聊天/FLEX 覆盖层已收起，再读取 screen_elements 和截图。状态悬浮球不应被当作业务控件。capture_screen 由 flex_sensitive_read 调用，要求模型图片能力已验证；返回截图不代表模型一定已收到图像，应结合实际发送状态。

## 观察、操作、复核

使用真实返回的 id/frame/窗口坐标，导航后重新读取。对象失效就重新获取，不连续重试旧 ID。activate_control 的支持范围以返回为准；不支持的控件不能报告点击成功，可在 gesture_capabilities 确认手势后端可用并获授权后使用 gesture。

delivered、dispatched、scrolled 不是业务成功证明。操作后核对 controllerPath、控件文字/位置、contentOffset 和新截图。滚动达到边界且 delta=0 时应报告没有滚动，不把它当成功。切页前记录恢复路径，测试后返回原页面并 restore_chat，任务/连接状态单独核对。

## 稳定 Hook 证据

对目标读 object_info、view_tree，结合 class_info；class_header 使用 flex_sensitive_read 的 name/start_line/line_count 分页。区分当前对象、交互父容器、业务祖先、最近 responder controller 和真实声明所属镜像。hookEvidence 的声明候选、executionObserved 与 stabilityVerified 分开解释，未观测执行的方法不能称为已验证生命周期。

set_view / undo 仅是临时现场验证，需要授权和结果复查。用户要持久隐藏按钮时，最终需按 hook-template 写进工程并构建，不能用临时隐藏冒充插件功能。

## 日志读取

先 sandbox_list 获取真实相对路径和大小，再 flex_sensitive_read(operation=sandbox_read,path=...)。新版默认 128 KiB、limit 最高 524288 字节；日志排查优先 tail=true 直接读末尾，tail 不与 offset 同传。完整读取用 next_offset 接着传 offset，检查 has_more、totalBytes、modifiedAt 和轮转/截短错误。不要反复发送整份相同日志，也不要依据旧插件的 64 KiB 上限宣布当前文件永远读不了；若能力/返回仍是旧限制，明确提示更新 FLEX。

网络详情、defaults、文件和钥匙串元数据仅在用户授权范围内读取，不复述秘密。报告工具失败、空结果、未测项和真实截图状态，不凭配置声称功能正常。
