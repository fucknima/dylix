---
name: iOS 崩溃与插件排错
description: ips 日志、异常线程、UUID/slide 符号化、加载失败、视图快照崩溃与最小修复验证。
---

## 收集最小证据

从用户选定的 ips/日志附件读取正文与必要分页，记录 App/插件版本、iOS、设备架构、发生时间、操作步骤和是否稳定复现。不要把所有线程整份重复塞入上下文；先读 exception、termination、faulting thread、寄存器和相关镜像 UUID。

EXC_BAD_ACCESS、SIGABRT、watchdog、jetsam 与签名/加载失败是不同路径。主线程最后一帧是症状位置，不必然是根因；libunwind、objc_msgSend、malloc、UIKit 栈顶不能直接证明系统框架有 bug。

## 对齐二进制

只用同一版本、架构、UUID 的镜像与符号。所选副本通过 binary_inspect overview 核对身份，再 symbols / functions / disassemble 看故障邻域。日志运行地址需按该镜像 load address/slide 换成静态地址；缺少信息就说明不能精确符号化，不能随便减一个基址。

区分故障指令、访问地址、返回地址和对象地址；arm64e 地址可能带 PAC，不能盲目按固定掩码截掉高位。追查对象生命周期、悬空引用、线程、边界长度、递归和 ABI；异常 reason/Last Exception Backtrace 对 NSException 比普通崩溃线程更有价值。

## 最小修复

用 search_text/read_file 定位自有实现，先提出可复现假设。UI/快照任务核对主线程、window/scene 状态、对象是否仍附着、图像尺寸与分配量；禁止对任意对象无限递归 description。遇到单个异常文件，先区分可恢复条目错误和归档损坏/越界，只有能安全继续时才跳过并记录原因。

修复经 propose_patch/apply_approved_patch 和 build_project，读取本次 diagnostics/artifacts。验证原触发步骤、失败路径、重复操作、切后台与无目标对象情况；不能用 catch 所有异常或吞掉错误代替根因修复。

“装了但没效果”且没有崩溃时，转 deb-packaging 核查签名、filter、依赖与加载；不强行按崩溃处理。结论列出证据、根因置信度、修改、复现/回归结果及未验证的真机行为。
