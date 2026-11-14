# Build 243：目录日志与签名标识一致性

## 实际证据

用户 build242 日志显示 applicationIdentifierMatchesBundleID=false，但 profileAllowsSignedApplicationIdentifier=true：签名权利属于描述文件授权的应用，却不属于 Info.plist 的实际 Bundle ID。App Group 可用不能证明应用标识正确。用户这份描述文件固定授权 app.panda1248.maroon8441；Dylix 当前标识为 com.xuegao.theosmobilecompiler。

Picker 展示、delegate 存活，但只有取消回调，没有目录选择回调。没有取得明确的系统拒绝错误；签名冲突是已确认异常，不等于目录故障根因已完全证明。

## 本次修改

- 系统日志按每次选择独立保存游标，2秒重叠覆盖延迟写入，输出限额前去重。扫描预算触顶时保留已扫描位置，下次继续，而非每轮重放启动前100条。
- 每批最多输出300条，优先保留 error/fault，保持原顺序；记录重复、扫描受限、输出省略、错误省略和去重状态重置数量。单文件仍限制1MiB，最多保留12份。不能读取 Files/fileproviderd 其他进程完整日志。
- 授权诊断显示签名/描述文件应用标识和修复建议，不导出凭据、证书、设备列表或书签。
- 构建支持 --bundle-id；主应用、分享扩展、灵动岛扩展使用独立描述文件与 entitlements。真实证书构建在编译前检查应用标识、团队和分享共同 App Group。缺少 profile 或不匹配直接报错。
- ApplicationIdentifierPrefix 与 TeamIdentifier 分别处理，不假定旧账号的 App ID 前缀必然等于 Team ID。不猜测服务专用通配权限。

## 正确重签名

优先保留原 Bundle ID，使用签名团队实际授权该标识的描述文件：

1. com.xuegao.theosmobilecompiler
2. com.xuegao.theosmobilecompiler.share
3. com.xuegao.theosmobilecompiler.activity

主应用和分享扩展必须具有至少一个共同、实际获授权的 App Group。每个 executable 的 application-identifier 必须等于该 profile 的 ApplicationIdentifierPrefix + '.' + 对应 CFBundleIdentifier。只有 P12 证书不能创造这些权限。

如果签名账号无法授权原标识，应使用账号已有/可注册的新主 Bundle ID，并为两个子扩展分别配置描述文件；先从旧应用导出项目/会话备份，新标识对应新沙盒。不要仅改 application-identifier 或给所有扩展套同一精确 profile。

若安装器报新旧应用标识不一致，还需比较旧版与新版的应用标识及签名团队。使用与旧版兼容的签名身份覆盖安装；无法保持时，先导出备份，再迁移新安装，不能直接卸载丢失数据。

开发构建示例（已有合法签名身份及三份匹配 profile）：

```
python3 scripts/build.py --identity '<Keychain 中的签名身份>' \
  --bundle-id com.xuegao.theosmobilecompiler \
  --profile Main.mobileprovision \
  --share-profile Share.mobileprovision \
  --activity-profile Activity.mobileprovision
```

待重签名 IPA 不嵌入用户 profile/私钥，不会自动修复后续外部重签名造成的冲突。

## 验证

- 签名配置单测10项、运行时签名诊断22项、日志突发/错误保留6项通过。
- ARM64 iOS18.3生产代码集成31项通过，包含目录授权、取消、独立窗口释放、日志导出和脱敏。
- 实际本进程日志第一批输出14条；第二批识别14条重复，仅输出5条新增。available=true，无扫描/输出省略。证据 build/data243-evidence。
- iOS26.0 SDK真机构建和模拟器完整 App 构建通过；IPA ZIP完整性、主应用及嵌套代码 ad-hoc 签名校验通过；三个 Bundle Version 均为243。
- 未使用用户私钥签名，未验证真实证书签名安装；未在 iOS27 真机验证目录选择恢复。当前 IPA 仍需正确重签名。
- IPA SHA-256：e0e99fc7cb83525c1e6b51d926cd5f5e8ef7f05ee125b3cc876d1404a7f0d270

## 用户真机对照验证（2026-11-10 补充）

用户提供 `Dylix-文件夹授权日志(1).log` 与 `(2).log`。两次均为 build243、iOS27.0.1 /24A446、normal模式。

- 修改前：Bundle ID 为 com.xuegao.theosmobilecompiler，签名应用标识为 KRSJ6N3F5J.app.panda1248.maroon8441，identityStatus=mismatch；9.7秒后仅取消，无 selection_callback。
- 用户报告只将软件包 Bundle ID 改为 app.panda1248.maroon8441 后可正常授权；新日志显示 identityStatus=metadata_consistent、applicationIdentifierMatchesBundleID=true。
- 10:18:40Z 连续出现 folder.selection_callback → folder.scope_started → folder.registration_started → folder.registration_saved，确认系统返回目录、安全作用域开启并保存授权。

结合用户操作说明和前后日志，本次真机故障可定位为重签名后 Bundle ID 与应用签名标识不一致。不是 iOS26+ 一概禁止目录授权，也不是此次 Bookmark 保存链路故障。此前“未在iOS27真机验证”的限制现已由用户真机日志补充；这不代表开发机完成了真机自动化。重启后书签恢复、两个扩展签名及跨用户签名兼容仍不在这份成功日志的验证范围。

该 Bundle ID 是这位用户的描述文件所允许的标识，不能将其硬编码为所有用户的公共发行标识。应由各用户的签名流程保证每份安装包内部一致。
