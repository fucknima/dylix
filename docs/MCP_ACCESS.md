# MCP 工具授权（Build222）

支持 Streamable HTTP 和会话 Linux 内 STDIO；不支持旧式 HTTP+SSE 的独立 GET 发现入口。JSON 与 POST 返回的 SSE 均可解析。协商接受 2024-11-05、2025-03-26、2025-06-18，后续 HTTP 请求使用协商版本。

1. 导入配置，进入服务，点击发现。STDIO 先选择会话并确认启动；HTTP 可先发现后选会话。
2. 在服务页“选择会话”中选择已有会话，逐项启用工具，再打开“用于当前会话”。也可从 AI 会话内进入，自动关联当前会话。
3. 服务端明确标记只读、没有破坏性标记且名称不含控制操作的查询，使用逐项工具授权；不强制服务端同时提供 `destructiveHint:false`。
4. 未声明只读、或点击、滑动、按键等设备交互工具，可以手动启用；实际调用通过现有会话确认回调，并在执行前重新检查会话开关、工具及服务配置。只读模式或没有确认入口时不下发这些工具。
5. 写文件、构建、Git、任意命令、安装和注入等命名的工具仍不通过 MCP 开放，继续使用 Dylix 原有工具与审批。名称和 annotations 是分类线索，不能证明第三方服务器无副作用；仅连接可信服务。Dylix 不向 MCP 授予本地项目挂载。

服务器与逐项授权继续本机保存，密钥在钥匙串；App 重启后重新发现并启用会话。刷新发现时撤销旧工具缓存，失败不沿用旧清单。关闭会话开关后不再发起新调用；已送达第三方的操作不能保证回滚。执行失败不自动重放控制操作。

发现失败提示 HTTP 状态及下一步（鉴权、接口或会话失效），不显示鉴权值。MCP 是否能控制目标设备最终取决于该服务器真实实现与权限，Dylix 不能为其补出未实现的 iOS 能力。

结构参考（Objective-C 实现，无 Swift/Python 源码复制）：

- https://github.com/OpenMinis/OpenMinis/blob/main/src/ios/Agent/Session/MCPStore.swift
- https://github.com/OpenMinis/OpenMinis/blob/main/src/ios/default_mount/usr/local/lib/minis-mcp-cli/main.py
- https://github.com/OpenMinis/OpenMinis/blob/main/src/ios/default_mount/usr/local/lib/minis-mcp-cli/transport/http.py

上游使用会话服务开关、简短元数据和 guest CLI 按需发现/调用；Dylix 保留原生工具 schema、逐项授权与项目审批，不照搬其默认启用策略。

验证：`python3 tests/MCPAccessRun.py`（真实本地 HTTP/JSON/SSE）、`python3 tests/AgentRuntimeRun.py MCPApprovalRuntimeTests.m`（生产 runtime 确认、拒绝、撤权、配置变化、取消）、`python3 tests/AgentExtensionsRun.py`。
