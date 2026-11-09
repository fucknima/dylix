---
name: ARM64 / arm64e 反汇编
description: ARM64 寄存器/调用约定、ObjC 派发、分支与数据流，使用真实函数入口和指令交叉验证。
---

## 工具顺序

先读取 macho-analysis，确认 binary_id、slice、静态地址与加密情况。用 binary_inspect functions 找候选函数入口，再 disassemble 读取有限窗口；branches、cfg、xrefs 用于补充直接分支和引用。address 必须来自当前切片的可执行范围，offset 在 disassemble/branches 中是相对 address 的指令偏移，其他操作按其 schema 和返回游标分页，不能混用单位。

## ABI 与调用

ARM64 指令通常按 4 字节对齐，先确定代码节，不把常量池或文件头当指令。x0–x7 是常见整型/指针参数，v0–v7 承载浮点/SIMD 参数；x0/v0 常见返回值，结构体间接返回可能使用 x8。x29 常见帧指针，x30 为 LR，sp 需保持 ABI 对齐。wN 写入会清零相应 xN 高 32 位；有符号/无符号扩展会影响边界判断。

Objective-C 常见调用以 x0 为 receiver、x1 为 selector，后续参数从 x2 起，但优化、尾调用和 stub 会改变局部表现。objc_msgSend 的目标不能只靠一条 bl 指令猜出；结合 selector 引用、receiver 来源、相邻数据流及头文件确认。block invoke、C++ this、Swift 调用约定不应照套 ObjC 原型。

## 数据流与控制流

ADRP 生成页基址，结合 ADD 或 LDR 才能确定实际引用；LDR 指令可读取地址或对象内容，二者不同。跟踪 MOV、ADD/SUB、LDR/STR、栈槽和寄存器覆盖，不跨函数假定寄存器值不变。CMP/TST 设置标志；B.cond、CBZ/CBNZ、TBZ/TBNZ 需要记录真/假分支及落空路径。

B 与 BL 区分跳转和调用；BR/BLR、跳转表、消息派发属于需要额外证据的间接目标。工具给出 unresolved 就保持未解析，不编造完整 CFG。RET 并不保证函数唯一出口，尾调用、异常路径和共享块均需考虑。PAC/AUT、BTI 在 arm64e 中不能直接解释为恶意逻辑或无用指令。

## 交叉验证与交付

对关键函数写明输入、输出、关键状态、分支条件和副作用，逐项给出地址/指令依据。函数起点来自符号/LC_FUNCTION_STARTS 也不意味着 nextEntry 就是精确末尾。使用 sandbox_reverse 的 disassemble / cfg / pcode / decompile 做独立对照，出现冲突时优先回到同一输入字节核对。

静态推断标明置信度；不因反编译输出了函数名就认定原型正确。修改插件优先使用有证据的业务 Hook，静态分析本身不写目标二进制；任何工程修改仍走原有差异审批。
