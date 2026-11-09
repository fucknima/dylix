---
name: Mach-O 分析
description: Mach-O/IPA 输入盘点、切片、虚拟地址与文件偏移、加密标记、符号/头文件及逆向工具选择。
---

## 输入身份

只分析用户选中的附件或已暂存副本。read_attachment 盘点附件；只有 schema 已下发且返回有效 binary_id 时才调用 binary_inspect。未出现工具说明当前输入/能力未就绪，不猜 ID、不传宿主绝对路径。IPA 头文件任务使用 classdump_export / classdump_headers，返回 job ID 后按真实任务结果读取。

先 binary_inspect(action=overview)，记录文件 SHA-256、UUID、FAT 切片、CPU/subtype、映像类型、加密范围、加载命令、依赖和实际返回的节信息。查询固定同一 slice，不把不同版本或不同切片的地址、符号混用。工具没返回的加载命令细节不能说已核实，可在可用的隔离终端工具中补查。

## 地址换算

区别文件偏移、切片内偏移、静态 VM 地址与 ASLR 后运行地址。对包含该地址的 segment，在文件映射范围内才可用 fileoff + (VA - vmaddr) 换算；zerofill 没有对应文件字节，FAT 容器还需考虑切片起点。运行地址换静态地址需同一 UUID 的真实 slide，不能拿 FLEX 对象地址当代码地址。

## 逐步缩小范围

symbols / strings 按关键词与返回分页定位线索；functions 获取符号及 LC_FUNCTION_STARTS 候选入口；disassemble / branches / cfg / xrefs 分析真实指令和引用。headers 或 classdump_headers 提供 Objective-C 声明，类/方法声明不证明运行时执行。Swift 泛型、内联、strip、category 与动态派发可能限制符号和类恢复。

需要近似 C 或 P-code 时按需读取 ghidra-decompilation 技能，再使用可用的 sandbox_reverse。需要 ARM64 指令解释读取 arm64-disassembly，崩溃定位读取 crash-triage。避免对整个镜像连续扫出大量无关文本。

## 结论与边界

cryptid/加密节存在时按工具的范围拒绝执行，不能把密文反汇编成业务逻辑；“能导出头文件”也不代表代码已解密。导入仅复制，不执行目标二进制。高熵、少符号和间接跳转只是特征，不单独证明混淆。

输出包括输入身份、切片、地址空间、相关函数/节、证据来源、推断与未解决点。反编译不是原始源码恢复；签名结构存在不等于签名有效；静态 CFG 不证明真实运行路径。
