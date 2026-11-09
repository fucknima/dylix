# Build225 模型连接修复

对应 GitHub #1、#3，版本保持1.1.1，构建号225。更新1.1.1发布包中的Build224，配套FLEX仍为1.0.2。

## 行为

1. 设置 → AI → 模型连接 → 传输与请求头，新增自定义 HTTP Headers JSON 编辑入口。值存独立钥匙串，偏好设置只含名称和修订标识。模型发现、能力探测、普通/流式对话统一附加；Authorization 可显式覆盖 API Key 默认鉴权。官方 OAuth 不附加自定义头。
2. 新增“仅允许局域网 HTTP”，公网 HTTP 被拒绝。原有任意主机 HTTP 显式授权保留，已有配置不重置。支持本机、私有 IPv4、IPv6 loopback/ULA/link-local、映射 IPv4 和 .local。
3. 拒绝非法字段、换行注入、大小写重复及传输控制字段；同源重定向保留自定义头，跨域、跨协议、端口变更和方法变更继续拒绝。请求头变更使旧能力验证失效；错误诊断对普通及 JSON 转义的回显值脱敏。
4. 不修改项目、人设、技能、记忆或写入/构建/Git 审批。

## 验证

- `python3 tests/provider_v4Run.py`：180项、0失败。生产 Keychain 保存/读取/删除，配置修改保留，连接间隔离，非法头拒绝，模型发现/能力请求，同源/跨域重定向，普通/转义凭据脱敏，IPv4/IPv6 HTTP 准入和撤销。同步修复旧测试运行器遗漏 StreamActivity 链接的问题。
- `python3 tests/AITransportNetwork.py`：149项、0失败。真实本机 HTTP 服务与生产 NSURLSession，验证缺头403、模型发现，以及 Chat/Responses/Anthropic SSE 请求携带额外客户端头和自定义 Authorization；同时覆盖已有协议、取消、网络错误诊断等回归。
- 主程序和分享扩展使用 iOS26.0 SDK 编译，LiveActivity 使用现有 Swift 工具链 SDK；IPA完整性、主程序/分享扩展/LiveActivity版本和签名结构单独校验。

## 验证边界

没有使用 OpenCode Go 账号或真实服务凭据。#1 所要求的通用请求头入口及传输能力已补齐，但不能据本地夹具宣称 OpenCode Go 服务端已接受该账号；还需按其服务文档填写允许的请求头，测试实际聊天。模型列表可获取始终不等于会话授权已通过。

局域网准入为主机名/字面地址校验，不是 DNS 解析后地址隔离。未新增公网 HTTP 默认授权，未放宽 OAuth HTTPS。余额请求维持原有行为，不附加自定义头。
