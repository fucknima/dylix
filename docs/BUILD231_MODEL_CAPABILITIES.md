# Build231：模型能力识别与思考接口适配

## 发现的问题

- 模型发现仅保留 ID，丢弃服务返回的模态、工具声明和思考档位。
- 名称正则未覆盖 Sol 简写和无分隔符别名，Claude 原生协议没有对应思考档位。
- 同名 DeepSeek 在官方与硅基流动可能使用不同参数，仅按名字决定参数不够。
- 历史 unsupported 标记能长期阻断工具 schema；图片测试未通过会隐藏浏览器/FLEX 截图能力。
- 能力测试继承不相干的思考设置，可能在验证图片/工具前就因参数被拒绝。工具探测只靠文字要求，模型未调用时证据不足。

## 实现

1. 模型列表保留经过白名单裁剪的声明：输入模态、工具能力、思考开关及档位，包括对象形式 supported_reasoning_levels。按服务端点与协议隔离；不保留密钥、任意请求 JSON；上限 2000 条 / 保存时 512 KiB。
2. 能力解析优先级：当前模型人工配置、成功响应证据、当前服务声明、保守模型族建议、未知。显示各自来源，不把目录建议冒充实测。旧的无证据负面标记不再阻断请求；一次重测失败不会抹掉已有成功证据，失败记录仍单独保存。
3. 统一思考解析和序列化：Chat reasoning_effort、Responses/OpenRouter reasoning.effort、DeepSeek/GLM thinking.type、硅基流动/Qwen enable_thinking、手动 Qwen budget / chat_template_kwargs、Claude budget/adaptive、Gemini budget/level。默认 auto 不额外发送思考参数。开关接口不展示虚构强度；none 仅在明确声明或手动选择可用时发送。
4. Sol/Astra/Terra/Luna 常见简写用于本地识别，实际请求保留原始模型 ID。Claude 预算严格低于 max_tokens。手动参数受协议和档位白名单约束。
5. 新增“模型能力与思考适配”原生页面，入口在连接编辑的模型区和会话思考控制面板。支持自动/人工图片与工具能力、选择思考接口、勾选合法档位、恢复自动和独立思考测试。
6. 普通能力测试不再继承会话思考强度。工具测试仅强制无副作用 probe_ping；仅在 400/422 且明确拒绝 tool_choice 时去掉强制选项重试一次，不重试真实业务工具。图片测试同时接受明确的形状前/后颜色描述，仍拒绝猜测与不一致答案。
7. 思考测试区分参数被接受与有可观察证据。HTTP200 但没有公开摘要/思考 token 用量时为未证实。测试详情和复制报告显示实际思考参数。FLEX/浏览器截图使用统一模型能力解析，同时保留原本本地权限检查。

## 参考结论

- [OpenMinis ThinkingRuleResolver](https://github.com/OpenMinis/OpenMinis/blob/1a71df0f381cefde80bf912b723de6f9831bc177/src/ios/Providers/Thinking/ThinkingRuleResolver.swift)：用户规则与服务商规则分层，声明的档位约束实际参数。
- [OpenMinis CopilotModelsAPI](https://github.com/OpenMinis/OpenMinis/blob/1a71df0f381cefde80bf912b723de6f9831bc177/src/ios/Providers/Copilot/CopilotModelsAPI.swift)：保留服务返回的 reasoningEffortValues，而非一律给相同档位。
- [Kelivo ModelSpecResolver](https://github.com/Chevey339/kelivo/blob/edd184a3324eb68dd9f33af5fd0ef4dddd54b8c0/lib/core/services/model_spec/model_spec_resolver.dart)：override/catalog/guess/vendor/fallback 的逐字段来源；vendor_defaults 区分接口方言。
- [Codex-X model_catalog](https://github.com/yynxxxxx/Codex-X/blob/02a71fb1eaa7bbccbd574a1bfb563c6077e34698/apps/desktop/src-tauri/src/providers/model_catalog.rs)：给自定义映射提供完整 effort 菜单，实际能力交由服务决定；这属于放开客户端选项，不是能力实测。Dylix 保留手动入口，但不自动宣布每个模型支持所有档位。
- [OpenAI reasoning](https://developers.openai.com/api/docs/guides/reasoning)、[DeepSeek thinking](https://api-docs.deepseek.com/guides/thinking_mode)、[Claude adaptive thinking](https://platform.claude.com/docs/en/build-with-claude/adaptive-thinking)、[Gemini thinking](https://ai.google.dev/gemini-api/docs/thinking)：核对实际字段和模型相关限制。官方页面已获取到本地阅读。

## 验证与边界

- Provider231Tests + 既有 provider_v4：真实请求构造、NSURLSession 传输和生产 decoder，响应由本地 URLProtocol fixture 提供；不等于真实付费服务端的全模型认证。
- ModelCapabilitiesUIRun：iOS18.3 ARM64 模拟器，生产设置页面/解析器/保存逻辑，检查人工能力切换、恢复、思考勾选、失败记录与报告、控制面板重建。
- TerminalPermissionTests、SubtaskRuntimeTests：验证这轮能力放行不会扩大本机审批授权。
- App 使用 iOS26 SDK 构建。未使用历史聊天中的 API 密钥，没有发布 GitHub。

服务的 /models 若只返回 ID，无法从这个接口可靠证明所有能力；中转也可能静默忽略参数。此时用模型族建议、手动适配和实际响应分别呈现，不能承诺自动识别所有私有别名或证明服务实际执行了选定强度。

## Build231 最终验证结果

- 协议与能力回归：217 项，0 失败；原生界面：12 项，全部通过。
- 终端权限与子任务回归通过，未改变本地权限边界。
- IPA ZIP 完整性及 codesign --verify --deep --strict 检查通过；Mach-O SDK 为 26.0，版本 1.1.1 / 231。
- IPA 大小：315881512 bytes。SHA-256：`f268462294e99f0041dc846e9551638228a33828b154440567cdbc03ad318943`。
- 测试记录、界面截图及安装包校验信息：`build/proof231/`。
