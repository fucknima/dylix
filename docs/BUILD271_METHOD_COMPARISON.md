# Build271 上游方法对照与取舍

日期：2026-11-12。依据实际取得的源码快照；固定提交与 main 快照哈希见 validation/upstream-sources.json。这里采用设计方法，未移植整个上游 Agent。

1. **OpenMinis：测即将发出的请求。** 压缩代码明确记录旧的 max(当前估计,上次 usage) 会让压缩前旧计数持续触发压缩。Dylix 保持按当前投影检查，新增上次 usage=1,000,000 后小请求仍能完成的回归。未把旧 usage 当成当前真实大小，也未声称字节是精确 token。
2. **Aider：当前文件与历史分开。** 延续 Dylix 的按版本工作证据，补上小预算下的片段缩小和最新用户具体符号定位。只选择已经读取的内容，不新增隐式文件权限。未采用每轮发送所有文件。
3. **OpenCode：按容量保留尾部、工具输出可追回。** 保留完整工具配对及原始归档，预算仍不够才进一步缩小近期完整结果；文本字段增加 max_chars。用户/系统/工具定义或不可拆原生批次太大时仍拒绝，不能为通过测试悄悄截断用户消息。模型 token 窗口与输出预留只有在容量可靠时才能加入，当前没有伪造这个能力。
4. **OpenHands：执行证据和计划分开，一次纠偏。** 继承 Build270 的局部恢复，测试有响应轨迹继续工作，固执重复轨迹有限停止；不重跑副作用、不把模型计划当真实完成。不是新增无限提示或后台摘要请求。
5. **Gemini CLI：简洁但保留可操作信息。** 三种回答风格统一以用户格式为先，复杂任务必须保留关键改动、证据、限制；不让“简洁”删掉代码或验收条件。不同风格不承诺机械的长度排序，也不加入默认付费检测模型。

参考入口：
- OpenMinis：src/ios/Agent/Chat/AIChatViewModel+Compaction.swift。
- Aider：aider/history.py、aider/coders/base_coder.py、base_prompts.py。
- OpenCode：packages/core/src/session/compaction.ts、tool/plugin/read.ts、tool-output.ts。
- OpenHands：stuck_detector.py、context/condenser/prompts/summarizing_system.j2。
- Gemini CLI：services/loopDetectionService.ts、prompts/snippets.ts。

Build271 未改会话 UI 或新增菜单。仍未实现可靠模型 token 窗口自动分配、跨会话纠偏完成率面板、真实渠道费用对照；不把这些标成完成。未引入每轮付费摘要服务。
