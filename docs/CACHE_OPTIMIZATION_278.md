# 缓存与长上下文优化记录（278）

## 对照结论

参考 OpenMinis `1a71df0f381cefde80bf912b723de6f9831bc177` 的请求构造和会话持久化实现：

- 缓存字段必须按服务商和官方端点开启，不能对未知中转站盲发；
- 缓存前缀必须稳定，不能每轮把提醒、进度或工具结果重新拼接到旧消息；
- 压缩应采用冻结的 trim/checkpoint，编辑历史、切换模型、工具 schema 或预算变化时才失效；
- 原始会话永远保留，网络投影只保存可复用的摘要/回读引用。

## Dylix 改动

1. 新增 `TFAIContextSessionProjection`：在一次运行中冻结历史投影，追加新消息时复用已确认前缀。
2. 仅当投影接近 85% 文本预算、历史发生编辑或连接/schema/预算变化时建立压缩 checkpoint。
3. 环境快照、恢复进度、回读索引移到请求末尾的临时观察数据块（user role，避免 Anthropic 的 assistant prefill 语义），不再反复改写 system 前缀。
4. 压缩预算由原来的 1/4 提高到稳定 checkpoint 的 1/2（仍受 256 KiB 保护值约束），并保留最近工具批次、用户约束、失败事实和原始引用。
5. Anthropic 官方端点可在冻结历史边界放置 ephemeral cache marker；代理、中转和仿冒域名不发送该字段。
6. 所有原始工具参数、结果、会话消息仍在本地 transcript 中，`read_context` 引用未改变。

## 验证

- 连续 160 轮工具历史：14,350 项断言通过；156/159 次历史前缀保持完全连续（98.1%），仅 3 次预算 checkpoint；原始投影基线只有 23 次保持连续。
- 发布版连续 160 轮：14,695 项断言通过；155/159 次历史前缀保持连续（97.5%），4 次 checkpoint。
- 编辑历史、切换模型、不可压缩超大输入、并行工具配对、原始参数/结果不变均通过。
- Provider 请求回归：283 项断言通过；官方 Anthropic 标记、代理禁发、工具顺序、输出上限和已有协议行为均通过。

## 说明

本地测试验证的是“请求前缀可复用”和“压缩不会破坏证据”；真实账单中的缓存命中率仍由具体服务商返回的 usage 字段决定，不能用本地估算冒充供应商计费数据。

## GitHub 成熟 Agent 对照（2026-11-22）

本轮继续核对了 OpenCode、Cline、Codex 的公开实现路径：

- OpenCode：`packages/core/src/session/compaction.ts`、`packages/core/src/session/context.ts`，并配套 `packages/core/test/session-compaction.test.ts` 与 `session-compaction-transport.test.ts`。重点是把“持久会话”和“本轮传输上下文”分离，压缩有明确触发条件，并用 transport 测试验证压缩后的请求，而不是只测最终 UI 文本。
- Cline：`apps/vscode/src/core/controller/slash/condense.ts`、`apps/cli/src/runtime/interactive/compaction.ts`，以及对应 `condense.test.ts`/`compaction.test.ts`。重点是手动/自动压缩共用同一条路径、保留可恢复的历史摘要，并在继续执行前重建上下文。
- Codex：`codex-rs/core/src/compact.rs`。实现了 compaction checkpoint、保留项/待处理用户输入、压缩前后 hook、摘要元数据和持久历史替换；压缩不是简单截断，也不会把临时状态反复写入稳定前缀。

这些原则已落实到 Dylix：冻结 canonical projection、临时观察尾部、checkpoint 失效条件、原始 transcript 与网络投影分离、provider replay 丢弃、压缩前预算保护，以及运行时 transport 回归测试。没有照搬其他项目的许可证代码，只吸收公开架构原则。

## 新增验证

- 开源版 `ContextRuntimeRun.py`：运行时上下文、工具调用、恢复、不可压缩输入保护、provider replay 清理、流式压缩标记共 **全部通过**。
- 发布版 `ContextRuntimeRun.py`：同一套回归 **全部通过**。
- 开源版 160 轮连续工具上下文：14,350 项断言通过。
- 发布版 160 轮连续工具上下文：14,695 项断言通过。
- 本地验证的是 prefix continuity、预算边界和证据保真；服务商真实缓存命中率/费用仍必须由对应 API 的 usage 返回字段确认，当前没有把任何本地比例冒充账单命中率。

## 中转站实测（2026-11-22）

使用用户提供的 `https://kedaya.ai/v1` 临时凭据对 `gpt-5.6-terra` 发起了最小化 Chat Completions 测试：

- 成功返回一次 usage：`prompt_tokens=4390`、`cached_tokens=3566`、`total_tokens=4396`。
- 该次响应的可观测缓存比例为 `3566 / 4390 = 81.23%`，说明稳定前缀确实被中转站/上游识别为缓存；这是单次请求观测值，不代表长期平均命中率。
- 随后同凭据请求返回 HTTP 401，无法继续进行多轮统计；因此没有把单次结果扩展成整体账单结论，也没有继续重试消耗额度。
- 中转站返回了 `prompt_tokens_details.cached_tokens`，Dylix 应优先读取这个字段；如果字段不存在，则不能自行推算供应商缓存命中。


## gpt-6.1-sol 实测补充（2026-11-22）

- 使用 `gpt-6.1-sol` 成功获得一次真实 usage：`prompt_tokens=4388`、`cached_tokens=3566`、`total_tokens=4393`。
- 单次可观测缓存比例约为 `81.27%`。
- 同一凭据随后多轮请求再次返回 HTTP 401，无法形成稳定的多轮样本；测试脚本也验证了 401 并非 Dylix 统计逻辑造成。
- 因此本次只能确认 6.1-sol 的单次缓存字段可被 Dylix 正确读取，不能据此宣称大量测试完成或长期命中率稳定。
