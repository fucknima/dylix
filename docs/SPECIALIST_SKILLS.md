# 插件开发与逆向技能（Build223）

不新增通用技能市场；沿用 Agent 能力中的技能入口与 `.dylix/skills/<id>/SKILL.md`。内置正文扩充到 11 项，面向实际工具链：

1. theos-logos：工程配置、Objective-C/Objective-C++、Logos、ABI、编译诊断。
2. hook-template：控件归属、生命周期、视图复用、最小 Hook 与宿主验证。
3. deb-packaging：rootful/rootless/RootHide、CPU/包架构、签名、filter 和加载排错。
4. macho-analysis：输入身份、切片、地址空间、加密、符号、头文件与分析分流。
5. arm64-disassembly：寄存器、调用约定、ObjC 派发、分支/数据流、PAC 与结果对照。
6. ghidra-decompilation：真实分析工具安装、异步进程、近似 C/P-code/CFG/xrefs、分页导出。
7. flex-hook-evidence：自主观察、截图、导航滚动、稳定 Hook 证据与大日志末尾/分页读取。
8. crash-triage：ips、异常线程、UUID/slide、最小修复、加载与崩溃的区别。
9. obfuscation-triage：编码/加密/混淆分类、已知 XOR/Base64/Hex、数据流与证据限制。
10. linux-agent-workflow：会话 guest、工具安装、持续 PTY、大输出、附件副本与网页预览。
11. tool-routing：从工程、附件、逆向、FLEX、构建、Git、浏览器、MCP 和记忆任务选择实际工具。

技能只提供可按需读取的工作方法，不新增反编译引擎，不使设备获得新权限，也不修改任何工具 schema。模型仍须依据当前实际下发的工具与参数执行；未验证的生命周期、未解析的间接跳转、失败或未完成任务均不得声称成功。

开启技能且携带开发提示词时，只把名称和简短摘要加入上下文；`agent_skill_read` 读取指定正文。关闭携带开发提示词后不自动注入目录，保持现有行为。技能文件不携带可执行脚本。

项目同名技能优先，安装或升级不会覆盖项目中的文件。因此旧项目若曾复制早期内置技能，原文件仍会保留；新增的不同 ID 可从内置目录读取。需要替换旧项目版本时，应先备份并由用户明确决定保留哪些自定义内容，不能悄悄覆盖。

验证：`python3 tests/AgentExtensionsRun.py` 检查全部技能可按需读取、目录不含正文、同名项目文件保留及路径边界；发布 IPA 另检查 11 个打包资源与源码哈希一致。
