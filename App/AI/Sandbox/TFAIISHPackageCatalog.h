#pragma once
#import <Foundation/Foundation.h>
// Fixed Alpine package IDs. No arbitrary command or user-supplied package name.
static inline NSArray *DXLinuxPackages(void){
 static NSArray *rows;static dispatch_once_t once;dispatch_once(&once,^{NSMutableArray *a=[NSMutableArray new];
 NSArray *specs=@[
 @[@"python3",@"Python 3",@"脚本与自动化",@"/usr/bin/python3"],
 @[@"py3-pip",@"pip",@"Python 包管理",@"/usr/bin/pip3"],
 @[@"nodejs",@"Node.js",@"JavaScript 运行时",@"/usr/bin/node"],
 @[@"npm",@"npm",@"Node.js 包管理",@"/usr/bin/npm"],
 @[@"git",@"Git",@"版本管理",@"/usr/bin/git"],
 @[@"curl",@"curl",@"HTTP 请求与下载",@"/usr/bin/curl"],
 @[@"wget",@"wget",@"下载工具（完整 GNU 版）",@"/usr/bin/wget"],
 @[@"bash",@"Bash",@"Shell 脚本",@"/bin/bash"],
 @[@"make",@"Make",@"构建任务",@"/usr/bin/make"],
 @[@"patch",@"Patch",@"源码补丁",@"/usr/bin/patch"],
 @[@"file",@"File",@"识别二进制文件类型",@"/usr/bin/file"],
 @[@"binutils",@"Binutils",@"readelf · objdump · nm",@"/usr/bin/readelf"],
 @[@"llvm19",@"LLVM 19",@"反汇编与对象文件分析",@"/usr/bin/llvm-objdump"],
 @[@"dpkg",@"dpkg",@"DEB 包管理与提取",@"/usr/bin/dpkg"],
 @[@"libplist-util",@"Plist 工具",@"plistutil 格式转换",@"/usr/bin/plistutil"],
 @[@"zip",@"ZIP",@"创建 ZIP 压缩包",@"/usr/bin/zip"],
 @[@"unzip",@"Unzip",@"解压 ZIP（完整工具）",@"/usr/bin/unzip"],
 @[@"xz",@"XZ",@"XZ / LZMA 压缩",@"/usr/bin/xz"],
 @[@"tar",@"GNU Tar",@"归档与提取",@"/bin/tar"],
 @[@"jq",@"jq",@"JSON 查询与处理",@"/usr/bin/jq"],
 @[@"ripgrep",@"Ripgrep",@"快速文本检索 rg",@"/usr/bin/rg"],
 @[@"openssl",@"OpenSSL",@"证书、摘要与编码分析",@"/usr/bin/openssl"]];
 for(NSArray *s in specs)[a addObject:@{@"id":[@"apk:" stringByAppendingString:s[0]],@"package":s[0],@"title":s[1],@"detail":s[2],@"path":s[3]}];rows=a.copy;});return rows;
}
static inline NSDictionary *DXLinuxPackage(NSString *identifier){for(NSDictionary *row in DXLinuxPackages())if([row[@"id"] isEqual:identifier])return row;return nil;}
static inline NSString *DXLinuxPackageCommand(NSString *identifier,BOOL removing){NSDictionary *row=DXLinuxPackage(identifier);if(!row)return nil;NSString *p=row[@"package"],*owner=[@".dylix-item-" stringByAppendingString:p];
 if(removing)return [NSString stringWithFormat:@"set -e; if apk info -e '%@' >/dev/null 2>&1; then apk del '%@'; else printf 'Not managed by this installer; no user packages removed.\\n'; exit 3; fi",owner,owner];
 return [NSString stringWithFormat:@"set -e; apk --no-progress add --virtual '%@' '%@'; apk info -e '%@' >/dev/null",owner,p,p];
}
