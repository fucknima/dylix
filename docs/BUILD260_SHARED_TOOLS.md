# Dylix 1.1.1（260）：工具全局持久化

1. 原代码按会话 ID 分别创建 fakefs rootfs。新会话访问另一套 Alpine，工具安装状态也按会话查询；即使旧工具仍在，用户也会看到未安装。没有用户设备原始数据，不能确定本次实际由切换会话、环境维护还是签名后应用数据容器变化触发。
2. 改为一套固定的全局 Linux 环境，保存在 `Library/Application Support/Dylix/iSH-v1/<sharedKey>/`，包含 `data` 和 `meta.db`。APK/pip/npm/手动安装工具及依赖、包数据库、`/root` 都由全部 AI 会话和交互终端共用，不放入聊天记录或临时缓存。
3. 会话仍分别管理进程句柄、PTY、输出和默认工作目录。停止或删除会话不会删除 rootfs；受管理的工具安装不会被该会话的普通取消操作终止。工具安装状态、自动安装和批量安装改为全局状态，受管理的安装任务互斥。
4. 首次升级在内核挂载前检查旧 rootfs 与 SQLite 完整性，按已安装包和工具特征优先迁移一套旧环境，通过重命名保留完整元数据，避免复制大文件或重新安装。其他旧环境保留；在 Linux 环境管理里可安排下次重启切换，原共享环境仍保留。不强行合并多套 APK 数据库。
5. 持久化迁移与切换日志，覆盖重命名中断恢复；损坏环境报错并保留数据，不自动覆盖空系统。用户明确重建/删除后，不偷偷恢复另一份旧环境。

## OpenMinis 参考

检查的 main 提交：`1a71df0f381cefde80bf912b723de6f9831bc177`。

- [RootfsManager.swift](https://github.com/OpenMinis/OpenMinis/blob/1a71df0f381cefde80bf912b723de6f9831bc177/src/ios/iSH/RootfsManager.swift)：固定 `Documents/alpine-rootfs/data`，不是每次聊天新建系统。
- [ISHKernel.m](https://github.com/OpenMinis/OpenMinis/blob/1a71df0f381cefde80bf912b723de6f9831bc177/src/ios/iSH/ISHKernel.m)：初始化内核时挂载 rootfs。

采用相同的固定持久环境原则，迁移与进程归属处理适配 Dylix 现有实现。

## 验证结果

- 环境迁移/维护主机检查：53 项通过，包含多旧环境选择、旧环境保留、切换与回切、多个断电阶段恢复、禁止丢弃已开始切换的恢复日志、明确删除不复活旧环境、损坏环境不覆盖。
- iPhone ARM64 iOS 18.3 模拟器，使用生产 iSH runtime：跨 AI 会话和真实 PTY 执行自定义命令、Python、Git、Node；停止原会话后工具可用；进程句柄仍拒绝其他会话读取；App 重启和 `simctl install` 覆盖安装后工具可用。10 条结果全部通过（含完成标记）。
- iPad ARM64 iOS 18.3 模拟器，干净的独立测试 App：从离线开发套件首次真实安装、跨会话调用、真实 PTY、旧 fakefs 启动迁移后仍执行工具。迁移后 `meta.db` inode 不变，证明使用原树而非重新安装。10 条结果全部通过（含完成标记）。
- 本次未运行全部历史 iSH 测试；其中与旧文件系统隔离语义相关的断言已更新，不能据此声称整个旧套件通过。
- iOS 26.0 SDK 真机 Release 构建完成；ZIP 完整性及构建 App 深度严格 ad-hoc 签名校验通过。IPA 为待重签安装包，尚未验证用户 iOS 27.0.1 真机。

## 保留边界

保持同一 Bundle ID 和应用数据容器的覆盖安装可继续使用。卸载 App、更改 Bundle ID/更换数据容器、明确删除或重建 Linux 环境、切换 Linux 版本都会改变或清除可用工具；不能恢复已经被系统或用户删除的数据。清除工具下载归档不等于卸载已安装工具。

所有终端现在共享文件系统，不再承诺会话之间的 Linux 文件隔离。项目源码仍通过原有显式导入和导出链路交互，未增加宿主机 shell 或自动挂载宿主项目。
