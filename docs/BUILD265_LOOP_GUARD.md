# Build265：交替回读与无进展调用防护

Dylix 1.1.2（265），FLEX 保持1.0.3。由用户截图中的226项处理、反复 read_context/read_file/search_code 与未应用提案引出；没有拿到该截图对应的完整原始会话，不把模拟场景当作用户实录复现。

## 已确认的旧实现缺口

1. 全局连续计数被任意新参数或新结果清零；在A/B重复中穿插C新查询即可绕过。
2. 调用参数未剔除展示标题；提案结果中的随机 proposal_id 被当作新进展。
3. read_context 不同引用及回读的回读没有按实际内容识别，历史检索可能形成自我引用链。
4. 每次 send 重建观测状态，普通“继续”与系统续接都可能重新获得一轮空转。
5. 旧测试主要为固定参数与固定结果，未覆盖上述变体。实际应用补丁返回 status=applied/files，旧进度索引只检查 applied 布尔值，遗漏真实修改回执。

## 修改

- 最近40个非轮询调用的滑动窗口；6个重复结果提醒，累计12个重复结果暂停，不因插入新调用立即清零。不是任务总轮数上限。
- 原调用签名和同读取目标的结果签名双重判定；排除 tool_title 和提案随机ID。不同文件相同内容、不同原文分页不交叉误判；不把不同写操作的统一成功信封算成重复。
- 历史回读按实际页内容比较，最多解开32层 read_context 包装；提示仅取当前决策缺失信息，不重新读完整历史或递归读回执。
- 从最近160条原始消息恢复有界观测；简单继续/系统恢复继承近期重复证据，允许至少4次新调用处理纠正或审批。新问题不继承旧累计分数；不恢复权限，也不重放工具。
- 实际 apply_approved_patch 成功回执清除失效观测；生成提案不当作已修改。进度索引增加提案ID、待审批状态及实际修改状态，引导审批或说明阻碍。
- 保留实时进程等既有轮询豁免；本轮没有实现任意 shell 命令的语义等价证明，也不保证消除模型的所有语义循环。

## 上游源码对照

- [OpenMinis ToolLoopDetector](https://github.com/OpenMinis/OpenMinis/blob/main/src/ios/Agent/ToolLoopDetector.swift)：历史窗口、去tool_title、相同调用结果累计、执行前检查；无关调用跳过而非清零。默认 warning10/critical20/global30；并非所有通用重复都会直接中断。
- [OpenMinis AgentLoop](https://github.com/OpenMinis/OpenMinis/blob/main/src/ios/Agent/Chat/AIChatViewModel%2BAgentLoop.swift)：还有maxAgentTurns后备上限和上下文压缩保护。不能声称它绝不会循环。
- [OpenClaw tool-loop-detection](https://github.com/openclaw/openclaw/blob/main/src/agents/tool-loop-detection.ts)：按结果判定、参数抖动无进展、ping-pong交替循环、全局熔断。

本次读取上游当前源码，以现有Objective-C实现独立改造，不复制Swift/TypeScript实现。没有用一刀切总轮数替代长任务能力。

## 验证

RunContinuity251Run新增交替夹新调用、搜索词抖动无结果、随机提案ID、变化历史ref、继续恢复、90个有效分页/不同文件、实际补丁回执清理、回读嵌套去重。原有补充发送、停止、后台续接与产物索引保持通过。
AIRuntimeBudgetRun保留40轮/1200个持续变化结果通过。ContextRuntimeRun与AIRecoveryRun回归通过。使用确定性传输fixture及真实运行时，未消费用户模型额度；不能等同Copilot全端到端或iOS27真机测试。
