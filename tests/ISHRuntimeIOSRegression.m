#import "../App/AI/Resources/DXResourceStore.h"
#import "../App/SDKResources.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import "../ShareExtension/TFShareFileProvider.h"
#import "../Vendor/libarchive-headers/archive.h"
#import "../Vendor/libarchive-headers/archive_entry.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
@interface UIViewController (Directory241)
- (void)chooseFolderCompatible:(BOOL)compatible;
@end
#import "../App/AI/Permissions/TFAIPolicy.h"
#import "../App/AI/Agent/TFAIReadOnlyBrowser.h"
#import <UIKit/UIKit.h>
#import "../App/AI/Agent/TFAIWebDOM.h"
#import "../App/AI/Sandbox/TFAIISHRuntime.h"
#import "../App/AI/Sandbox/TFAIISHTerminal.h"
#import <WebKit/WebKit.h>
#import "../App/AI/Agent/TFAIAgentContext.h"
#import "../App/AI/Sandbox/TFAIISHEnvironment.h"
#import "../App/AI/Sandbox/TFAIISHEnvironmentUI.h"
#import "../App/AI/Sandbox/TFAIISHPreview.h"
#import "../App/AI/Sandbox/TFAIISHExports.h"
#import "../App/AI/Sandbox/TFAIISHMCPTransport.h"
#import "../App/AI/Agent/TFAIMCP.h"
#import "../App/AI/Attachments/TFAIDirectoryRegistry.h"
#import "../App/AI/Attachments/TFAIAttachmentStore.h"
#import "../App/AI/Sandbox/TFAIISHRemote.h"
#import "../App/AI/Sandbox/TFAIISHRootCatalog.h"
#import "../App/AI/Sandbox/TFAIISHMirrors.h"
@interface UIViewController (MirrorHarness)
- (NSDictionary *)fastest:(NSString *)group;
- (void)probe;
@end
BOOL TFAIAttachmentSensitive(NSString *text){return [text containsString:@"FAKE_SECRET"]; }
NSDictionary *TFAIBinaryStage(NSData *data,NSString *name,NSError **error){return nil;}
NSString *TFAIAttachmentLocalPath(NSDictionary *entry,NSError **error){return nil;}
NSDictionary *TFAIReadAttachmentReferences(NSDictionary *references,NSDictionary *arguments,NSError **error){return nil;}
NSError *TFAIError(NSInteger code,NSString *message){return [NSError errorWithDomain:@"Dylix.Test" code:code userInfo:@{NSLocalizedDescriptionKey:message}];}
#import "../App/AI/Sandbox/TFAIISHFiles.h"
// Runtime harness exercises file browsing UI; the real project write engine has
// a separate 348-case regression suite. Never claim these linker stubs test writeback.
@implementation TFAIToolbox
@end

UIViewController *TFAIAgentSettingsController(NSString *root,NSString *session){return [UIViewController new];}
UIViewController *TFAIApprovalController(NSDictionary *plan,void(^decision)(BOOL,NSArray *)){return [UIViewController new];}
#import "../App/GlassSupport.h"
@implementation TMCNavigationController
@end
static void Message(UIViewController *host,NSString *title,NSString *text){}
@interface UIViewController (WorkspaceHarnessSave)
- (BOOL)save;
@end
#include "../App/ProjectWorkspace.inc"
#include "../App/WorkspaceSplit.inc"
@interface DraftController : UIViewController
@property UITextView *text;
@end
@implementation DraftController
- (void)viewDidLoad{[super viewDidLoad];self.text=[[UITextView alloc]initWithFrame:self.view.bounds];self.text.text=@"UNSAVED_DRAFT";self.text.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;[self.view addSubview:self.text];}
- (BOOL)save{return YES;}
@end
@interface ISHProof : UIResponder <UIApplicationDelegate>
@property(nonatomic) UIWindow *window;
@property NSMutableArray *results;
@property NSString *processID,*serverID;
@property NSDictionary *previewInfo;
@property NSMutableData *installOutput;
@property TFAIISHMCPTransport *mcp;
@property TFAIWebDOM *dom;
@property WKWebView *domWeb;
@property BOOL domAllowed;
@property uint64_t installOffset;
@end
#import "../App/AI/Backup/DXBackup.h"
#import "../App/AI/Backup/DXBackupTask.h"
#import "../App/AI/Sandbox/TFAIISHHub.h"
#import "../App/GitPreferences.h"
BOOL TMCBuildIsRunning(void){return NO;}
BOOL TFAIHasLiveRuns(void){return NO;}
@implementation TMCGitLease
+ (instancetype)tryWrite{return [self new];}
+ (BOOL)hasActiveBuilds{return NO;}
@end
@implementation ISHProof
#include "Terminal263IOS.inc"
#include "Backup262IOS.inc"
#include "SharedTools260IOS.inc"
#include "DataWorkflows237IOS.inc"
#include "OptionalResources247IOS.inc"
#include "Packages253IOS.inc"
#include "ShareFolder241IOS.inc"
#include "Workspace227IOS.inc"
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts{
 self.results=[NSMutableArray new];self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];UIViewController *vc=[UIViewController new];vc.view.backgroundColor=UIColor.systemBackgroundColor;self.window.rootViewController=vc;[self.window makeKeyAndVisible];
 if([NSProcessInfo.processInfo.arguments containsObject:@"--terminal263"]){[self terminal263];return YES;}
 if([NSProcessInfo.processInfo.arguments containsObject:@"--backup262"]){[self backup262];return YES;}
 if([NSProcessInfo.processInfo.arguments containsObject:@"--shared260"]){[self shared260];return YES;}
 if([NSProcessInfo.processInfo.arguments containsObject:@"--shared260-check"]){[self shared260Check];return YES;}
 if([NSProcessInfo.processInfo.arguments containsObject:@"--folder-native240"]){self.window.rootViewController=[[UINavigationController alloc]initWithRootViewController:TFAIDirectoryRegistryController(@"native240")];return YES;}
 if([NSProcessInfo.processInfo.arguments containsObject:@"--share-native241"]){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{NSURL *folder=[self shareFixture241];UIActivityViewController *sheet=[[UIActivityViewController alloc]initWithActivityItems:@[folder] applicationActivities:nil];sheet.popoverPresentationController.sourceView=vc.view;sheet.popoverPresentationController.sourceRect=CGRectMake(100,100,1,1);[vc presentViewController:sheet animated:YES completion:nil];});return YES;}
 if([NSProcessInfo.processInfo.arguments containsObject:@"--packages253"]){[self packages253];return YES;}
 if([NSProcessInfo.processInfo.arguments containsObject:@"--resources247"]){[self resources247];return YES;}
 if([NSProcessInfo.processInfo.arguments containsObject:@"--resources247-persist"]){[self persistResources247];return YES;}
 if([NSProcessInfo.processInfo.arguments containsObject:@"--data237"]){[self data237];return YES;}
 if([NSProcessInfo.processInfo.arguments containsObject:@"--directory-check227"]){NSArray *args=NSProcessInfo.processInfo.arguments;[self directoryCheck227:[args[[args indexOfObject:@"--directory-check227"]+1] integerValue]];return YES;}
 if([NSProcessInfo.processInfo.arguments containsObject:@"--workspace227"]){[self workspace227];return YES;}
 if([NSProcessInfo.processInfo.arguments containsObject:@"--root-check227"]){NSArray *args=NSProcessInfo.processInfo.arguments;[self rootCheck227:[args[[args indexOfObject:@"--root-check227"]+1] integerValue]];return YES;}
 if([NSProcessInfo.processInfo.arguments containsObject:@"--root227"]){[self root227];return YES;}
 if([NSProcessInfo.processInfo.arguments containsObject:@"--browser-ui"]){TFAIReadOnlyBrowser *first=[TFAIReadOnlyBrowser browserForSession:@"browser-a"],*other=[TFAIReadOnlyBrowser browserForSession:@"browser-b"];[self record:@"browser_session_isolation" passed:first!=other&&first.webView.configuration.websiteDataStore!=other.webView.configuration.websiteDataStore detail:nil];NSString *identifier=[TFAIReadOnlyBrowser tabsForSession:@"browser-a"].firstObject[@"id"];for(int i=0;i<7;i++)[TFAIReadOnlyBrowser newTabForSession:@"browser-a"];[self record:@"browser_tab_capacity" passed:[TFAIReadOnlyBrowser tabsForSession:@"browser-a"].count==8&&![TFAIReadOnlyBrowser newTabForSession:@"browser-a"] detail:nil];[self record:@"browser_tab_scope" passed:![TFAIReadOnlyBrowser selectTab:identifier session:@"browser-b"] detail:nil];[TFAIReadOnlyBrowser selectTab:identifier session:@"browser-a"];[self record:@"browser_select_preserves_webview" passed:[TFAIReadOnlyBrowser browserForSession:@"browser-a"]==first detail:nil];[TFAIReadOnlyBrowser closeTab:identifier session:@"browser-a"];[self record:@"browser_close_reselects" passed:[TFAIReadOnlyBrowser tabsForSession:@"browser-a"].count==7&&[TFAIReadOnlyBrowser browserForSession:@"browser-a"]!=first detail:nil];[TFAIReadOnlyBrowser setManualLogin:YES session:@"browser-a"];[self record:@"browser_manual_login_session_gate" passed:[TFAIReadOnlyBrowser AIBlockedForSession:@"browser-a"]&&![TFAIReadOnlyBrowser AIBlockedForSession:@"browser-b"]&&![TFAIReadOnlyBrowser newTabForSession:@"browser-a"]&&![TFAIReadOnlyBrowser selectTab:identifier session:@"browser-a"] detail:nil];[first perform:@{@"action":@"observe"} completion:^(NSDictionary *r,NSError *error){[self record:@"browser_stale_tab_cannot_read_login" passed:error&&!r detail:nil];}];[TFAIReadOnlyBrowser setManualLogin:NO session:@"browser-a"];[self record:@"browser_manual_login_exit_readonly" passed:![TFAIReadOnlyBrowser AIBlockedForSession:@"browser-a"] detail:nil];[TFAIReadOnlyBrowser clearSession:@"browser-a" completion:^{[self record:@"browser_clear_isolation" passed:[TFAIReadOnlyBrowser tabsForSession:@"browser-a"].count==1&&[TFAIReadOnlyBrowser browserForSession:@"browser-b"]==other detail:nil];UIViewController *page=TFAIReadOnlyBrowserControllerWithAsk(@"browser-a",nil);self.window.rootViewController=[[UINavigationController alloc]initWithRootViewController:page];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{[self record:@"browser_ui" passed:page.isViewLoaded&&page.navigationItem.rightBarButtonItems.count==2 detail:@{@"width":@(page.view.bounds.size.width)}];});}];return YES;}
 if([NSProcessInfo.processInfo.arguments containsObject:@"--environment-ui"]){UIViewController *page=TFAIISHEnvironmentController(@"proof-one",nil);self.window.rootViewController=[[UINavigationController alloc]initWithRootViewController:page];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{[page.view layoutIfNeeded];UITableView *table=((UITableViewController *)page).tableView;[self record:@"environment_ui" passed:[page.title isEqual:@"Linux 环境"]&&table.numberOfSections==4&&table.bounds.size.width>0&&[table numberOfRowsInSection:0]==3 detail:@{@"width":@(table.bounds.size.width),@"height":@(table.bounds.size.height)}];});return YES;}
 if([NSProcessInfo.processInfo.arguments containsObject:@"--maintenance-seed"]||[NSProcessInfo.processInfo.arguments containsObject:@"--maintenance-backup"]||[NSProcessInfo.processInfo.arguments containsObject:@"--maintenance-restore"]||[NSProcessInfo.processInfo.arguments containsObject:@"--maintenance-reset"]){[self maintenanceSmoke];return YES;}
 if([NSProcessInfo.processInfo.arguments containsObject:@"--verify-persistence"]){
  NSArray *history=[TFAIISHRuntime.shared processes:@"proof-one"];BOOL hasInterrupted=NO,noReplay=YES,noSecrets=YES;for(NSDictionary *row in history){if([row[@"state"] isEqual:@"interrupted_by_app_restart"])hasInterrupted=YES;noReplay&=![row[@"running"] boolValue];noSecrets&=!row[@"command"]&&!row[@"output"]&&!row[@"environment"];}
  [self record:@"process_restart_history" passed:hasInterrupted&&noReplay&&noSecrets&&history.count<=32 detail:history];
  [[TFAIISHRuntime shared]execute:@"cat /workspace/persist.txt" session:@"proof-one" timeout:15 output:nil completion:^(NSDictionary *r,NSError *e){[self.results addObject:@{@"test":@"app_restart_persistence",@"passed":@(!e&&[r[@"output"] containsString:@"persisted"]),@"result":r?:@{},@"error":e.localizedDescription?:@""}];[self save];}];
 }else if([NSProcessInfo.processInfo.arguments containsObject:@"--test-reverse-only"])[self reverseTests];else [self run:0];return YES;
}
- (void)skillSmoke:(void(^)(void))done{
 NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:@"dylix-skill-proof"],*folder=[root stringByAppendingPathComponent:@".dylix/skills/theos-logos"],*file=[folder stringByAppendingPathComponent:@"SKILL.md"];
 [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];[@"---\nname: Override\ndescription: Project test\n---\nSKILL_PROJECT_ONE" writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:nil];
 [@"NEVER_EXPOSE_SCRIPT" writeToFile:[folder stringByAppendingPathComponent:@"run.sh"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
 [TFAIISHRuntime.shared configureProject:root session:@"proof-project-skills"];
 [TFAIISHRuntime.shared execute:@"cat $DYLIX_SKILLS_DIR/theos-logos/SKILL.md; test ! -f $DYLIX_SKILLS_DIR/theos-logos/run.sh && echo NO_SCRIPTS" session:@"proof-project-skills" timeout:20 output:nil completion:^(NSDictionary *r,NSError *e){[self record:@"skills_project_override_and_no_scripts" passed:!e&&[r[@"output"] containsString:@"SKILL_PROJECT_ONE"]&&[r[@"output"] containsString:@"NO_SCRIPTS"] detail:e.localizedDescription];
  [@"---\nname: Override\ndescription: Project test\n---\nSKILL_PROJECT_TWO" writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [TFAIISHRuntime.shared execute:@"cat $DYLIX_SKILLS_DIR/theos-logos/SKILL.md; if rm $DYLIX_SKILLS_DIR/theos-logos/SKILL.md 2>/dev/null; then echo REMOVE_FAILED; else echo REMOVE_BLOCKED; fi" session:@"proof-project-skills" timeout:20 output:nil completion:^(NSDictionary *r,NSError *e){[self record:@"skills_hot_refresh_and_remove_blocked" passed:!e&&[r[@"output"] containsString:@"SKILL_PROJECT_TWO"]&&[r[@"output"] containsString:@"REMOVE_BLOCKED"] detail:e.localizedDescription];
   [TFAIISHRuntime.shared execute:@"cat $DYLIX_SKILLS_DIR/theos-logos/SKILL.md" session:@"proof-two" timeout:20 output:nil completion:^(NSDictionary *r,NSError *e){[self record:@"skills_project_isolated_across_sessions" passed:!e&&[r[@"output"] length]>0&&![r[@"output"] containsString:@"SKILL_PROJECT_TWO"] detail:e.localizedDescription];[self projectCopySmoke:root done:done];}];
  }];
 }];
}
- (void)projectCopySmoke:(NSString *)root done:(void(^)(void))done{
 NSString *source=[root stringByAppendingPathComponent:@"Tweak.m"];[@"int project_copy_original = 7;\n" writeToFile:source atomically:YES encoding:NSUTF8StringEncoding error:nil];
 [TFAIISHRuntime.shared importProjectCopy:root session:@"proof-project-skills" completion:^(NSDictionary *r,NSError *e){[self record:@"project_source_copy_import" passed:!e&&[r[@"files"] intValue]==1 detail:e.localizedDescription];if(e){done();return;}NSString *command=[NSString stringWithFormat:@"pwd; cat '%@/Tweak.m'; echo CHANGED_IN_GUEST > '%@/Tweak.m'",r[@"path"],r[@"path"]];
  [TFAIISHRuntime.shared execute:command session:@"proof-project-skills" timeout:20 output:nil completion:^(NSDictionary *out,NSError *e){NSString *host=[NSString stringWithContentsOfFile:source encoding:NSUTF8StringEncoding error:nil];[self record:@"project_cwd_and_copy_do_not_mutate_original" passed:!e&&[out[@"output"] containsString:@"/workspace/projects/"]&&[out[@"output"] containsString:@"project_copy_original"]&&[host containsString:@"project_copy_original"] detail:e.localizedDescription];
   for(int i=0;i<25;i++)[@"int header;" writeToFile:[root stringByAppendingPathComponent:[NSString stringWithFormat:@"limit-%d.h",i]] atomically:YES encoding:NSUTF8StringEncoding error:nil];
   [TFAIISHRuntime.shared importProjectCopy:root session:@"proof-project-skills" completion:^(NSDictionary *r,NSError *e){[self record:@"project_copy_retains_existing_file_limit" passed:e&&!r detail:e.localizedDescription];for(int i=0;i<25;i++)[NSFileManager.defaultManager removeItemAtPath:[root stringByAppendingPathComponent:[NSString stringWithFormat:@"limit-%d.h",i]] error:nil];done();}];
  }];
 }];
}
- (void)maintenanceSmoke{
 NSArray *args=NSProcessInfo.processInfo.arguments;BOOL seed=[args containsObject:@"--maintenance-seed"],reset=[args containsObject:@"--maintenance-reset"],restore=[args containsObject:@"--maintenance-restore"];
 NSString *session=@"proof-maintenance",*key=TFAIISHEnvironment.sharedKey,*stage=seed?@"seed":reset?@"reset":restore?@"restore":@"backup";
 void(^run)(void)=^{NSString *command=seed?@"mkdir -p /workspace; printf ORIGINAL > /workspace/env-one; rm -f /workspace/env-two; ln /workspace/env-one /workspace/env-two; chmod 640 /workspace/env-one; echo SEEDED":reset?@"test ! -f /workspace/env-one && echo RESET_OK":restore?@"cat /workspace/env-one; cat /workspace/env-two; test $(stat -c %i /workspace/env-one) = $(stat -c %i /workspace/env-two) && echo LINKS_OK; stat -c %a /workspace/env-one":@"printf CHANGED > /workspace/env-one; echo CHANGED_OK";
 [TFAIISHRuntime.shared execute:command session:session timeout:30 output:nil completion:^(NSDictionary *r,NSError *e){NSString *text=r[@"output"];BOOL ok=!e&&[r[@"exit_code"] intValue]==0&&(seed?[text containsString:@"SEEDED"]:reset?[text containsString:@"RESET_OK"]:restore?([text containsString:@"ORIGINALORIGINAL"]&&[text containsString:@"LINKS_OK"]&&[text containsString:@"640"]):[text containsString:@"CHANGED_OK"]);[self record:[@"maintenance_" stringByAppendingString:stage] passed:ok detail:r?:e.localizedDescription];}];};
 if(seed){run();return;}
 NSString *snapshot=nil;if(restore){NSDictionary *inventory=[TFAIISHEnvironment inventoryAtBase:TFAIISHEnvironment.basePath];for(NSDictionary *row in inventory[@"snapshots"])if([row[@"sessionKey"] isEqual:key]){snapshot=row[@"id"];break;}}
 [TFAIISHRuntime.shared scheduleMaintenance:reset?@"reset":restore?@"restore":@"backup" sessionKey:key snapshot:snapshot completion:^(NSError *e){if(e)[self record:[@"maintenance_" stringByAppendingString:stage] passed:NO detail:e.localizedDescription];else run();}];
}
- (void)save{
 NSString *path=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"ish-regression.json"];
 [[NSJSONSerialization dataWithJSONObject:self.results options:NSJSONWritingPrettyPrinted error:nil] writeToFile:path atomically:YES];
}
- (void)run:(NSUInteger)i{
 NSArray *cases=@[
  @{@"session":@"proof-one",@"command":@"test -f $DYLIX_SKILLS_DIR/theos-logos/SKILL.md; ls $DYLIX_SKILLS_DIR; if echo bad > $DYLIX_SKILLS_DIR/WRONG 2>/dev/null; then echo WRITE_FAILED; else echo SKILLS_READ_ONLY; fi; if chmod 777 $DYLIX_SKILLS_DIR 2>/dev/null; then echo CHMOD_FAILED; else echo SKILLS_CHMOD_BLOCKED; fi",@"expect":@"SKILLS_READ_ONLY",@"also":@"SKILLS_CHMOD_BLOCKED"},
  @{@"session":@"proof-one",@"command":@"uname -m; printf 'DYLIX_REAL_LINUX\\n'; pwd",@"expect":@"aarch64"},
  @{@"session":@"proof-one",@"command":@"printf 'persisted' > /workspace/persist.txt; cat /workspace/persist.txt; exit 7",@"expect":@"persisted",@"exit":@7},
  @{@"session":@"proof-two",@"command":@"test -f /workspace/persist.txt && echo ENVIRONMENT_SHARED; cd /; cd ../../..; pwd; ln -sf /bin/sh /tmp/sh; /tmp/sh -c 'echo SYMLINK_OK'",@"expect":@"ENVIRONMENT_SHARED",@"also":@"SYMLINK_OK"},
  @{@"session":@"proof-one",@"command":@"cat /workspace/persist.txt; cat /../../../../etc/alpine-release; mkdir -p /tmp/mnt; mount -t realfs / /tmp/mnt; echo MOUNT_STATUS=$?",@"expect":@"MOUNT_STATUS=1"},
  @{@"session":@"proof-one",@"command":@"printf 'before-timeout\\n'; sleep 20; echo BAD_TIMEOUT",@"expect":@"before-timeout",@"timeout":@1},
  @{@"session":@"proof-one",@"command":@"printf 'after-timeout\\n'; cat /workspace/persist.txt",@"expect":@"after-timeout"},
  @{@"session":@"proof-two",@"command":@"ln -sf /../../sessions /tmp/escape; test ! -e /tmp/escape && test ! -d /sessions && test -f /workspace/persist.txt && echo NO_HOST_ESCAPE",@"expect":@"NO_HOST_ESCAPE"},
  @{@"session":@"proof-one",@"command":@"i=0; while [ $i -lt 8 ]; do /bin/sh -c 'printf x'; i=$((i+1)); done; printf ' REPEATED_FORK_OK\\n'; printf '中文输出\\n'",@"expect":@"REPEATED_FORK_OK",@"also":@"中文输出"},
  @{@"session":@"proof-one",@"command":@"yes bounded | head -c 140000; echo OUTPUT_END",@"expect":@"OUTPUT_END",@"truncated":@YES}
 ];
 if(i==cases.count){[self skillSmoke:^{[self installPreviewRuntime];}];return;}
 NSDictionary *c=cases[i];[[TFAIISHRuntime shared]execute:c[@"command"] session:c[@"session"] timeout:c[@"timeout"]?[c[@"timeout"] doubleValue]:20 output:nil completion:^(NSDictionary *r,NSError *e){
  BOOL passed=!e&&[r[@"output"] containsString:c[@"expect"]]&&(!c[@"exit"]||[r[@"exit_code"] isEqual:c[@"exit"]])&&(!c[@"also"]||[r[@"output"] containsString:c[@"also"]]);
  if(c[@"truncated"])passed=passed&&[r[@"truncated"] boolValue]&&[r[@"output"] lengthOfBytesUsingEncoding:NSUTF8StringEncoding]<=65536;
  if(c[@"timeout"])passed=passed&&[r[@"timed_out"] boolValue]&&![r[@"output"] containsString:@"BAD_TIMEOUT"];
  [self.results addObject:@{@"test":@(i),@"passed":@(passed),@"result":r?:@{},@"error":e.localizedDescription?:@""}];[self save];NSLog(@"ISH_TEST %lu %@ %@",(unsigned long)i,passed?@"PASS":@"FAIL",r?:e);[self run:i+1];
 }];
}

- (void)reverseOperations:(NSUInteger)index {
 NSArray *operations=@[@"functions",@"cfg",@"xrefs",@"disassemble",@"strings",@"imports",@"sections",@"pcode"];
 if(index>=operations.count){
  NSURL *file=[NSBundle.mainBundle URLForResource:@"reverse-fixture" withExtension:@"dylib"];
  [TFAIISHRuntime.shared analyzeBinaryFile:file arguments:@{@"operation":@"decompile",@"address":@"0x1"} session:@"proof-reverse" completion:^(NSDictionary *r,NSError *e){[self record:@"reverse_unaligned_address_rejected_before_launch" passed:e&&!r detail:nil];[self reverseArm64e];}];return;
 }
 NSString *operation=operations[index];NSURL *file=[NSBundle.mainBundle URLForResource:@"reverse-fixture" withExtension:@"dylib"];NSDictionary *meta=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"reverse-fixture" withExtension:@"json"]] options:0 error:nil];
 [TFAIISHRuntime.shared analyzeBinaryFile:file arguments:@{@"operation":operation,@"address":meta[@"address"]} session:@"proof-reverse" completion:^(NSDictionary *r,NSError *e){
  if(!r){[self record:[@"reverse_engine_" stringByAppendingString:operation] passed:NO detail:e.localizedDescription];[self reverseOperations:index+1];return;}
  [self awaitProcess:r[@"process_id"] session:@"proof-reverse" offset:0 collected:[NSMutableString new] completion:^(NSDictionary *exit,NSString *text){
   [TFAIISHRuntime.shared fileOperation:@"read" path:r[@"output_path"] arguments:@{} session:@"proof-reverse" completion:^(NSDictionary *out,NSError *e){
    NSString *source=out[@"content"];BOOL good=!e&&[exit[@"exit_code"] intValue]==0&&source.length&&!([source containsString:@"ERROR:"]);
    if(![operation isEqual:@"pcode"]){id json=source?[NSJSONSerialization JSONObjectWithData:[source dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil]:nil;good&=[json isKindOfClass:NSArray.class];if(![@[@"imports",@"strings"] containsObject:operation])good&=[json count]>0;if([operation isEqual:@"functions"])good&=[source containsString:@"dylix_fixture_add"]&&[source containsString:@"dylix_fixture_call"];}
    [self record:[@"reverse_engine_" stringByAppendingString:operation] passed:good detail:@{@"bytes":out[@"bytes"]?:@0,@"output":source?:@"",@"diagnostic":text?:@""}];[self reverseOperations:index+1];
   }];
  }];
 }];
}
- (void)reverseArm64e{
 NSURL *file=[NSBundle.mainBundle URLForResource:@"reverse-arm64e" withExtension:@"dylib"];NSDictionary *meta=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"reverse-arm64e" withExtension:@"json"]] options:0 error:nil];
 [TFAIISHRuntime.shared analyzeBinaryFile:file arguments:@{@"operation":@"decompile",@"address":meta[@"address"]} session:@"proof-reverse" completion:^(NSDictionary *r,NSError *e){if(!r){[self record:@"ghidra_arm64e_decompilation" passed:NO detail:e.localizedDescription];[self record:@"reverse_suite_finished" passed:NO detail:nil];return;}
  [self awaitProcess:r[@"process_id"] session:@"proof-reverse" offset:0 collected:[NSMutableString new] completion:^(NSDictionary *exit,NSString *text){[TFAIISHRuntime.shared fileOperation:@"read" path:r[@"output_path"] arguments:@{} session:@"proof-reverse" completion:^(NSDictionary *out,NSError *e){BOOL valid=!e&&[exit[@"exit_code"] intValue]==0&&[out[@"content"] containsString:@"* 3 + 7"];[self record:@"ghidra_arm64e_decompilation" passed:valid detail:out[@"content"]?:text];[self record:@"reverse_suite_finished" passed:valid detail:nil];}];}];
 }];
}
- (void)reverseTests{[TFAIISHRuntime.shared installReverseTools:@"proof-reverse" completion:^(NSDictionary *r,NSError *e){[self record:@"reverse_signed_package_install_started" passed:!e&&r[@"process_id"] detail:e.localizedDescription];if(!r){[self record:@"reverse_suite_finished" passed:NO detail:e.localizedDescription];return;}[self awaitProcess:r[@"process_id"] session:@"proof-reverse" offset:0 collected:[NSMutableString new] completion:^(NSDictionary *exit,NSString *text){[self record:@"reverse_official_apk_signatures_isolated_install" passed:[exit[@"exit_code"] intValue]==0&&[text containsString:@"DYLIX_REVERSE_TOOLS_INSTALLED"] detail:text];if([exit[@"exit_code"] intValue]!=0){[self record:@"reverse_suite_finished" passed:NO detail:text];return;}NSURL *file=[NSBundle.mainBundle URLForResource:@"reverse-fixture" withExtension:@"dylib"];NSDictionary *meta=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"reverse-fixture" withExtension:@"json"]] options:0 error:nil];[TFAIISHRuntime.shared analyzeBinaryFile:file arguments:@{@"operation":@"decompile",@"address":meta[@"address"]} session:@"proof-reverse" completion:^(NSDictionary *r,NSError *e){[self record:@"ghidra_targeted_analysis_started" passed:!e&&r[@"process_id"]&&r[@"output_path"] detail:e.localizedDescription];if(!r){[self record:@"reverse_suite_finished" passed:NO detail:e.localizedDescription];return;}[self awaitProcess:r[@"process_id"] session:@"proof-reverse" offset:0 collected:[NSMutableString new] completion:^(NSDictionary *exit,NSString *text){[self record:@"ghidra_real_process_exit" passed:[exit[@"exit_code"] intValue]==0 detail:text];[TFAIISHRuntime.shared fileOperation:@"read" path:r[@"output_path"] arguments:@{} session:@"proof-reverse" completion:^(NSDictionary *out,NSError *e){NSString *source=out[@"content"];BOOL valid=[source containsString:@"return"]&&[source containsString:@"* 3 + 7"]&&!([source containsString:@"ERROR:"]);[self record:@"ghidra_real_native_C_decompilation" passed:!e&&valid detail:source?:e.localizedDescription];[TFAIISHRuntime.shared execute:@"cat /etc/alpine-release; test ! -f /usr/bin/radare2 && echo BASE_NOT_UPGRADED" session:@"proof-reverse" timeout:15 output:nil completion:^(NSDictionary *base,NSError *e){[self record:@"reverse_engine_separate_prefix" passed:!e&&[base[@"output"] containsString:@"3.21.0"]&&[base[@"output"] containsString:@"BASE_NOT_UPGRADED"] detail:base];[self reverseOperations:0];}];}];}];}];}];}];}
- (void)awaitProcess:(NSString *)identifier session:(NSString *)session offset:(uint64_t)offset collected:(NSMutableString *)collected completion:(void(^)(NSDictionary *,NSString *))completion{[TFAIISHRuntime.shared performProcess:@"read" arguments:@{@"process_id":identifier,@"offset":@(offset),@"wait_seconds":@10} session:session completion:^(NSDictionary *r,NSError *e){NSString *text=r[@"output"];if(text)[collected appendString:text];if(e||![r[@"running"] boolValue]){completion(r?:@{@"exit_code":@(-1)},collected);return;}[self awaitProcess:identifier session:session offset:[r[@"next_offset"] unsignedLongLongValue] collected:collected completion:completion];}];}

- (void)fileTests{
 NSString *path=[@"/workspace/file-" stringByAppendingString:NSUUID.UUID.UUIDString];
 [TFAIISHRuntime.shared fileOperation:@"write" path:path arguments:@{@"content":@"中文 file\n",@"sha256":@"missing"} session:@"proof-one" completion:^(NSDictionary *r,NSError *e){[self record:@"vfs_create_utf8" passed:!e&&[r[@"bytes"] intValue]==12 detail:e.localizedDescription];
  [TFAIISHRuntime.shared fileOperation:@"read" path:path arguments:@{} session:@"proof-one" completion:^(NSDictionary *r,NSError *e){[self record:@"vfs_read_exact_utf8" passed:!e&&[r[@"content"] isEqual:@"中文 file\n"]&&[r[@"sha256"] length]==64 detail:e.localizedDescription];NSString *hash=r[@"sha256"]?:@"invalid";
   [TFAIISHRuntime.shared fileOperation:@"write" path:path arguments:@{@"content":@"BAD",@"sha256":@"stale"} session:@"proof-one" completion:^(NSDictionary *r,NSError *e){[self record:@"vfs_stale_write_rejected" passed:e&&!r detail:nil];
    [TFAIISHRuntime.shared fileOperation:@"write" path:path arguments:@{@"content":@"changed",@"sha256":hash} session:@"proof-one" completion:^(NSDictionary *r,NSError *e){[self record:@"vfs_atomic_edit" passed:!e&&[r[@"content"] isEqual:@"changed"] detail:e.localizedDescription];
     [TFAIISHRuntime.shared fileOperation:@"list" path:@"/workspace" arguments:@{} session:@"proof-one" completion:^(NSDictionary *r,NSError *e){BOOL found=NO;for(NSDictionary *row in r[@"items"])if([row[@"path"] isEqual:path])found=YES;[self record:@"vfs_directory_listing" passed:!e&&found detail:e.localizedDescription];[self rejectFileCase:0 path:path];}];
    }];
   }];
  }];
 }];
}
- (void)rejectFileCase:(NSUInteger)i path:(NSString *)path{
 NSArray *paths=@[@"/../../etc/passwd",@"/tmp/sh",@"/dev/null",@"/workspace"];
 if(i==paths.count){[TFAIISHRuntime.shared fileOperation:@"read" path:path arguments:@{} session:@"proof-two" completion:^(NSDictionary *r,NSError *e){[self record:@"vfs_cross_session_read_shared" passed:!e&&[r[@"content"] isEqual:@"changed"] detail:nil];[self advancedFiles];}];return;}
 [TFAIISHRuntime.shared fileOperation:@"read" path:paths[i] arguments:@{} session:@"proof-two" completion:^(NSDictionary *r,NSError *e){[self record:[@"vfs_reject_" stringByAppendingString:paths[i]] passed:e&&!r detail:nil];[self rejectFileCase:i+1 path:path];}];
}
- (void)advancedFiles{
 NSString *base=[@"/workspace/batch-" stringByAppendingString:NSUUID.UUID.UUIDString];NSString *setup=[NSString stringWithFormat:@"mkdir -p '%@/source/sub' '%@/dest'; printf '中文123' > '%@/source/sub/a.txt'; printf data > '%@/source/keep.txt'; ln -s /etc/passwd '%@/alias'",base,base,base,base,base];
 [TFAIISHRuntime.shared execute:setup session:@"proof-one" timeout:15 output:nil completion:^(NSDictionary *r,NSError *e){NSArray *tests=@[
 @{@"test":@"vfs_recursive_batch_copy",@"op":@"copy",@"path":base,@"args":@{@"paths":@[[base stringByAppendingString:@"/source"]],@"destination":[base stringByAppendingString:@"/dest"]}},
 @{@"test":@"vfs_copy_never_overwrites",@"op":@"copy",@"path":base,@"args":@{@"paths":@[[base stringByAppendingString:@"/source"]],@"destination":[base stringByAppendingString:@"/dest"]},@"error":@YES},
 @{@"test":@"vfs_copy_rejects_link",@"op":@"copy",@"path":base,@"args":@{@"paths":@[[base stringByAppendingString:@"/alias"]],@"destination":[base stringByAppendingString:@"/dest"]},@"error":@YES},
 @{@"test":@"vfs_copy_rejects_self_descendant",@"op":@"copy",@"path":base,@"args":@{@"paths":@[[base stringByAppendingString:@"/source"]],@"destination":[base stringByAppendingString:@"/source/sub"]},@"error":@YES},
 @{@"test":@"vfs_move_rejects_system_source",@"op":@"move",@"path":base,@"args":@{@"paths":@[@"/etc/passwd"],@"destination":[base stringByAppendingString:@"/dest"]},@"error":@YES},
 @{@"test":@"vfs_recursive_filename_search",@"op":@"search",@"path":[base stringByAppendingString:@"/dest"],@"args":@{@"query":@"a.txt"},@"items":@1},
 @{@"test":@"vfs_directory_text_review",@"op":@"tree",@"path":[base stringByAppendingString:@"/dest"],@"args":@{},@"items":@2},
 @{@"test":@"vfs_utf8_page_boundary",@"op":@"read_range",@"path":[base stringByAppendingString:@"/dest/source/sub/a.txt"],@"args":@{@"max_bytes":@7},@"text":@"中文1",@"next":@7},
 @{@"test":@"vfs_utf8_next_page",@"op":@"read_range",@"path":[base stringByAppendingString:@"/dest/source/sub/a.txt"],@"args":@{@"offset":@7,@"max_bytes":@3},@"text":@"23",@"next":@9},
 @{@"test":@"vfs_utf8_split_character_trimmed",@"op":@"read_range",@"path":[base stringByAppendingString:@"/dest/source/sub/a.txt"],@"args":@{@"max_bytes":@4},@"text":@"中",@"next":@3},
 @{@"test":@"vfs_paging_bad_offset_rejected",@"op":@"read_range",@"path":[base stringByAppendingString:@"/dest/source/sub/a.txt"],@"args":@{@"offset":@99},@"error":@YES},
 @{@"test":@"vfs_rename_directory",@"op":@"rename",@"path":[base stringByAppendingString:@"/dest/source"],@"args":@{@"destination":[base stringByAppendingString:@"/dest/renamed"]}},
 @{@"test":@"vfs_batch_move",@"op":@"move",@"path":base,@"args":@{@"paths":@[[base stringByAppendingString:@"/dest/renamed/sub/a.txt"],[base stringByAppendingString:@"/dest/renamed/keep.txt"]],@"destination":[base stringByAppendingString:@"/dest"]}},
 @{@"test":@"vfs_batch_destination_conflict_preflight",@"op":@"copy",@"path":base,@"args":@{@"paths":@[[base stringByAppendingString:@"/source/sub/a.txt"],[base stringByAppendingString:@"/source/keep.txt"]],@"destination":[base stringByAppendingString:@"/dest"]},@"error":@YES},
 @{@"test":@"vfs_executable_probe_follows_guest_link",@"op":@"probe",@"path":@"/usr/bin/python3",@"args":@{},@"executable":@YES}
 ];[self fileCases:tests index:0];}];
}
- (void)fileCases:(NSArray *)cases index:(NSUInteger)index{if(index==cases.count){[self localMCPTests];return;}NSDictionary *test=cases[index];[TFAIISHRuntime.shared fileOperation:test[@"op"] path:test[@"path"] arguments:test[@"args"] session:@"proof-one" completion:^(NSDictionary *r,NSError *e){BOOL ok=[test[@"error"] boolValue]?(e&&!r):(!e&&r);if(test[@"items"])ok&=[r[@"items"] count]==[test[@"items"] unsignedIntegerValue];if(test[@"text"])ok&=[r[@"content"] isEqual:test[@"text"]];if(test[@"next"])ok&=[r[@"next_offset"] isEqual:test[@"next"]];if(test[@"executable"])ok&=[r[@"executable"] boolValue];[self record:test[@"test"] passed:ok detail:e.localizedDescription];[self fileCases:cases index:index+1];}];}

- (void)localMCPTests{
 NSString *script=@"import sys,json,time,os\nfor line in sys.stdin:\n r=json.loads(line)\n os.set_blocking(0,False)\n assert not os.get_blocking(0)\n os.set_blocking(0,True)\n if 'id' not in r: continue\n if r['method']=='exit': sys.exit(0)\n if r['method']=='wait': time.sleep(35)\n print('diagnostic 中文',file=sys.stderr,flush=True)\n print(json.dumps({'jsonrpc':'2.0','id':'wrong-id','result':{'wrong':True}}),flush=True)\n result={'protocolVersion':'2025-06-18','echo':r.get('params',{}),'argv':sys.argv[1:],'envOk':os.environ.get('DYLIX_PROOF_TOKEN')=='fixture-env-value'}\n if r['method']=='tools/call': result={'content':[{'type':'text','text':'LOOKUP_OK'}]}\n if r['method']=='tools/list': result={'tools':[{'name':'lookup','inputSchema':{'type':'object'},'annotations':{'readOnlyHint':True,'destructiveHint':False}}]}\n out=json.dumps({'jsonrpc':'2.0','id':r['id'],'result':result},ensure_ascii=False)+'\\n'\n mid=len(out)//2\n sys.stdout.write(out[:mid]);sys.stdout.flush();time.sleep(.03);sys.stdout.write(out[mid:]);sys.stdout.flush()\n";
 NSString *path=[@"/workspace/mcp-" stringByAppendingFormat:@"%@.py",NSUUID.UUID.UUIDString];
 [TFAIISHRuntime.shared fileOperation:@"write" path:path arguments:@{@"content":script,@"sha256":@"missing"} session:@"proof-one" completion:^(NSDictionary *r,NSError *e){if(e){[self record:@"stdio_fixture_create" passed:NO detail:e.localizedDescription];[self importFixture];return;}self.mcp=[TFAIISHMCPTransport new];
  [self.mcp start:@"/usr/bin/python3" arguments:@[@"-u",path,@"literal ; $(echo BAD)"] environment:@{@"DYLIX_PROOF_TOKEN":@"fixture-env-value"} session:@"proof-one" completion:^(NSError *e){[self record:@"stdio_guest_python_launch" passed:!e&&self.mcp.ready detail:e.localizedDescription];if(e){[self importFixture];return;}
   NSString *handle=[self.mcp valueForKey:@"handle"];[TFAIISHRuntime.shared stdio:handle input:nil session:@"proof-two" completion:^(NSDictionary *r,NSError *e){[self record:@"stdio_cross_session_handle_rejected" passed:e&&!r detail:nil];
    [self.mcp request:@{@"jsonrpc":@"2.0",@"id":@"init",@"method":@"initialize",@"params":@{@"text":@"中文"}} completion:^(NSDictionary *r,NSError *e){[self record:@"stdio_fragmented_json_stderr_wrong_id" passed:!e&&[r[@"echo"][@"text"] isEqual:@"中文"]&&[r[@"argv"] isEqual:@[@"literal ; $(echo BAD)"]]&&[r[@"envOk"] boolValue] detail:r?:e.localizedDescription];
     [self.mcp request:@{@"jsonrpc":@"2.0",@"method":@"notifications/initialized"} completion:^(NSDictionary *r,NSError *e){[self record:@"stdio_notification_no_reply" passed:!e detail:nil];
      [self.mcp request:@{@"jsonrpc":@"2.0",@"id":@"list",@"method":@"tools/list"} completion:^(NSDictionary *r,NSError *e){[self record:@"stdio_tool_list" passed:!e&&[r[@"tools"] count]==1 detail:r?:e.localizedDescription];
       [self.mcp request:@{@"jsonrpc":@"2.0",@"id":@"call",@"method":@"tools/call",@"params":@{@"name":@"lookup"}} completion:^(NSDictionary *r,NSError *e){[self record:@"stdio_tool_call" passed:!e&&[r[@"content"] count]==1 detail:e.localizedDescription];
        [self.mcp request:@{@"jsonrpc":@"2.0",@"id":@"exit",@"method":@"exit"} completion:^(NSDictionary *r,NSError *e){[self record:@"stdio_eof_reported" passed:e&&!self.mcp.ready detail:e.localizedDescription];[self.mcp close];[self mcpRegistryTests:path];}];
       }];
      }];
     }];
    }];
   }];
  }];
 }];
}
- (void)mcpRegistryTests:(NSString *)path{
 TFAIMCP *store=[TFAIMCP new];NSString *name=[@"Proof-" stringByAppendingString:NSUUID.UUID.UUIDString];NSDictionary *config=@{@"mcpServers":@{name:@{@"transport":@"stdio",@"command":@"/usr/bin/python3",@"args":@[@"-u",path],@"env":@{@"DYLIX_PROOF_TOKEN":@"fixture-env-value"}}}};NSString *text=[[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:config options:0 error:nil] encoding:NSUTF8StringEncoding];NSError *error=nil;
 BOOL imported=[store importJSON:text error:&error];[self record:@"mcp_stdio_configuration_import" passed:imported detail:error.localizedDescription];NSString *identifier=nil;for(NSDictionary *row in store.servers)if([row[@"name"] isEqual:name])identifier=row[@"id"];if(!identifier){[self importFixture];return;}
 NSString *configPath=[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"DylixAgent/mcp.json"];NSString *stored=[NSString stringWithContentsOfFile:configPath encoding:NSUTF8StringEncoding error:nil];[self record:@"mcp_environment_values_absent_from_configuration" passed:stored.length&&![stored containsString:@"fixture-env-value"]&&[stored containsString:@"DYLIX_PROOF_TOKEN"] detail:nil];NSDictionary *diagnostic=[store diagnostics:identifier session:@"proof-one"];[self record:@"mcp_diagnostics_only_environment_names" passed:[diagnostic[@"environmentKeys"] containsObject:@"DYLIX_PROOF_TOKEN"]&&![diagnostic.description containsString:@"fixture-env-value"] detail:diagnostic];NSError *envError=nil;[self record:@"mcp_runtime_override_environment_rejected" passed:![store setEnvironment:@{@"LD_PRELOAD":@"evil"} server:identifier error:&envError]&&envError detail:nil];TFAIMCP *reloaded=[TFAIMCP new];BOOL persisted=NO;for(NSDictionary *row in reloaded.servers)if([row[@"id"] isEqual:identifier]&&[row[@"transport"] isEqual:@"stdio"])persisted=YES;[self record:@"mcp_stdio_configuration_reload" passed:persisted detail:nil];
 [store discover:identifier session:@"proof-one" launchApproved:NO completion:^(NSDictionary *r,NSError *e){[self record:@"mcp_start_requires_native_confirmation" passed:e&&!r detail:nil];
 [store discover:identifier session:@"proof-one" launchApproved:YES completion:^(NSDictionary *r,NSError *e){[self record:@"mcp_initialize_notification_list_chain" passed:!e&&[r[@"tools"] count]==1 detail:e.localizedDescription];if(e){[store remove:identifier];[self importFixture];return;}
  NSError *allowError=nil;BOOL allowed=[store setAllowed:YES tool:@"lookup" server:identifier error:&allowError];[store setEnabled:YES server:identifier session:@"proof-one"];NSArray *schemas=[store schemas:@"proof-one"];[self record:@"mcp_explicit_readonly_allowlist_schema" passed:allowed&&schemas.count==1 detail:allowError.localizedDescription];[store setEnabled:YES server:identifier session:@"proof-two"];[self record:@"mcp_schema_requires_session_transport" passed:![store schemas:@"proof-two"].count detail:nil];
  [store call:schemas.firstObject[@"name"]?:@"missing" arguments:@{@"query":@"test"} session:@"proof-one" completion:^(NSDictionary *r,NSError *e){[self record:@"mcp_registered_tool_real_guest_call" passed:!e&&[r[@"content"] count]==1 detail:e.localizedDescription];NSArray *audit=[store auditForSession:@"proof-one"];BOOL audited=NO;for(NSDictionary *row in audit)if([row[@"method"] isEqual:@"tools/call"]&&[row[@"success"] boolValue])audited=YES;[self record:@"mcp_stdio_metadata_audit" passed:audited&&![audit.description containsString:@"fixture-env-value"]&&![audit.description containsString:@"query"]&&![store auditForSession:@"unrelated"].count detail:nil];[store setEnabled:NO server:identifier session:@"proof-one"];[self record:@"mcp_disable_revokes_schema" passed:![store schemas:@"proof-one"].count detail:nil];[store remove:identifier];[self stdioTimeoutTest];}];
 }];
 }];
}

- (void)stdioTimeoutTest{
 TFAIISHMCPTransport *transport=[TFAIISHMCPTransport new];[transport start:@"/bin/sleep" arguments:@[@"35"] session:@"proof-one" completion:^(NSError *e){if(e){[self record:@"stdio_timeout_closes_process" passed:NO detail:e.localizedDescription];[self filesUI];return;}NSTimeInterval started=NSProcessInfo.processInfo.systemUptime;[transport request:@{@"jsonrpc":@"2.0",@"id":@"timeout",@"method":@"initialize"} completion:^(NSDictionary *r,NSError *e){[self record:@"stdio_timeout_closes_process" passed:e&&!r&&!transport.ready&&NSProcessInfo.processInfo.systemUptime-started>=29 detail:e.localizedDescription];[self filesUI];}];}];
}
- (void)domTests:(void(^)(void))done{
 WKWebViewConfiguration *config=[WKWebViewConfiguration new];config.websiteDataStore=WKWebsiteDataStore.nonPersistentDataStore;self.domWeb=[[WKWebView alloc]initWithFrame:self.window.bounds configuration:config];UIViewController *page=[UIViewController new];[page.view addSubview:self.domWeb];self.window.rootViewController=page;__weak typeof(self) weak=self;self.dom=[[TFAIWebDOM alloc]initWithWebView:self.domWeb validator:^BOOL(NSURL *url){return weak.domAllowed&&[url.absoluteString isEqual:@"about:blank"];}];self.domAllowed=YES;
 [self.domWeb loadHTMLString:@"<meta name='viewport' content='width=device-width'><button onclick=\"document.querySelector('#status').textContent='CLICK_OK'\">Change</button><input type=search placeholder=Search oninput=\"document.querySelector('#status').textContent=this.value\"><select onchange=\"document.querySelector('#status').textContent=this.value\"><option value=a>A</option><option value=b>B</option></select><form method=post><button>POST blocked</button></form><input type=password value='NEVER_EXPOSE'><input type=file><p id=status>READY</p>" baseURL:nil];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{[self.dom perform:@{@"action":@"observe"} completion:^(NSDictionary *r,NSError *e){[self record:@"public_dom_visible_snapshot_no_secret_values" passed:!e&&[r[@"elements"] count]==4&&![r.description containsString:@"NEVER_EXPOSE"] detail:e.localizedDescription];NSString *click=[self domID:r text:@"Change" tag:nil],*token=r[@"snapshot"];[self.dom perform:@{@"action":@"click",@"id":click?:@"invalid",@"snapshot":token?:@"invalid"} completion:^(NSDictionary *r,NSError *e){[self record:@"public_dom_click_actual_page_event" passed:!e&&[r[@"text"] containsString:@"CLICK_OK"]&&[r[@"dispatched"] boolValue]&&![r[@"businessSuccessVerified"] boolValue] detail:e.localizedDescription];[self.dom perform:@{@"action":@"click",@"id":click?:@"0",@"snapshot":token?:@"invalid"} completion:^(NSDictionary *ignored,NSError *e){[self record:@"public_dom_stale_token_rejected" passed:e&&!ignored detail:nil];[self domType:r completion:done];}];}];}];});
}
- (NSString *)domID:(NSDictionary *)snapshot text:(NSString *)text tag:(NSString *)tag{for(NSDictionary *item in snapshot[@"elements"])if((!text||[item[@"text"] isEqual:text])&&(!tag||[item[@"tag"] isEqual:tag]))return item[@"id"];return nil;}
- (void)domType:(NSDictionary *)snapshot completion:(void(^)(void))done{NSString *identifier=[self domID:snapshot text:nil tag:@"INPUT"];[self.dom perform:@{@"action":@"type",@"id":identifier?:@"invalid",@"snapshot":snapshot[@"snapshot"]?:@"invalid",@"text":@"QUERY_OK"} completion:^(NSDictionary *r,NSError *e){[self record:@"public_dom_text_entry_dispatches_input_event" passed:!e&&[r[@"text"] containsString:@"QUERY_OK"] detail:e.localizedDescription];NSString *identifier=[self domID:r text:nil tag:@"SELECT"];[self.dom perform:@{@"action":@"select",@"id":identifier?:@"invalid",@"snapshot":r[@"snapshot"]?:@"invalid",@"text":@"b"} completion:^(NSDictionary *r,NSError *e){[self record:@"public_dom_select_actual_option" passed:!e&&[r[@"text"] hasSuffix:@"b"] detail:e.localizedDescription];NSString *identifier=[self domID:r text:@"POST blocked" tag:nil];[self.dom perform:@{@"action":@"click",@"id":identifier?:@"invalid",@"snapshot":r[@"snapshot"]?:@"invalid"} completion:^(NSDictionary *r,NSError *e){[self record:@"public_dom_post_form_blocked" passed:e&&!r detail:nil];[self.dom perform:@{@"action":@"screenshot"} completion:^(NSDictionary *r,NSError *e){NSData *image=[[NSData alloc]initWithBase64EncodedString:r[@"imageBase64"]?:@"" options:0];[self record:@"public_dom_transient_real_webkit_screenshot" passed:!e&&image.length&&image.length<=120*1024&&[UIImage imageWithData:image]!=nil detail:e.localizedDescription];self.domAllowed=NO;[self.dom perform:@{@"action":@"observe"} completion:^(NSDictionary *r,NSError *e){[self record:@"public_dom_url_or_permission_revocation_blocks" passed:e&&!r detail:nil];self.dom=nil;self.domWeb=nil;done();}];}];}];}];}];}

- (void)filesUI{
 UIViewController *page=TFAIISHFilesController(@"proof-one",nil);self.window.rootViewController=[[UINavigationController alloc]initWithRootViewController:page];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{UITableView *table=((UITableViewController *)page).tableView;[self record:@"native_linux_file_browser_ui" passed:[table numberOfRowsInSection:0]>0&&page.navigationItem.rightBarButtonItems.count==2 detail:@([table numberOfRowsInSection:0])];UIGraphicsBeginImageContextWithOptions(page.view.bounds.size,YES,1);[page.view drawViewHierarchyInRect:page.view.bounds afterScreenUpdates:YES];UIImage *image=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();if(image)[UIImagePNGRepresentation(image) writeToFile:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"linux-files.png"] atomically:YES];[self domTests:^{[self importFixture];}];});
}
- (void)browserTests:(NSDictionary *)snapshot{
 NSString *input=nil,*button=nil;for(NSDictionary *row in snapshot[@"elements"]){if([row[@"tag"] isEqual:@"INPUT"])input=row[@"id"];if([row[@"tag"] isEqual:@"BUTTON"])button=row[@"id"];}
 if(!input||!button){[self record:@"browser_test_controls_found" passed:NO detail:snapshot];[self showPreview];return;}
 TFAIISHBrowserAction(@{@"process_id":self.serverID,@"operation":@"type",@"snapshot":snapshot[@"snapshot"],@"id":input,@"text":@"中文 test"},@"proof-one",^(NSDictionary *typed,NSError *e){[self record:@"browser_type_and_observe" passed:!e&&[typed[@"snapshot"] length]&&![typed[@"snapshot"] isEqual:snapshot[@"snapshot"]] detail:e.localizedDescription];
  TFAIISHBrowserAction(@{@"process_id":self.serverID,@"operation":@"click",@"snapshot":snapshot[@"snapshot"],@"id":button},@"proof-one",^(NSDictionary *stale,NSError *e){[self record:@"browser_stale_snapshot_rejected" passed:e&&!stale detail:nil];
   TFAIISHBrowserAction(@{@"process_id":self.serverID,@"operation":@"click",@"snapshot":typed[@"snapshot"]?:@"invalid",@"id":button},@"proof-one",^(NSDictionary *clicked,NSError *e){[self record:@"browser_real_click_business_result" passed:!e&&[clicked[@"text"] containsString:@"CLICK_OK 中文 test"] detail:clicked?:e.localizedDescription];
    TFAIISHBrowserAction(@{@"process_id":self.serverID,@"operation":@"observe"},@"proof-two",^(NSDictionary *r,NSError *e){[self record:@"browser_foreign_session_rejected" passed:e&&!r detail:nil];[self showPreview];});
   });
  });
 });
}

- (void)importFixture{
 NSURL *fixture=[NSBundle.mainBundle URLForResource:@"smoke" withExtension:@"deb"];
 [[TFAIISHRuntime shared]importFile:fixture name:@"smoke.deb" session:@"proof-one" completion:^(NSDictionary *r,NSError *e){
  BOOL imported=!e&&[r[@"bytes"] unsignedIntegerValue]>0&&[r[@"path"] hasSuffix:@"smoke.deb"];
  [self.results addObject:@{@"test":@"native_file_import",@"passed":@(imported),@"error":e.localizedDescription?:@""}];[self save];
  if(!imported){[self cancelTest];return;}
  NSString *command=[NSString stringWithFormat:@"set -e; mkdir -p /workspace/deb-smoke; cd /workspace/deb-smoke; ar x '%@' && tar xzf data.tar.gz && cat usr/share/dylix/smoke.txt; test ! -e /workspace/MAINTAINER_RAN && echo NO_MAINTAINER_SCRIPT",r[@"path"]];
  [[TFAIISHRuntime shared]execute:command session:@"proof-one" timeout:600 output:nil completion:^(NSDictionary *out,NSError *error){
   [self.results addObject:@{@"test":@"deb_unpack_in_linux",@"passed":@(!error&&[out[@"output"] containsString:@"DEB_PAYLOAD_OK"]&&[out[@"output"] containsString:@"NO_MAINTAINER_SCRIPT"]),@"result":out?:@{},@"error":error.localizedDescription?:@""}];[self save];
   NSString *link=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createSymbolicLinkAtPath:link withDestinationPath:fixture.path error:nil];
   [[TFAIISHRuntime shared]importFile:[NSURL fileURLWithPath:link] name:@"link.deb" session:@"proof-one" completion:^(NSDictionary *unused,NSError *rejected){
    [NSFileManager.defaultManager removeItemAtPath:link error:nil];[self.results addObject:@{@"test":@"reject_import_symlink",@"passed":@(rejected!=nil&&unused==nil)}];[self save];[self exportTest];
   }];
  }];
 }];
}
- (void)exportTest{
 [TFAIISHRuntime.shared exportFile:@"/workspace/persist.txt" session:@"proof-one" completion:^(NSDictionary *r,NSError *e){
  NSURL *url=r?TFAIISHExportURL(r,@"proof-one"):nil;NSString *text=url?[NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil]:nil;
  [self.results addObject:@{@"test":@"guest_export_roundtrip",@"passed":@(!e&&[text isEqual:@"persisted"]&&!r[@"localPath"]&&TFAIISHExportURL(r,@"proof-two")==nil),@"error":e.localizedDescription?:@""}];
  if(url)[NSFileManager.defaultManager removeItemAtURL:url.URLByDeletingLastPathComponent error:nil];[self save];[self rejectExport:0];
 }];
}
- (void)rejectExport:(NSUInteger)i{
 NSArray *paths=@[@"/../../etc/passwd",@"/workspace",@"/tmp/sh"];
 if(i==paths.count){[self managedTests];return;}
 [TFAIISHRuntime.shared exportFile:paths[i] session:@"proof-two" completion:^(NSDictionary *r,NSError *e){[self.results addObject:@{@"test":[@"reject_export_" stringByAppendingString:paths[i]],@"passed":@(e!=nil&&r==nil)}];[self save];[self rejectExport:i+1];}];
}
- (void)record:(NSString *)name passed:(BOOL)passed detail:(id)detail{[self.results addObject:@{@"test":name,@"passed":@(passed),@"detail":detail?:@{}}];[self save];}
- (void)managedTests{
 [TFAIISHRuntime.shared performProcess:@"start" arguments:@{@"command":@"exec /bin/sh -i"} session:@"proof-one" completion:^(NSDictionary *r,NSError *e){NSString *identifier=r[@"process_id"];self.processID=identifier;[self record:@"persistent_process_start" passed:!e&&identifier.length&&[r[@"running"] boolValue] detail:e.localizedDescription];if(!identifier){[self cancelTest];return;}
  [TFAIISHRuntime.shared performProcess:@"write" arguments:@{@"process_id":identifier,@"input":@"printf 'PROCESS_ROUNDTRIP_OK\\n'\n"} session:@"proof-one" completion:^(NSDictionary *w,NSError *we){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
   [TFAIISHRuntime.shared performProcess:@"read" arguments:@{@"process_id":identifier,@"offset":@0} session:@"proof-one" completion:^(NSDictionary *read,NSError *re){[self record:@"persistent_process_write_read" passed:!we&&!re&&[read[@"output"] containsString:@"PROCESS_ROUNDTRIP_OK"] detail:read];
    [TFAIISHRuntime.shared performProcess:@"read" arguments:@{@"process_id":identifier,@"offset":read[@"next_offset"]?:@0} session:@"proof-one" completion:^(NSDictionary *next,NSError *ne){[self record:@"process_incremental_cursor" passed:!ne&&![next[@"output"] length] detail:next];[self rejectForeignProcess:0];}];
   }];
  });}];
 }];
}
- (void)rejectForeignProcess:(NSUInteger)i{
 NSArray *ops=@[@"read",@"write",@"stop",@"resize"];
 if(i==ops.count){[self resizeManaged];return;}
 [TFAIISHRuntime.shared performProcess:ops[i] arguments:@{@"process_id":self.processID,@"input":@"echo BAD\n",@"columns":@100,@"rows":@30} session:@"proof-two" completion:^(NSDictionary *r,NSError *e){[self record:[@"process_cross_session_" stringByAppendingString:ops[i]] passed:!r&&e!=nil detail:e.localizedDescription];[self rejectForeignProcess:i+1];}];
}
- (void)resizeManaged{
 [TFAIISHRuntime.shared performProcess:@"resize" arguments:@{@"process_id":self.processID,@"columns":@110,@"rows":@32} session:@"proof-one" completion:^(NSDictionary *r,NSError *e){
  [TFAIISHRuntime.shared performProcess:@"write" arguments:@{@"process_id":self.processID,@"input":@"stty size\n"} session:@"proof-one" completion:^(NSDictionary *w,NSError *we){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[TFAIISHRuntime.shared performProcess:@"read" arguments:@{@"process_id":self.processID} session:@"proof-one" completion:^(NSDictionary *read,NSError *re){[self record:@"persistent_process_resize" passed:!e&&!we&&!re&&[read[@"output"] containsString:@"32 110"] detail:read];[self overflowManaged];}];});}];
 }];
}
- (void)overflowManaged{
 [NSUserDefaults.standardUserDefaults setInteger:256*1024 forKey:@"DylixISHProcessOutputLimit"];
 [TFAIISHRuntime.shared performProcess:@"write" arguments:@{@"process_id":self.processID,@"input":@"yes rollover | head -c 400000; echo PROCESS_TAIL_END\n"} session:@"proof-one" completion:^(NSDictionary *w,NSError *e){[self verifyOverflowManaged:0];}];
}
- (void)verifyOverflowManaged:(NSUInteger)attempt{
 [TFAIISHRuntime.shared performProcess:@"read" arguments:@{@"process_id":self.processID,@"offset":@0,@"max_bytes":@16384} session:@"proof-one" completion:^(NSDictionary *read,NSError *error){
  if(!error&&[read[@"bytes_produced"] unsignedLongLongValue]<400000&&attempt<80){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,250*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self verifyOverflowManaged:attempt+1];});return;}
  [self record:@"persistent_process_bounded_ring" passed:!error&&[read[@"earliest_offset"] unsignedLongLongValue]>0&&[read[@"missed_bytes"] unsignedLongLongValue]==0&&[read[@"spool_bytes"] unsignedLongLongValue]>256*1024&&[read[@"next_offset"] unsignedLongLongValue]>0&&[read[@"output"] lengthOfBytesUsingEncoding:NSUTF8StringEncoding]<=16384 detail:@{@"bytes":read[@"bytes_produced"]?:@0,@"missed":read[@"missed_bytes"]?:@0,@"spool":read[@"spool_bytes"]?:@0,@"earliest":read[@"earliest_offset"]?:@0}];
  [NSUserDefaults.standardUserDefaults removeObjectForKey:@"DylixISHProcessOutputLimit"];[self unicodeProcessRead];
 }];
}
- (void)unicodeProcessRead{
 [TFAIISHRuntime.shared performProcess:@"start" arguments:@{@"command":@"printf '中文'; sleep 2",@"timeout":@1} session:@"proof-one" completion:^(NSDictionary *started,NSError *e){NSString *identifier=started[@"process_id"];if(!identifier){[self record:@"unicode_process_start" passed:NO detail:e.localizedDescription];[self servePreview];return;}
  [TFAIISHRuntime.shared performProcess:@"read" arguments:@{@"process_id":identifier,@"offset":@0,@"max_bytes":@1,@"wait_seconds":@0.5} session:@"proof-one" completion:^(NSDictionary *r,NSError *re){
   // Read after output arrives to force a UTF8 byte split; cursor must always advance.
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,1500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[TFAIISHRuntime.shared performProcess:@"read" arguments:@{@"process_id":identifier,@"offset":@0,@"max_bytes":@1} session:@"proof-one" completion:^(NSDictionary *chunk,NSError *ce){NSData *raw=[[NSData alloc]initWithBase64EncodedString:chunk[@"output"] options:0];[self record:@"process_utf8_split_advances_cursor" passed:!ce&&[chunk[@"encoding"] isEqual:@"base64"]&&raw.length==1&&[chunk[@"next_offset"] intValue]==1 detail:chunk];[self record:@"managed_process_timeout" passed:![chunk[@"running"] boolValue]&&[chunk[@"state"] isEqual:@"timed_out"] detail:nil];[self longPollTest];}];});
  }];
 }];
}
- (void)longPollTest{
 [TFAIISHRuntime.shared performProcess:@"start" arguments:@{@"command":@"sleep 1; echo LONG_POLL_OK"} session:@"proof-one" completion:^(NSDictionary *r,NSError *e){if(!r){[self record:@"process_long_poll" passed:NO detail:e.localizedDescription];[self servePreview];return;}NSTimeInterval start=NSProcessInfo.processInfo.systemUptime;
  [TFAIISHRuntime.shared performProcess:@"read" arguments:@{@"process_id":r[@"process_id"],@"wait_seconds":@5} session:@"proof-one" completion:^(NSDictionary *read,NSError *failure){[self record:@"process_long_poll" passed:!failure&&[read[@"output"] containsString:@"LONG_POLL_OK"]&&NSProcessInfo.processInfo.systemUptime-start<4 detail:read?:failure.localizedDescription];[self servePreview];}];
 }];
}
- (void)installPreviewRuntime{
 [TFAIISHRuntime.shared installDeveloperTools:@"proof-one" completion:^(NSDictionary *r,NSError *e){[self record:@"offline_installer_started" passed:!e&&[r[@"process_id"] length] detail:r?:e.localizedDescription];if(!r){[self stopManaged];return;}self.installOutput=[NSMutableData new];self.installOffset=0;[self awaitInstall:r[@"process_id"] attempt:0];}];
}
- (void)awaitInstall:(NSString *)identifier attempt:(NSUInteger)attempt{
 [TFAIISHRuntime.shared performProcess:@"read" arguments:@{@"process_id":identifier,@"offset":@(self.installOffset),@"max_bytes":@16384,@"wait_seconds":@1} session:@"proof-one" completion:^(NSDictionary *r,NSError *e){
  NSData *chunk=[r[@"encoding"] isEqual:@"base64"]?[[NSData alloc]initWithBase64EncodedString:r[@"output"] options:0]:[r[@"output"] dataUsingEncoding:NSUTF8StringEncoding];if(chunk)[self.installOutput appendData:chunk];self.installOffset=[r[@"next_offset"] unsignedLongLongValue];
  if(!e&&([r[@"running"] boolValue]||[r[@"has_more"] boolValue])&&attempt<540){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{[self awaitInstall:identifier attempt:attempt+1];});return;}
  NSString *output=[[NSString alloc]initWithData:self.installOutput encoding:NSUTF8StringEncoding];[self record:@"official_signed_offline_install" passed:!e&&![r[@"running"] boolValue]&&[r[@"exit_code"] intValue]==0&&[output containsString:@"DYLIX_DEVELOPER_TOOLS_INSTALLED"] detail:e.localizedDescription?:@{@"exit_code":r[@"exit_code"]?:@(-1),@"output":output?:@"invalid UTF8"}];[self fileTests];
 }];
}
- (void)servePreview{
 NSString *command=@"mkdir -p /workspace/web-proof; printf '%s' '<html><head><title>Dylix real preview</title></head><body><span id=\"status\">STATIC_MARKER</span><input id=\"value\"><button onclick=\"document.getElementById(&quot;result&quot;).innerText=&quot;CLICK_OK &quot;+document.getElementById(&quot;value&quot;).value\">Test</button><p id=\"result\"></p><script>setTimeout(()=>document.getElementById(\"status\").innerText=\"JS_PREVIEW_OK\",200)</script></body></html>' > /workspace/web-proof/index.html; exec python3 -u -m http.server 0 --bind 127.0.0.1 --directory /workspace/web-proof";
 [TFAIISHRuntime.shared performProcess:@"start" arguments:@{@"command":command} session:@"proof-one" completion:^(NSDictionary *r,NSError *e){self.serverID=r[@"process_id"];[self record:@"http_server_process_start" passed:!e&&self.serverID.length detail:e.localizedDescription];[self waitForServer:0];}];
}
- (void)waitForServer:(NSUInteger)attempt{
 [TFAIISHRuntime.shared preview:self.serverID port:0 path:@"/" session:@"proof-one" completion:^(NSDictionary *info,NSError *e){if(!info&&attempt<30){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,200*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self waitForServer:attempt+1];});return;}
  [self record:@"real_listener_port_discovery" passed:!e&&[info[@"port"] integerValue]>0 detail:info?:e.localizedDescription];if(!info){[self stopManaged];return;}self.previewInfo=info;
  BOOL foreign=[TFAIISHRuntime.shared ownsPreviewURL:[NSURL URLWithString:info[@"url"]] process:self.serverID session:@"proof-two"];
  BOOL wrongPort=[TFAIISHRuntime.shared ownsPreviewURL:[NSURL URLWithString:@"http://127.0.0.1:1/"] process:self.serverID session:@"proof-one"];
  [self record:@"preview_ownership_enforced" passed:!foreign&&!wrongPort detail:nil];
  TFAIISHReadPreview(info,@"proof-one",^(NSDictionary *page,NSError *failure){[self record:@"real_wkwebview_javascript_preview" passed:!failure&&[page[@"text"] containsString:@"JS_PREVIEW_OK"]&&[page[@"javascriptRendered"] boolValue] detail:page?:failure.localizedDescription];[self browserTests:page?:@{}];});
 }];
}
- (void)showPreview{
 UIViewController *vc=TFAIISHPreviewController(self.previewInfo,@"proof-one");self.window.rootViewController=[[UINavigationController alloc]initWithRootViewController:vc];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),dispatch_get_main_queue(),^{WKWebView *web=nil;for(UIView *v in vc.view.subviews)if([v isKindOfClass:WKWebView.class])web=(id)v;
  [web evaluateJavaScript:@"document.body.innerText" completionHandler:^(id text,NSError *e){[self record:@"visible_local_preview_ui" passed:!e&&[text containsString:@"JS_PREVIEW_OK"] detail:text];[web takeSnapshotWithConfiguration:nil completionHandler:^(UIImage *image,NSError *error){[self record:@"local_preview_screenshot" passed:image!=nil&&!error detail:error.localizedDescription];if(image)[UIImagePNGRepresentation(image) writeToFile:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"local-web-preview.png"] atomically:YES];[self stopManaged];}];}];
 });
}
- (void)stopManaged{
 [TFAIISHRuntime.shared performProcess:@"stop" arguments:@{@"process_id":self.serverID?:@"missing"} session:@"proof-one" completion:^(NSDictionary *r,NSError *e){BOOL owned=self.previewInfo?[TFAIISHRuntime.shared ownsPreviewURL:[NSURL URLWithString:self.previewInfo[@"url"]] process:self.serverID session:@"proof-one"]:NO;[self record:@"server_stop_revokes_preview" passed:!e&&![r[@"running"] boolValue]&&!owned detail:r?:e.localizedDescription];
  [TFAIISHRuntime.shared performProcess:@"stop" arguments:@{@"process_id":self.processID} session:@"proof-one" completion:^(NSDictionary *r,NSError *e){[self record:@"managed_process_stop" passed:!e&&![r[@"running"] boolValue]&&[r[@"state"] isEqual:@"cancelled"] detail:r];
   [TFAIISHRuntime.shared performProcess:@"write" arguments:@{@"process_id":self.processID,@"input":@"echo BAD\n"} session:@"proof-one" completion:^(NSDictionary *w,NSError *we){[self record:@"exited_process_rejects_input" passed:!w&&we!=nil detail:we.localizedDescription];[self packageTools];}];
  }];
 }];
}
- (void)packageTools{
 if(![NSProcessInfo.processInfo.arguments containsObject:@"--test-packages"]){[self networkTest];return;}
 [TFAIISHRuntime.shared execute:@"python3 -c 'import json,hashlib;print(\"PYTHON_REAL_OK\",json.dumps({\"ok\":True}))' && node -e 'console.log(\"NODE_REAL_OK\",process.arch)' && npm --version && git --version && curl --version | head -1 && file /bin/busybox" session:@"proof-one" timeout:600 output:nil completion:^(NSDictionary *r,NSError *e){[self record:@"python_node_and_developer_packages" passed:!e&&[r[@"exit_code"] intValue]==0&&[r[@"output"] containsString:@"PYTHON_REAL_OK"]&&[r[@"output"] containsString:@"NODE_REAL_OK"] detail:r?:e.localizedDescription];[self machOTools228];}];
}

- (void)machOTools228{
 [TFAIISHRuntime.shared importFile:[NSBundle.mainBundle URLForResource:@"reverse-fixture" withExtension:@"dylib"] name:@"fixture-arm64.dylib" session:@"proof-one" completion:^(NSDictionary *first,NSError *error){
 [TFAIISHRuntime.shared importFile:[NSBundle.mainBundle URLForResource:@"reverse-arm64e" withExtension:@"dylib"] name:@"fixture-arm64e.dylib" session:@"proof-one" completion:^(NSDictionary *second,NSError *error){
 [TFAIISHRuntime.shared importFile:[NSBundle.mainBundle URLForResource:@"MachOSignatureVerify" withExtension:@"py"] name:@"verify-signature.py" session:@"proof-one" completion:^(NSDictionary *verify,NSError *error){
 if(!first||!second||!verify){[self record:@"macho228_fixtures" passed:NO detail:error.localizedDescription];[self networkTest];return;}
 NSString *command=[NSString stringWithFormat:@"set -e; for t in dpkg-deb lipo otool ldid nm; do command -v \"$t\"; done; lipo -create '%@' '%@' -output /workspace/macho228-fat.dylib; lipo -archs /workspace/macho228-fat.dylib; lipo /workspace/macho228-fat.dylib -thin arm64e -output /workspace/macho228-signed.dylib; otool -hv /workspace/macho228-signed.dylib; nm -g /workspace/macho228-signed.dylib | grep dylix_fixture_add; ldid -r /workspace/macho228-signed.dylib; python3 '%@' /workspace/macho228-signed.dylib --unsigned; ldid -S /workspace/macho228-signed.dylib; python3 '%@' /workspace/macho228-signed.dylib; dpkg-deb --version | head -1; mkdir -p /workspace/deb-smoke/DEBIAN; tar -xzf /workspace/deb-smoke/control.tar.gz -C /workspace/deb-smoke/DEBIAN; dpkg-deb -b /workspace/deb-smoke /workspace/macho228-test.deb; dpkg-deb -x /workspace/macho228-test.deb /workspace/macho228-deb; cat /workspace/macho228-deb/usr/share/dylix/smoke.txt; test ! -e /workspace/MAINTAINER_RAN; python3 '%@' --vfs; printf 'MACHO228_ALL_OK\\n'",first[@"path"],second[@"path"],verify[@"path"],verify[@"path"],verify[@"path"]];
 [TFAIISHRuntime.shared execute:command session:@"proof-one" timeout:600 output:nil completion:^(NSDictionary *r,NSError *e){NSString *text=r[@"output"];[self record:@"macho228_lipo_otool_nm_ldid_dpkg_real_guest" passed:!e&&[r[@"exit_code"] intValue]==0&&[text containsString:@"CODEDIRECTORY_HASHES_VERIFIED"]&&[text containsString:@"arm64e"]&&[text containsString:@"MACHO228_ALL_OK"] detail:r?:e.localizedDescription];[self networkTest];}];
 }];}];}];
}

- (void)networkTest{
 if(![NSProcessInfo.processInfo.arguments containsObject:@"--test-network"]){[self cancelTest];return;}
 NSString *command=@"python3 -c 'import socket;print(\"DNS_REAL_OK\",socket.getaddrinfo(\"dl-cdn.alpinelinux.org\",443)[0][4][0])' && curl -fIsS --connect-timeout 5 --max-time 15 https://dl-cdn.alpinelinux.org/alpine/v3.21/main/aarch64/APKINDEX.tar.gz > /workspace/https-proof.txt && grep -q 200 /workspace/https-proof.txt && echo HTTPS_REAL_OK";
 [TFAIISHRuntime.shared execute:command session:@"proof-one" timeout:30 output:nil completion:^(NSDictionary *r,NSError *e){[self record:@"real_dns_and_https" passed:!e&&[r[@"exit_code"] intValue]==0&&[r[@"output"] containsString:@"DNS_REAL_OK"]&&[r[@"output"] containsString:@"HTTPS_REAL_OK"] detail:r?:e.localizedDescription];[self cancelTest];}];
}

- (void)cancelTest{
 [[TFAIISHRuntime shared]execute:@"echo CANCEL_STARTED; sleep 10; echo BAD_CANCEL" session:@"proof-one" timeout:20 output:nil completion:^(NSDictionary *r,NSError *e){
  [self.results addObject:@{@"test":@"explicit_cancel",@"passed":@(!e&&[r[@"cancelled"] boolValue]&&![r[@"output"] containsString:@"BAD_CANCEL"]),@"result":r?:@{},@"error":e.localizedDescription?:@""}];[self save];[self managedUI];
 }];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{[TFAIISHRuntime.shared cancelCommands:@"proof-one"];});
}
- (void)managedUI{
 [TFAIISHRuntime.shared performProcess:@"start" arguments:@{@"command":@"exec /bin/sh -i"} session:@"proof-one" completion:^(NSDictionary *r,NSError *failure){NSString *identifier=r[@"process_id"];if(!identifier){[self record:@"managed_terminal_ui_roundtrip" passed:NO detail:failure.localizedDescription];[self interactive];return;}
  UIViewController *page=TFAIISHProcessController(@"proof-one",identifier);self.window.rootViewController=[[UINavigationController alloc]initWithRootViewController:page];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{WKWebView *web=nil;for(UIView *v in page.view.subviews)if([v isKindOfClass:WKWebView.class])web=(id)v;
   [web evaluateJavaScript:@"send('input', \"printf 'MANAGED_UI_OK\\\\n'\\r\")" completionHandler:^(id value,NSError *error){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{
    [web evaluateJavaScript:@"Array.from({length:terminal.buffer.active.length},(_,i)=>terminal.buffer.active.getLine(i).translateToString(true)).includes('MANAGED_UI_OK')" completionHandler:^(id ok,NSError *e){[self record:@"managed_terminal_ui_roundtrip" passed:[ok boolValue]&&!e&&!error detail:e.localizedDescription?:error.localizedDescription];
     [TFAIISHRuntime.shared performProcess:@"stop" arguments:@{@"process_id":identifier} session:@"proof-one" completion:^(NSDictionary *stopped,NSError *se){[self interactive];}];
    }];
   });}];
  });
 }];
}
- (void)interactive{
 __block NSMutableData *bytes=[NSMutableData new];
 id observer=[NSNotificationCenter.defaultCenter addObserverForName:TFAIISHTerminalOutput object:@"proof-one" queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){[bytes appendData:n.userInfo[@"data"]];}];
 [[TFAIISHRuntime shared]openTerminal:@"proof-one" columns:80 rows:24 completion:^(NSError *e){
  [[TFAIISHRuntime shared]writeTerminal:@"proof-one" data:[@"printf 'PTY_INTERACTIVE_OK\\n'\r" dataUsingEncoding:NSUTF8StringEncoding]];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,4*NSEC_PER_SEC),dispatch_get_main_queue(),^{
   NSString *output=[[NSString alloc]initWithData:bytes encoding:NSUTF8StringEncoding]?:@"";
   BOOL ok=!e&&[output containsString:@"PTY_INTERACTIVE_OK"];
   NSRegularExpression *prompt=[NSRegularExpression regularExpressionWithPattern:@"root@[^\\r\\n: ]+:/workspace[^\\r\\n]* # " options:0 error:nil];
   [self.results addObject:@{@"test":@"interactive_identity_prompt",@"passed":@(!e&&[prompt firstMatchInString:output options:0 range:NSMakeRange(0,output.length)]!=nil),@"output":output}];
   [self.results addObject:@{@"test":@"interactive_pty",@"passed":@(ok),@"output":output,@"error":e.localizedDescription?:@""}];
   [NSNotificationCenter.defaultCenter removeObserver:observer];[self save];[self render];
  });
 }];
}
- (void)verifyToolbar:(WKWebView *)web page:(UIViewController *)page completion:(void (^)(void))completion{
 NSMutableArray<UIView *> *queue=[NSMutableArray arrayWithObject:page.view];NSUInteger count=0;BOOL touch=YES;
 while(queue.count){UIView *v=queue.lastObject;[queue removeLastObject];[queue addObjectsFromArray:v.subviews];if([v.accessibilityIdentifier hasPrefix:@"terminal.key."]){count++;touch&=v.bounds.size.height>=44&&v.bounds.size.width>=44;}}
 [self.results addObject:@{@"test":@"toolbar_native_keys_and_touch_targets",@"passed":@(count==28&&touch),@"count":@(count)}];
 [web evaluateJavaScript:@"(()=>{const original=send,got=[];send=(t,v)=>{if(t==='input')got.push(v);};try{const cases=[['escape','\\x1b'],['tab','\\t'],['enter','\\r'],['up','\\x1b[A'],['down','\\x1b[B'],['left','\\x1b[D'],['right','\\x1b[C'],['home','\\x1b[H'],['end','\\x1b[F'],['pageUp','\\x1b[5~'],['pageDown','\\x1b[6~'],['delete','\\x1b[3~'],['backspace','\\x7f'],['interrupt','\\x03'],['eof','\\x04'],['suspend','\\x1a'],['clear','\\x0c'],['/','/'],['|','|']];for(const [k,v] of cases){dylixKey(k);if(got.pop()!==v)throw Error(k);}dylixKey('ctrl');input('c');if(got.pop()!=='\\x03'||ctrl)throw Error('ctrl');dylixKey('alt');input('x');if(got.pop()!=='\\x1bx'||alt)throw Error('alt');dylixKey('ctrl');dylixKey('left');if(got.pop()!=='\\x1b[1;5D')throw Error('ctrl-left');dylixKey('alt');dylixKey('pageUp');if(got.pop()!=='\\x1b[5;3~')throw Error('alt-pageup');dylixKey('ctrl');dylixPaste('safe text');if(got.pop()!=='safe text'||ctrl||alt)throw Error('paste');return true;}finally{resetModifiers();send=original;}})()" completionHandler:^(id result,NSError *error){[self.results addObject:@{@"test":@"toolbar_webkit_control_sequences",@"passed":@([result boolValue]&&!error),@"error":error.localizedDescription?:@""}];completion();}];
}
- (void)render{
 UIViewController *page=TFAIISHTerminalController(@"proof-one");self.window.rootViewController=[[UINavigationController alloc]initWithRootViewController:page];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),dispatch_get_main_queue(),^{
  WKWebView *web=nil;for(UIView *v in page.view.subviews)if([v isKindOfClass:WKWebView.class])web=(id)v;
  [web evaluateJavaScript:@"send('input', \"printf 'RENDERED_PTY_OK\\\\n'\\r\")" completionHandler:^(id r,NSError *error){
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),dispatch_get_main_queue(),^{
    [web evaluateJavaScript:@"Array.from({length:terminal.buffer.active.length},(_,i)=>terminal.buffer.active.getLine(i).translateToString(true)).includes('RENDERED_PTY_OK')" completionHandler:^(id ok,NSError *e){
     [self verifyToolbar:web page:page completion:^{[self.results addObject:@{@"test":@"terminal_webview_roundtrip",@"passed":@([ok boolValue]&&!e&&!error&&[[TFAIISHRuntime.shared status:@"proof-one"][@"terminalRunning"] boolValue]),@"error":e.localizedDescription?:error.localizedDescription?:@""}];[self save];NSLog(@"ISH_TEST_FINISHED %@",self.results);}];
    }];
   });
  }];
 });
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(ISHProof.class));}}
