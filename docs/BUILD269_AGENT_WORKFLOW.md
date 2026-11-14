# Build269：借鉴成熟 Agent 的工作上下文与任务进度

## 源码依据

本轮实际阅读了以下上游源码；只借鉴机制，新增 Objective-C 实现，没有复制其 Python/Swift 实现。

- OpenMinis 的压缩与摘要：<https://github.com/OpenMinis/OpenMinis/blob/main/src/ios/Agent/Chat/AIChatViewModel%2BCompaction.swift>。摘要属于历史背景，最新用户请求优先，保留已完成动作、路径和结果，避免重新发现。
- Aider 当前文件上下文：<https://github.com/Aider-AI/aider/blob/main/aider/coders/base_coder.py>。当前选中文件与 done/history、repo、当前对话分别组装，工作源码不只依赖历史摘要。
- Aider 历史摘要：<https://github.com/Aider-AI/aider/blob/main/aider/history.py>。压缩较早部分，保留近期尾部。
- DeepAgents 摘要中间件：<https://github.com/langchain-ai/deepagents/blob/master/libs/deepagents/deepagents/middleware/summarization.py>。保留近期对话并为旧信息提供持久引用。
- LangChain 任务清单中间件：<https://github.com/langchain-ai/langchain/blob/master/libs/langchain_v1/langchain/agents/middleware/todo.py>。复杂任务使用结构化进度；计划不等于真实执行结果，简单任务无需额外清单。

## 应用到 Dylix

1. 新增 `update_plan`，最多 20 项，每项内容最多 240 UTF-16 单位，状态为 pending/in_progress/completed/blocked。整个数组替换，空数组清除。可选 explanation 最多 600 单位。
2. 工具只产生会话记录，不访问文件、不代替执行、不授予权限。通过现有工具注册、参数校验、会话检查、调用记录与导出链路。Ask 模式同样允许记录计划，子任务原有工具白名单不变。
3. 返回明确 `model_reported:true / execution_verified:false`，附当前用户消息 ID（存在时）。压缩时保留最近 512 条消息范围内的最后有效计划，空计划阻止旧计划复活。旧计划不能覆盖新用户指令。
4. 工作源码在指南、历史页之前选取；同路径已知 SHA 只保留最近现场读取版本。即使之后 read_context 返回了旧副本，也不能覆盖现场版本。已应用写入继续失效其之前的源码快照。
5. 工作证据文本总额度由 24 KiB 调为 40 KiB，其中源码最多 24 KiB、指南最多 12 KiB；证据最多 8 项、指南最多 4 项、历史页最多 3 项。计划与既有操作回执另有条数/字段限额，最终整个请求仍受用户设置的硬上限约束。不会无上限塞入全文。
6. 同一轮组装缓存已解析结果，避免为了优先级和版本筛选反复解析同一大段 JSON。原始本地消息和原文分页接口保持不变。
7. 沿用 Build267/268 的逐行重叠识别、按文件失效、实际可见页复用；普通新分页、修改后的验证和长任务继续允许。

## 验证

- WorkingContext269Run：16 项，覆盖无效计划、条数限制、空计划清除、失败更新、现场版本与旧历史副本、指南挤占及写入失效。
- TaskPlan269Run：使用实际 AIRuntime 和工具注册，Agent/Ask 两种模式无项目、无桥接、无审批均能记录计划，下一轮接收结果及用户消息 ID。
- ContextProjectionRun：136 项（含用户会话离线回放），原文恢复、工具调用配对、可见页复用和用户硬预算检查通过。
- ToolRegistryRun：197 项通过；RunContinuity251Run、AIRuntimeBudgetRun（正常 1,200 工具调用）、RequestOptimization252Run、开发提示词 52 项通过。

对用户原会话的固定调用序列回放：114 次历史读取中 47 次可复用上下文内原文，少回传 61,852 UTF-8 字节；Build268 对应 33 次、42,192 字节。最终请求样本从 129,558 字节增加到 140,980 字节，用于保留更多有用工作内容。这是取舍后的离线协议测量，不是实际模型行为、计费或 Token 节省承诺。会话导出未记录 App 构建号，不能据此确认其为 Build265。

未进行在线付费模型闭环测试，不能保证所有模型完全不再重复。计划也不会自动验证步骤是否完成；真实操作和测试结果仍须由模型依据工具回执判断。

## 安装包验收

已使用 iPhoneOS26.0 SDK 编译发布版 1.1.2 (269)。ZIP 完整性、主程序与两个扩展构建号、产物新增工具字符串、无测试固定字符串和证书描述文件、codesign --verify --deep --strict 均通过。产物为 ad-hoc 包，需要用户使用自己的证书重签。未声称完成 iPhone 真机或在线模型验证。
