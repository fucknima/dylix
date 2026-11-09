# 局域网与本机连接（Build220 / FLEX 1.0.2）

当前仅提供两种连接方式，均由用户手动开启服务。

1. **Wi-Fi 局域网**：dylix 与 FLEX 所在设备连接到可互通的同一局域网，dylix 只选择当前 Wi-Fi 的私有 IPv4。将复制的完整 `http://IP:实际端口` 与授权码填入 FLEX。
2. **仅本机**：FLEX 与 dylix 在同一台设备上时，先关闭 HTTP 与 WebDAV，进入“远程连接 → 连接方式 → 仅本机”，再开启服务。复制的地址为 `http://127.0.0.1:实际端口`，无需 Wi-Fi；其他设备不能访问。

切换方式须先关闭 HTTP 与 WebDAV。实际端口继续沿用用户设置，连接配置、项目、会话与模型保留，敏感读取和写入审批沿用现有流程。

互联网中继、服务器配置和 Tailscale 组网已移除。旧实验版本保存的组网模式会按普通局域网处理，不自动使用蜂窝地址。FLEX 地址输入和底层连接均拒绝公网、组网及 HTTPS 中继地址。

HTTP 本身为明文，请在可信局域网中使用；本机模式仅监听回环地址。后台连接仍受 iOS 调度及现有后台设置影响，不能保证强退后继续运行。

验证入口：`python3 tests/RemoteCoreRun.py`、`python3 tests/FlexConnectionRun.py --flex Plugins/FLEX`、`python3 tests/FlexAgentUISmokeRun.py --flex Plugins/FLEX --persistence --diagnostics`。
