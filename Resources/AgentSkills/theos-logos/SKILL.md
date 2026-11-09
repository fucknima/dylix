---
name: Theos / Logos 写法
description: 插件工程配置、Objective-C/Objective-C++、Logos 预处理、ABI、编译错误与最小修改流程。
---

## 先理解现有工程

用 read_project_config、list_files、read_file、search_text 检查配置、Makefile、control、过滤 plist 和相邻实现。配置以当前构建器实际读取的文件为准，不假定修改 Makefile 就会改变 MobileCompiler.json。只使用本轮 schema 中存在的工具；缺少项目时先确认关联项目。

识别源文件类型：.xm/.xmm 经过 Logos；.m 是 Objective-C；.mm 是 Objective-C++。确认 ARC、C++ 标准、SDK、最低部署版本、头文件目录、链接 framework/library 和目标架构。Linux 终端不是 iOS 宿主 shell，不用 guest clang 冒充 Dylix 的本机 Clang/LLD 构建。

## Logos 与 ABI

%hook 必须使用真实 runtime 类名，%group/%hook 与 %end 成对闭合；%ctor 仅做必要初始化和分组启用。类在启动后才加载时先确认加载时序，不能仅凭首次 NSClassFromString 返回 nil 判定类不存在。

方法的实例/类方法、selector、冒号数量、返回值与每个参数类型必须与证据一致。%orig 默认保留原参数；显式传参时保持完整签名。结构体返回、浮点、block、可变参数和 C 函数不能随意套用普通对象方法 ABI。跨 .m/.mm 的 C 接口需检查 extern "C"；弱符号调用前判空。

Hook 模板只能作为骨架，TARGET_CLASS/TARGET_METHOD 是待替换占位符，不能直接写入正式插件：

```logos
%hook TARGET_CLASS
- (void)TARGET_METHOD {
    %orig;
    // 仅在真实签名、执行时序及对象归属已核对后增加逻辑。
}
%end
```

## 编辑与构建

先提出最小差异，再走 propose_patch / apply_approved_patch；配置变更使用实际下发的配置提案工具。不要整份替换无关业务源码。构建使用 build_project，读取本次 build ID 的 read_diagnostics 与 list_artifacts，修复首个真实编译/链接错误后再构建。

重复符号先查源文件是否重复编入，undefined symbol 先查声明、定义、链接与架构；不能靠删掉功能压住错误。编译成功仅证明静态产物生成，不证明宿主加载、Hook 命中或功能生效。交付列明修改文件、本次产物、验证结果及尚未真机验证项。
