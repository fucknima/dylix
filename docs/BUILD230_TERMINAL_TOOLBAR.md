# Build230：终端快捷键栏

- 由六键等宽栏改为横向滚动单行，键盘显示/收起固定右侧。28 个按键/入口，按键至少 44pt 高、48pt 宽。
- Esc、Tab、一次性 Ctrl/Alt、四方向、回车、粘贴/复制、Ctrl-C/D/Z/L、Home/End、PageUp/PageDown、Delete/退格、常用符号及文件/环境入口。
- Ctrl/Alt 显示选中状态，在下一次输入后释放；光标键遵循 xterm application cursor 模式，修饰方向键发送对应 CSI 序列。粘贴复用 xterm.paste，保留其 bracketed paste 处理，并清理残留选择及修饰键。
- 参考 OpenMinis TerminalKeyboardAccessory 的功能覆盖，使用 Dylix UIKit/WebKit 现有结构独立实现，不引入 SwiftUI 控件或替换终端引擎。
- Node 回归使用实际随包 HTML 脚本，校验普通/应用模式、Ctrl/Alt、Unicode 和粘贴。模拟器回归增加 28 键触摸区域及 WebKit 实际控制序列测试。

最终验证：117 项模拟器回归全部通过；Node 快捷键映射回归通过；iOS26 SDK 构建 Build230 完成，App deep/strict 签名及 IPA ZIP 完整性校验通过。
