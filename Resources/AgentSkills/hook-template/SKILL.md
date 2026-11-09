---
name: Hook 模板
description: 从 FLEX/头文件/静态分析定位稳定 Hook 点，处理视图复用、生命周期、原调用及持久化隐藏按钮。
---

## 从需求到证据

先说清目标页面、控件特征和期望行为。隐藏一个按钮不等于隐藏其父卡片；也不等于修改所有 UIButton。读取 flex_current_context，再用 flex_live_read 的 current、screen_elements、object_info、view_tree 复核对象、业务祖先、所属控制器、镜像、标题与 accessibilityIdentifier。没有 FLEX 时，使用所选二进制的 headers 或 classdump_headers 及项目源码交叉核对。

对象 ID 和地址只标识当前实例，不可硬编码进插件。frame、展示文案、索引和最近 responder controller 都是辅助定位证据，不证明创建者。类名和 selector 必须来自当前 App 的真实声明，不能用猜测替代。

## 选择 Hook 点

优先业务类的配置、布局或模型更新方法，范围尽量小。头文件中出现方法，只能证明声明存在；hookEvidence 中 executionObserved=false、lifecycleExecutionObserved=false 或 stabilityVerified=false 时如实报告，不能通过多读一次就宣称验证通过。用用户授权的宿主运行测试和定向日志验证命中，不宣称工具提供了并不存在的任意方法追踪。

确认控制逻辑应在 %orig 前还是后执行；布局后隐藏通常需要防止后续刷新恢复。UITableView/UICollectionView 的复用、滚动、切页、重新进入与模型切换均需检查。能稳定使用业务属性/ivar 时优先使用，但先核对存在性与类型；不要根据内存地址做持久定位。

UI 修改在主线程执行。需要跨生命周期保存的状态避免使用一个全局实例指针；按对象绑定状态并考虑释放。防止 setHidden: 或 layoutSubviews 内互相触发递归，避免在每次布局重复添加约束、手势或子视图。

## 分阶段验证

1. 最小原样 %orig，确认可加载且不崩溃。
2. 增加业务类与控件定位日志，验证真正命中的页面和实例，不输出账号凭据。
3. 只改目标属性，验证同类其他按钮、点击区域、布局与父容器不受误伤。
4. 滚动/复用/切页/重进后复测；用户可关闭功能并恢复正常行为。

FLEX 的 set_view/undo 只用于经确认的临时验证，不能称为插件实现。写入工程、构建和产物分享分别走现有工具链；没有真实运行证据时交付候选 Hook 和验证步骤，明确未验证的生命周期。
