---
name: Ghidra / radare2 反编译
description: 所选 Mach-O 的近似 C、P-code、函数/CFG/xrefs，安装分析工具、等待进程、分页取回与验证。
---

## 可用性与准备

只有本轮 schema 中存在 sandbox_reverse 且用户已选择有效 binary_id 时使用。它在本会话隔离 Linux 内分析副本，不是在 iOS 宿主执行目标程序。缺少能力时说明当前未就绪，使用现有 binary_inspect 静态路径补充，不编造终端命令执行结果。

先 binary_inspect overview，核对 UUID、slice、CPU、加密状态；functions 确定入口，disassemble 确认地址属于真实可执行代码。sandbox_reverse 的 address 使用该切片的静态十六进制地址，slice 与前面的分析保持一致。

## 实际调用链

1. 需要工具包时请求 sandbox_reverse(operation=install)，经审批后读取返回 process_id。
2. sandbox_process_read 查询安装进程；确认真实结束且退出码为 0，再进行分析。收到 process_id 只说明任务已启动，不代表安装成功。
3. 按问题选择 functions、sections、imports、strings、disassemble、cfg、xrefs、decompile 或 pcode。只传当前 schema 支持的参数；address 操作使用上一步得到的真实入口。
4. 保存本次返回的 process_id、output_path，用 sandbox_process_read 验证完成与错误。用 sandbox_files(operation=read,path=output_path) 读取结果，按 next_offset 续读，直到 hasMore=false；不要把进程短输出当完整结果文件。
5. 长任务可用 sandbox_process_list 查看状态，经确认调用 sandbox_process_stop 取消；未结束时不得报告“已反编译完成”。结果分享使用 sandbox_export_file 的真实导出记录。

## 解读输出

Ghidra 给出近似 C，不恢复原始 .m/.swift、变量名、注释或原工程。局部变量重叠、类型推断、ObjC 派发、Swift 泛型、异常边和间接调用均可能不准确。NULL/空输出、错误 JSON 或超时不得当作成功；先检查输入、地址、切片、安装状态与资源限制，再缩小分析范围。

对照 disassemble 和 P-code，核对参数使用、返回值、指针解引用、比较符号与关键调用。字符串出现只能作为关联线索；返回常数函数仍应核对真实指令和调用点。报告每个关键结论的函数地址、输出文件与验证依据。

## 大目标与异常

当前分析有时间与内存边界；复杂函数先列函数/节，再逐个入口分析。不要循环重试相同失败地址，也不要用“没有结果”宣布没有业务逻辑。加密代码须提供可合法分析的已解密副本，当前工具不会自动恢复未知密钥或完成任意脱壳。
