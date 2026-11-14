# Build 248：挂载附件图标修复

将附件菜单挂载入口原有的 folder.badge.checkmark 替换为 folder.badge.gearshape，并在系统取图失败时使用基础 folder/doc 图标兜底。

已重新编译完整模拟器 App 和 iOS26 SDK 真机目标 IPA。iPhone 和 iPad 模拟器各 13 项挂载附件检查通过，包含图标非空检查和实际菜单截图；截图核对挂载图标正常显示。IPA ZIP、版本号、可选大资源排除及 codesign 深层严格校验通过。未在 iOS27 实机验证。

官网资源与 build247 完全相同，不需要重新部署；仍需先上传官网资源包。

IPA SHA-256：5d76cfd5745f832bace207180573c3035dcc9fa8bf7405a21167182d49cbc32b
