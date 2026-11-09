---
name: deb 打包
description: rootful/rootless/RootHide 包布局、CPU 与 Debian 架构、签名、filter、依赖及安装不生效排查。
---

## 区分四件事

分别记录 Mach-O CPU slice、编译 target/ABI、Debian Architecture 字段与安装布局。arm 是含糊说法，不等于 arm64；arm64e 涉及 ABI/PAC，不等于把包字段改成 arm64e。不要只改 control 就宣布完成 RootHide 兼容，也不要认为带 arm64e slice 就能在所有加载环境使用。

从用户实际设备、包管理器报错、参考包结构及项目配置确定目标环境。rootful 通常使用 /Library/MobileSubstrate/DynamicLibraries，rootless 常见 /var/jb/Library/MobileSubstrate/DynamicLibraries；RootHide 使用其专用构建/转换约定，以已验证打包器和参考产物为准，不硬写随机安装根路径。无法确认的环境要求保留诊断，不伪装支持。

## 检查包与镜像

导入 deb 后先用 read_attachment 检查清单和控制层/内容层，读取控制字段与实际 dylib、filter 配对。如需 guest 归档工具，先 sandbox_import_attachment 复制已选附件，再在隔离 Linux 内检查 ar/tar；不执行包内 maintainer scripts，不把“解包”当“安装”。

核对 Package、Version、Architecture、Depends、目标目录、文件名大小写及文件模式。Filter 应命中目标 bundle ID / 进程且与加载器格式一致；过宽 filter 可能误加载，过窄可能完全不触发。依赖必须匹配实际 Hook 后端，不能随意删除 Depends 让安装器通过。

对待分析 dylib 必须先获得有效 binary_id，再用 binary_inspect overview 检查 CPU、UUID、最低系统要求、依赖与 rpath。检查是否存在代码签名信息；存在 LC_CODE_SIGNATURE 仅是必要结构证据，不证明签名页哈希和系统信任均通过。原构建器的补签名/校验失败时停止交付，不靠新增 postinst 临时掩盖构建问题。

## 验证本次产物

使用 build_project 的本次 build ID，读取 diagnostics 和 artifacts。包内 dylib 与独立导出 dylib 的 SHA-256、UUID 应符合本次构建；不要拿旧文件、相近大小或同名包代替。签名后再次 strip/改 load command 会改变内容，必须重新签名并验证。

安装失败优先查 Architecture、Depends、包格式与目标环境；“安装成功但无效果”查实际加载、签名、filter、目标进程重启、Hook 命中与配置。每步区分已观察事实和待验证假设，保留包管理器错误及加载日志。构建通过、包安装成功和宿主功能生效是三个独立验收项。
