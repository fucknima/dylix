#import <UIKit/UIKit.h>
#import "FLEXDylixChatViewController.h"
#import "FLEXDylixStatusWindow.h"
#import "FLEXDylixRuntime.h"
#import "FLEXDylixPreferences.h"
#import "FLEXDylixConnection.h"
#import <errno.h>
#import "FLEXGlobalsEntry.h"
#import "FLEXDylixTouchDriver.h"
#import "x/ClassDump/UCClassSearchViewController.h"
#import "x/ClassDump/UCClassDumpTool.h"

// Runs the production chat/runtime in UIKit. Only the Dylix HTTP transport and
// unrelated FLEX services are fixtures; this is not a target-App device test.
static UIWindow *HostWindow;
static NSMutableArray *Checks;
static void Check(BOOL ok, NSString *name) {
 [Checks addObject:@{@"name":name,@"passed":@(ok)}];
 if(!ok)NSLog(@"FAIL %@",name);
}
static BOOL Await(int (^condition)(void), NSTimeInterval seconds) {
 NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];
 while(!condition()&&end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.02]];
 return condition();
}
@interface FLEXUtility : NSObject @end
@implementation FLEXUtility
+ (UIWindow *)appKeyWindow {return HostWindow;}
+ (UIViewController *)topViewControllerInWindow:(UIWindow *)window {
 UIViewController *c=window.rootViewController;
 for(int i=0;i<15;i++) {UIViewController *n=c.presentedViewController;
  if(!n&&[c isKindOfClass:UINavigationController.class])n=((UINavigationController *)c).visibleViewController;
  if(!n)break;c=n;
 }return c;
}
@end
@interface FLEXManager : NSObject
@property UIWindow *explorerWindow;
@property NSMutableArray *userGlobalEntries;
@end
@implementation FLEXManager
+ (instancetype)sharedManager {static FLEXManager *m;static dispatch_once_t once;dispatch_once(&once,^{m=[self new];m.userGlobalEntries=[NSMutableArray new];m.explorerWindow=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];m.explorerWindow.windowLevel=UIWindowLevelAlert-1;m.explorerWindow.rootViewController=[UIViewController new];});return m;}
- (BOOL)isHidden {return self.explorerWindow.hidden;}
- (void)showExplorer {self.explorerWindow.hidden=NO;}
- (void)hideExplorer {self.explorerWindow.hidden=YES;}
- (void)dismissAnyPresentedTools:(dispatch_block_t)done {UIViewController *root=self.explorerWindow.rootViewController;if(root.presentedViewController)[root dismissViewControllerAnimated:YES completion:done];else if(done)done();}
- (void)presentTool:(UINavigationController *(^)(void))future completion:(dispatch_block_t)done {[self showExplorer];[self.explorerWindow.rootViewController presentViewController:future() animated:YES completion:done];}
- (void)presentEmbeddedTool:(UIViewController *)controller completion:(void(^)(UINavigationController *))done {UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:controller];nav.modalPresentationStyle=UIModalPresentationFullScreen;[self presentTool:^{return nav;} completion:^{if(done)done(nav);}];}
@end
@interface FLEXNetworkRecorder : NSObject @end
@implementation FLEXNetworkRecorder
+ (instancetype)defaultRecorder {return nil;}
@end
@interface FLEXNetworkObserver : NSObject @end
@implementation FLEXNetworkObserver
+ (BOOL)isEnabled {return NO;}
+ (void)setEnabled:(BOOL)enabled {}
@end
NSString *const kFLEXKeychainAccountKey=@"account";
NSString *const kFLEXKeychainWhereKey=@"service";
NSString *const kFLEXKeychainGroupKey=@"group";
NSString *const kFLEXKeychainClassKey=@"class";
@interface FLEXKeychain : NSObject @end
@implementation FLEXKeychain
+ (NSArray *)allAccounts:(NSError **)error {return @[];}
@end
@interface FLEXLiveObjectsController : UITableViewController <UISearchBarDelegate>
@property NSUInteger searches;
@end
@implementation FLEXLiveObjectsController
- (void)viewDidLoad {[super viewDidLoad];self.title=@"Runtime fixture";self.navigationItem.searchController=[[UISearchController alloc]initWithSearchResultsController:nil];self.navigationItem.searchController.searchBar.delegate=self;}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {return 40;}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {UITableViewCell *c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];c.textLabel.text=[NSString stringWithFormat:@"Fixture class %ld",(long)path.row];return c;}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {UIViewController *c=[UIViewController new];c.title=@"Object detail";c.view.backgroundColor=UIColor.systemBackgroundColor;[self.navigationController pushViewController:c animated:NO];}
- (void)searchBar:(UISearchBar *)bar textDidChange:(NSString *)text {self.searches++;}
@end
@interface FLEXGlobalsViewController : NSObject @end
@interface UCClassSearchViewController (SmokeTable) <UITableViewDataSource,UITableViewDelegate>
@end
@implementation UCClassSearchViewController
+ (instancetype)searchViewControllerWithMode:(UCClassSearchMode)mode {UCClassSearchViewController *c=[self new];c.searchMode=mode;return c;}
- (void)viewDidLoad {[super viewDidLoad];UITableView *table=[[UITableView alloc]initWithFrame:self.view.bounds style:UITableViewStylePlain];table.dataSource=self;table.delegate=self;[self.view addSubview:table];self.title=@"Extension fixture";}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {return 4;}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {UITableViewCell *cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];cell.textLabel.text=@"UIView header fixture";return cell;}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {UIViewController *detail=[UIViewController new];detail.title=@"Extension detail fixture";detail.view.backgroundColor=UIColor.whiteColor;[self.navigationController pushViewController:detail animated:NO];}
@end
@implementation UCClassDumpTool
+ (NSString *)headerForClassName:(NSString *)name {return @"@interface UIView : UIResponder\n@property CGRect frame;\n@end\n";}
@end
@implementation FLEXGlobalsViewController
+ (FLEXGlobalsEntry *)globalsEntryForRow:(FLEXGlobalsRow)row {return [FLEXGlobalsEntry entryWithNameFuture:^{return [NSString stringWithFormat:@"Native fixture %lu",(unsigned long)row];} viewControllerFuture:^{return [FLEXLiveObjectsController new];}];}
@end
@interface FLEXDylixChatViewController (Smoke)
- (void)finishAgentCommand:(NSDictionary *)command allowed:(BOOL)allowed;
- (void)stopAgentTapped;
- (void)closeTapped;
- (void)applyModelSelection:(NSDictionary *)connection;
- (void)sendTapped;
- (void)executeAgentCommand:(NSDictionary *)command;
- (void)updateTaskFromJob:(NSDictionary *)job;
- (void)showConnectionState:(NSUInteger)state;
- (void)refreshAgentStatus;
- (void)workspace:(NSString *)action arguments:(NSDictionary *)arguments completion:(void(^)(NSDictionary *,NSError *))done;
@end
@interface SmokeChat : FLEXDylixChatViewController
@property NSMutableDictionary *replies;
@property NSUInteger polls, cancels;
@property BOOL routingFixture;
@property BOOL restorationFixture;
@property NSMutableArray *restoreActions;
@property NSDictionary *lastAIArguments;
@property NSMutableDictionary *grants;
@end
@implementation SmokeChat
- (void)workspace:(NSString *)action arguments:(NSDictionary *)arguments completion:(void(^)(NSDictionary *,NSError *))done {
 if(self.restorationFixture){
  [self.restoreActions addObject:action];
  if([action isEqual:@"projects"]){done(@{@"projects":@[@{@"id":@"persist-project",@"name":@"Saved project"}]},nil);return;}
  if([action isEqual:@"ai_connections"]){done(@{@"connections":@[@{@"id":@"persist-connection",@"model":@"gpt-6.1-sol"}]},nil);return;}
  if([action isEqual:@"ai_read"]){done(@{@"id":@"persist-session",@"title":@"Saved conversation",@"messages":@[@{@"role":@"assistant",@"content":@"History from Dylix"}]},nil);return;}
 }
 if(self.routingFixture){
  if([action isEqual:@"flex_publish"]){done(@{},nil);return;}
  if([action isEqual:@"flex_tool_permission"]){done(@{@"enabled":@([self.grants[arguments[@"sessionID"]] boolValue])},nil);return;}
 }
 [super workspace:action arguments:arguments completion:done];
}
- (void)request:(NSString *)path body:(NSDictionary *)body completion:(void(^)(NSDictionary *,NSError *))done {
 if(self.restorationFixture&&[path isEqual:@"/api/v1/status"]){done(@{@"session":@{@"csrf":@"restored-csrf"}},nil);return;}
 if(self.routingFixture&&[path isEqual:@"/api/v1/workspace"]&&[body[@"action"] isEqual:@"ai_send"]){self.lastAIArguments=body[@"arguments"];done(@{@"id":@"model-routing-job",@"sessionID":@"test-session"},nil);return;}
 if(self.routingFixture&&[path hasSuffix:@"/get"]){done(@{@"state":@"completed",@"result":@{@"sessionID":@"test-session",@"messages":@[@{@"role":@"assistant",@"content":@"fixture reply"}]}},nil);return;}
 if([path hasSuffix:@"/next"])self.polls++;
 if([path hasSuffix:@"/cancel"])self.cancels++;
 if([path hasSuffix:@"/reply"])self.replies[body[@"id"]]=body;
 dispatch_async(dispatch_get_main_queue(),^{if(done)done(@{},nil);});
}
@end
static NSDictionary *Command(SmokeChat *chat, NSString *op, NSDictionary *args) {
 NSString *identifier=NSUUID.UUID.UUIDString;
 [chat finishAgentCommand:@{@"id":identifier,@"operation":op,@"arguments":args?:@{},@"expiresAt":@(NSDate.date.timeIntervalSince1970+30)} allowed:YES];
 Await(^{return chat.replies[identifier]!=nil&&![[chat valueForKey:@"agentReplying"] boolValue];},5);
 return chat.replies[identifier];
}
@interface HookEvidenceFixtureController : UIViewController @end
@implementation HookEvidenceFixtureController
- (void)viewDidLayoutSubviews {[super viewDidLayoutSubviews];}
@end
@interface HookEvidenceFixtureButton : UIButton @end
@implementation HookEvidenceFixtureButton
- (void)didMoveToWindow {[super didMoveToWindow];}
@end
@interface AppDelegate : UIResponder <UIApplicationDelegate,UITextFieldDelegate,UITextViewDelegate>
@property UIWindow *window;
@property NSUInteger tapped;
@property NSUInteger gestureTaps,gestureLongPresses,gesturePans,gesturePinches,gestureRotations,gestureDoubleTaps,edits,valueChanges;
@property UITextField *field;
@property UISwitch *toggle;
@property UITextView *textView;
@property NSUInteger textViewChanges;
@property UISlider *slider;
@property UISegmentedControl *segments;
@property UIStepper *stepper;
@property UIScrollView *targetScroll;
@end
@implementation AppDelegate
- (void)targetTapped {self.tapped++;}
- (void)gestureTap:(UITapGestureRecognizer *)recognizer {if(recognizer.state==UIGestureRecognizerStateRecognized)self.gestureTaps++;}
- (void)gestureLongPress:(UILongPressGestureRecognizer *)recognizer {if(recognizer.state==UIGestureRecognizerStateBegan)self.gestureLongPresses++;}
- (void)gesturePan:(UIPanGestureRecognizer *)recognizer {if(recognizer.state==UIGestureRecognizerStateChanged)self.gesturePans++;}
- (void)gesturePinch:(UIPinchGestureRecognizer *)recognizer {if(recognizer.state==UIGestureRecognizerStateChanged)self.gesturePinches++;}
- (void)gestureRotate:(UIRotationGestureRecognizer *)recognizer {if(recognizer.state==UIGestureRecognizerStateChanged)self.gestureRotations++;}
- (void)gestureDouble:(UITapGestureRecognizer *)recognizer {if(recognizer.state==UIGestureRecognizerStateRecognized)self.gestureDoubleTaps++;}
- (void)textEdited {self.edits++;}
- (void)valueChanged {self.valueChanges++;}
- (BOOL)textField:(UITextField *)field shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)text {return ![text isEqual:@"reject-fixture"];}
- (BOOL)textView:(UITextView *)view shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {return ![text isEqual:@"reject-fixture"];}
- (void)textViewDidChange:(UITextView *)view {self.textViewChanges++;}
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
 Checks=[NSMutableArray new];self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];HostWindow=self.window;
 UIViewController *root=[HookEvidenceFixtureController new];root.view.backgroundColor=UIColor.systemBackgroundColor;self.window.rootViewController=root;
 UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];button.frame=CGRectMake(30,160,240,50);[button setTitle:@"Target smoke button" forState:UIControlStateNormal];[button addTarget:self action:@selector(targetTapped) forControlEvents:UIControlEventTouchUpInside];[root.view addSubview:button];[self.window makeKeyAndVisible];
 UIView *pad=[[UIView alloc]initWithFrame:CGRectMake(30,260,300,180)];pad.backgroundColor=UIColor.systemTealColor;[root.view addSubview:pad];
 [pad addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(gestureTap:)]];
 UILongPressGestureRecognizer *hold=[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(gestureLongPress:)];hold.minimumPressDuration=.3;[pad addGestureRecognizer:hold];
 [pad addGestureRecognizer:[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(gesturePan:)]];
 [pad addGestureRecognizer:[[UIPinchGestureRecognizer alloc]initWithTarget:self action:@selector(gesturePinch:)]];
 [pad addGestureRecognizer:[[UIRotationGestureRecognizer alloc]initWithTarget:self action:@selector(gestureRotate:)]];
 UITapGestureRecognizer *doubleTap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(gestureDouble:)];doubleTap.numberOfTapsRequired=2;[pad addGestureRecognizer:doubleTap];
 self.field=[[UITextField alloc]initWithFrame:CGRectMake(30,470,240,40)];self.field.placeholder=@"Fixture input";[self.field addTarget:self action:@selector(textEdited) forControlEvents:UIControlEventEditingChanged];[root.view addSubview:self.field];
 self.toggle=[[UISwitch alloc]initWithFrame:CGRectMake(30,530,70,40)];self.toggle.accessibilityLabel=@"Fixture switch";[self.toggle addTarget:self action:@selector(valueChanged) forControlEvents:UIControlEventValueChanged];[root.view addSubview:self.toggle];
 self.field.delegate=self;
 self.textView=[[UITextView alloc]initWithFrame:CGRectMake(130,530,230,60)];self.textView.delegate=self;self.textView.accessibilityLabel=@"Fixture text view";[root.view addSubview:self.textView];
 self.slider=[[UISlider alloc]initWithFrame:CGRectMake(30,610,150,30)];self.slider.accessibilityLabel=@"Fixture slider";[self.slider addTarget:self action:@selector(valueChanged) forControlEvents:UIControlEventValueChanged];[root.view addSubview:self.slider];
 self.segments=[[UISegmentedControl alloc]initWithItems:@[@"One",@"Two"]];self.segments.frame=CGRectMake(200,610,170,30);self.segments.accessibilityLabel=@"Fixture segments";[self.segments addTarget:self action:@selector(valueChanged) forControlEvents:UIControlEventValueChanged];[root.view addSubview:self.segments];
 self.stepper=[[UIStepper alloc]initWithFrame:CGRectMake(30,660,100,30)];self.stepper.accessibilityLabel=@"Fixture stepper";[self.stepper addTarget:self action:@selector(valueChanged) forControlEvents:UIControlEventValueChanged];[root.view addSubview:self.stepper];
 self.targetScroll=[[UIScrollView alloc]initWithFrame:CGRectMake(30,720,160,100)];self.targetScroll.accessibilityLabel=@"Fixture scroll";self.targetScroll.contentInsetAdjustmentBehavior=UIScrollViewContentInsetAdjustmentNever;self.targetScroll.contentInset=UIEdgeInsetsMake(6,7,8,9);self.targetScroll.contentSize=CGSizeMake(500,300);self.targetScroll.contentOffset=CGPointMake(-7,-6);[root.view addSubview:self.targetScroll];
 // A timer permits Await to pump UIKit's main-queue completions reentrantly.
 [self performSelector:@selector(run) withObject:nil afterDelay:1];return YES;
}
- (void)writeSmokeReport {
 NSUInteger failures=0;for(NSDictionary *check in Checks)if(![check[@"passed"] boolValue])failures++;
 NSDictionary *report=@{@"checks":Checks,@"failures":@(failures),@"scope":@"production FLEX UIKit and storage, fixture HTTP transport"};
 NSString *path=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/results.json"];[NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];[[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToFile:path atomically:YES];
}
- (void)run {
 NSArray *args=NSProcessInfo.processInfo.arguments;
 if([args containsObject:@"--connection-diagnostics"]){
  SmokeChat *chat=[[SmokeChat alloc]initWithReport:@"fixture" className:@"UIWindow"];
  [chat setValue:@"192.168.20.10" forKey:@"host"];[chat setValue:@9432 forKey:@"port"];
  [chat setValue:@"fixture-private-token" forKey:@"token"];
  UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:chat];
  [FLEXManager.sharedManager presentTool:^{return nav;} completion:nil];
  Check(Await(^{return chat.viewIfLoaded.window&&!nav.isBeingPresented;},3),@"diagnostic chat presented in UIKit");
  NSError *failure=FLEXDylixConnectionError(@"192.168.20.10",9432,@"/api/v1/pair",@"connect",ECONNREFUSED,0);
  [chat performSelector:NSSelectorFromString(@"showError:") withObject:failure];
  Check(Await(^{return chat.presentedViewController!=nil&&!chat.presentedViewController.isBeingPresented;},2),@"detailed connection error alert presented");
  UIAlertController *alert=(id)chat.presentedViewController;
  Check([alert.message containsString:@"拒绝连接"]&&[alert.message containsString:@"尚未进入授权码"],@"alert distinguishes TCP refusal from invalid pairing code");
  Check([alert.actions filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"title == %@",@"复制诊断"]].count==1,@"error alert offers diagnostic copy action");
  Check([[chat valueForKey:@"token"] isEqual:@"fixture-private-token"]&&[chat valueForKey:@"lastConnectionError"]==failure,@"failure retains credentials and last diagnostic");
  [chat dismissViewControllerAnimated:NO completion:nil];Await(^{return !chat.presentedViewController;},2);
  [chat performSelector:NSSelectorFromString(@"connectTapped")];
  alert=(id)chat.presentedViewController;
  Check([alert.actions filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"title == %@",@"上次连接诊断"]].count==1,@"connection settings expose last error without repeated heartbeat dialogs");
  Check([alert.textFields.firstObject.text isEqual:@"http://192.168.20.10:9432"],@"settings retain actual custom address and port");
  [chat dismissViewControllerAnimated:NO completion:nil];Await(^{return !chat.presentedViewController;},2);
  [chat performSelector:NSSelectorFromString(@"showConnectionDiagnostic")];alert=(id)chat.presentedViewController;
  Check([alert.message containsString:@"POSIX：61"]&&[alert.message containsString:@"阶段：connect"]&&![alert.message containsString:@"fixture-private-token"],@"diagnostic details show safe stage errno and actual target");
  [self writeSmokeReport];return;
 }
 NSString *phase=nil;for(NSString *arg in args)if([arg hasPrefix:@"--preferences-"])phase=[arg substringFromIndex:14];
 if(phase){
  NSError *storageError=nil;
  if([phase isEqual:@"write"]){
   Check([FLEXDylixPreferences clearAll:&storageError],@"clear isolated fixture preferences");
   NSDictionary *state=@{@"host":@"192.168.20.10",@"port":@9432,@"authorizationCode":@"98765432",@"token":@"fixture-token",@"csrf":@"fixture-csrf",@"projectID":@"persist-project",@"projectName":@"Saved project",@"connectionID":@"persist-connection",@"modelID":@"gpt-6.1-sol",@"modelName":@"Saved model",@"sessionID":@"persist-session",@"sessionTitle":@"Saved conversation",@"messages":@[@{@"text":@"must-not-persist"}],@"permissionGranted":@YES};
   Check([FLEXDylixPreferences saveState:state error:&storageError],@"persist production connection state with real simulator Keychain");Check([[FLEXDylixPreferences loadState][@"host"] isEqual:@"192.168.20.10"],@"saved metadata reloads in the same process");
   NSDictionary *public=[NSDictionary dictionaryWithContentsOfFile:[[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"FLEXDylix"] stringByAppendingPathComponent:@"connection.plist"]];
   Check(!public[@"token"]&&!public[@"csrf"]&&!public[@"authorizationCode"]&&!public[@"messages"]&&!public[@"permissionGranted"],@"preferences contain neither credentials nor chat messages or permission grants");
  }else if([phase isEqual:@"read"]){
   NSDictionary *state=[FLEXDylixPreferences loadState];Check([state[@"host"] isEqual:@"192.168.20.10"]&&[state[@"port"] isEqual:@9432],@"IP and actual port survive process restart and covering install");
   Check([state[@"authorizationCode"] isEqual:@"98765432"]&&[state[@"token"] isEqual:@"fixture-token"],@"pairing code and token survive in Keychain");
   SmokeChat *chat=[[SmokeChat alloc]initWithReport:@"fixture" className:@"UIWindow"];chat.restorationFixture=YES;chat.restoreActions=[NSMutableArray new];[chat loadViewIfNeeded];
   Check([[chat valueForKey:@"projectID"] isEqual:@"persist-project"]&&[[chat valueForKey:@"modelID"] isEqual:@"gpt-6.1-sol"]&&[[chat valueForKey:@"sessionID"] isEqual:@"persist-session"],@"fresh production chat restores project, exact model and conversation");
   Check([[chat valueForKey:@"needsConnectionValidation"] boolValue],@"restored token requires validation before agent polling");
   [chat performSelector:NSSelectorFromString(@"resumeSavedConnection")];
   Check(![[chat valueForKey:@"needsConnectionValidation"] boolValue]&&[[chat valueForKey:@"csrf"] isEqual:@"restored-csrf"],@"restored connection validates token and refreshes CSRF");
   Check([chat.restoreActions isEqual:@[@"projects",@"ai_connections",@"ai_read"]],@"restoration verifies project and raw model then fetches real conversation history");
   Check([[[chat valueForKey:@"messages"] firstObject][@"text"] isEqual:@"History from Dylix"],@"history rehydrates from authenticated Dylix response");
  }else if([phase isEqual:@"disconnect"]){
   Check([FLEXDylixPreferences clearAuthorization:&storageError],@"explicit disconnect removes saved credentials");
  }else if([phase isEqual:@"cleared"]){
   NSDictionary *state=[FLEXDylixPreferences loadState];Check(!state[@"token"]&&!state[@"csrf"]&&!state[@"authorizationCode"],@"credentials stay cleared after restart");
   Check([state[@"host"] isEqual:@"192.168.20.10"]&&[state[@"projectID"] isEqual:@"persist-project"]&&[state[@"modelID"] isEqual:@"gpt-6.1-sol"]&&[state[@"sessionID"] isEqual:@"persist-session"],@"explicit disconnect retains endpoint and previous selections");
   [FLEXDylixPreferences clearAll:nil];
  }else Check(NO,@"recognized preferences test phase");
  [self writeSmokeReport];return;
 }
 [FLEXDylixPreferences clearAll:nil];
 SmokeChat *chat=[[SmokeChat alloc]initWithReport:@"fixture" className:@"UIWindow"];chat.replies=[NSMutableDictionary new];chat.selectedObject=HostWindow;
 [chat setValue:@"127.0.0.1" forKey:@"host"];[chat setValue:@8787 forKey:@"port"];[chat setValue:@"test-token" forKey:@"token"];[chat setValue:@"test-csrf" forKey:@"csrf"];[chat setValue:@"test-session" forKey:@"sessionID"];
 UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:chat];nav.modalPresentationStyle=UIModalPresentationFullScreen;
 [FLEXManager.sharedManager presentTool:^{return nav;} completion:nil];
 Check(Await(^{return chat.viewIfLoaded.window!=nil&&!nav.isBeingPresented;},4),@"chat appears in real UIKit");
 chat.routingFixture=YES;[chat setValue:@"fixture-project" forKey:@"projectID"];
 [chat applyModelSelection:@{@"id":@"same-connection",@"provider":@"fixture",@"model":@"gpt-6-sol"}];
 ((UITextView *)[chat valueForKey:@"input"]).text=@"model routing test";[chat sendTapped];
 Check([chat.lastAIArguments[@"model"] isEqual:@"gpt-6-sol"],@"send includes exact first model under shared connection id");
 [chat applyModelSelection:@{@"id":@"same-connection",@"provider":@"fixture",@"model":@"gpt-6.1-sol"}];
 ((UITextView *)[chat valueForKey:@"input"]).text=@"switch model test";[chat sendTapped];
 Check([chat.lastAIArguments[@"connectionID"] isEqual:@"same-connection"]&&[chat.lastAIArguments[@"model"] isEqual:@"gpt-6.1-sol"],@"switching shared connection sends newly selected raw model");
 Check([[chat valueForKey:@"sessionID"] isEqual:@"test-session"]&&[[chat valueForKey:@"projectID"] isEqual:@"fixture-project"],@"model switch preserves current conversation and project");
 SmokeChat *remembered=[[SmokeChat alloc]initWithReport:@"fixture" className:@"UIWindow"];
 Check([[remembered valueForKey:@"modelID"] isEqual:@"gpt-6.1-sol"],@"reopening chat restores raw selected model");
 [chat setValue:@YES forKey:@"busy"];[chat performSelector:NSSelectorFromString(@"modelTapped")];
 Check([[chat valueForKey:@"modelID"] isEqual:@"gpt-6.1-sol"]&&!chat.presentedViewController,@"active request blocks misleading model changes");[chat setValue:@NO forKey:@"busy"];
 
 [chat setValue:@"high" forKey:@"reasoningEffort"];((UITextView *)[chat valueForKey:@"input"]).text=@"explicit thinking";[chat sendTapped];
 Check([chat.lastAIArguments[@"reasoningEffort"] isEqual:@"high"],@"FLEX sends explicit thinking effort with selected model");
 [chat setValue:nil forKey:@"reasoningEffort"];((UITextView *)[chat valueForKey:@"input"]).text=@"inherit thinking";[chat sendTapped];
 Check(chat.lastAIArguments[@"reasoningEffort"]==nil,@"untouched FLEX effort is omitted to inherit live conversation setting");
 [chat applyModelSelection:@{@"id":@"same-connection",@"model":@"gpt-6-sol",@"efforts":@[@{@"id":@"auto",@"name":@"默认"},@{@"id":@"high",@"name":@"高"}]}];
 Check([[chat valueForKey:@"reasoningEffort"] isEqual:@"auto"]&&[[chat valueForKey:@"reasoningOptions"] count]==2,@"model changes clear incompatible thinking and expose server-advertised options");
 [chat setValue:@"high" forKey:@"reasoningEffort"];[chat applyModelSelection:@{@"id":@"same-connection",@"model":@"gpt-6-sol"}];
 Check([[chat valueForKey:@"reasoningEffort"] isEqual:@"high"],@"reselecting same model preserves explicit thinking");
 [chat applyModelSelection:@{@"id":@"same-connection",@"model":@"gpt-6.1-sol"}];
 chat.grants=[@{@"test-session":@YES} mutableCopy];
 NSString *authorized=NSUUID.UUID.UUIDString;
 [chat executeAgentCommand:@{@"id":authorized,@"operation":@"defaults_get",@"arguments":@{@"key":@"AppleLocale"},@"sessionID":@"test-session",@"expiresAt":@(NSDate.date.timeIntervalSince1970+30)}];
 Check(Await(^{return chat.replies[authorized]!=nil&&![[chat valueForKey:@"agentReplying"] boolValue];},3)&&!chat.presentedViewController,@"conversation grant executes sensitive operation without second authorization dialog");
 NSString *isolated=NSUUID.UUID.UUIDString;
 [chat executeAgentCommand:@{@"id":isolated,@"operation":@"set_network_recording",@"arguments":@{@"enabled":@YES},@"sessionID":@"other-session",@"expiresAt":@(NSDate.date.timeIntervalSince1970+30)}];
 Check(Await(^{return chat.replies[isolated]!=nil;},3)&&[chat.replies[isolated][@"error"] length]>0,@"other conversation cannot reuse current conversation grant");
 chat.routingFixture=NO;
 [chat setValue:@YES forKey:@"busy"];[chat setValue:@"job-fixture" forKey:@"jobID"];
 NSTimer *timer=[chat valueForKey:@"agentTimer"];FLEXDylixRuntime *runtime=[chat valueForKey:@"runtime"];
 NSString *logPath=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/flex-large-log.txt"];
 NSMutableString *log=[NSMutableString new];for(NSUInteger i=0;i<80000;i++)[log appendString:@"中文日志 abc\n"];[log appendString:@"LATEST-END"];
 NSData *logData=[log dataUsingEncoding:NSUTF8StringEncoding];[logData writeToFile:logPath atomically:YES];
 NSDictionary *(^ReadLog)(NSDictionary *)=^NSDictionary *(NSDictionary *args){NSMutableDictionary *a=[args mutableCopy];a[@"path"]=@"Documents/flex-large-log.txt";return [runtime execute:@"sandbox_read" arguments:a error:nil];};
 NSDictionary *page=ReadLog(@{});Check([page[@"totalBytes"] unsignedLongLongValue]==logData.length&&[page[@"bytesRead"] unsignedIntegerValue]>65536&&[page[@"has_more"] boolValue],@"large log reads 128 KiB by default instead of rejecting entire file");
 NSMutableData *reassembled=[NSMutableData new];unsigned long long cursor=0;BOOL pagesOK=YES;
 do{page=ReadLog(@{@"offset":@(cursor),@"limit":@131073});NSData *chunk=[page[@"text"] dataUsingEncoding:NSUTF8StringEncoding];if(!page||!chunk||[page[@"next_offset"] unsignedLongLongValue]<=cursor){pagesOK=NO;break;}[reassembled appendData:chunk];cursor=[page[@"next_offset"] unsignedLongLongValue];}while([page[@"has_more"] boolValue]);
 Check(pagesOK&&[reassembled isEqual:logData],@"UTF-8 byte pagination reconstructs a multi-megabyte log without loss or duplication");
 page=ReadLog(@{@"tail":@YES,@"limit":@524288});Check([page[@"text"] hasSuffix:@"LATEST-END"]&&![page[@"has_more"] boolValue]&&[page[@"bytesRead"] unsignedIntegerValue]<=524288,@"512 KiB tail reads latest log directly across UTF-8 boundary");
 Check(ReadLog(@{@"limit":@524289})==nil&&ReadLog(@{@"offset":@(-1)})==nil&&ReadLog(@{@"tail":@YES,@"offset":@0})==nil,@"invalid ranges and conflicting tail cursor are rejected");
 Check(ReadLog(@{@"offset":@(logData.length+1)})==nil,@"stale offset beyond rotated file fails explicitly");
 page=ReadLog(@{@"offset":@(logData.length)});Check([page[@"text"] isEqual:@""]&&![page[@"has_more"] boolValue],@"EOF is an explicit empty successful page");
 [@"" writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];page=ReadLog(@{});Check([page[@"text"] isEqual:@""]&&[page[@"totalBytes"] unsignedIntegerValue]==0,@"empty UTF-8 log remains readable");
 Check([runtime execute:@"sandbox_read" arguments:@{@"path":@"../outside.txt"} error:nil]==nil,@"large-file support preserves sandbox boundary");
 [NSFileManager.defaultManager removeItemAtPath:logPath error:nil];

 HookEvidenceFixtureButton *evidenceButton=[HookEvidenceFixtureButton buttonWithType:UIButtonTypeSystem];evidenceButton.frame=CGRectMake(20,40,100,30);[evidenceButton setTitle:@"Evidence fixture" forState:UIControlStateNormal];evidenceButton.accessibilityIdentifier=@"stable-fixture-button";[HostWindow.rootViewController.view addSubview:evidenceButton];
 [runtime setValue:evidenceButton forKey:@"selectedObject"];NSDictionary *evidence=[runtime execute:@"object_info" arguments:@{} error:nil][@"hookEvidence"];
 Check([evidence[@"signature"][@"class"] isEqual:@"HookEvidenceFixtureButton"]&&[evidence[@"signature"][@"accessibilityID"] isEqual:@"stable-fixture-button"],@"object_info exposes stable locator candidate without using runtime address");
 Check([evidence[@"controller"][@"class"] isEqual:@"HookEvidenceFixtureController"]&&[evidence[@"controller"][@"relationship"] isEqual:@"nearest_responder_controller"],@"hook evidence identifies nearest responder controller and labels relationship");
 BOOL ownViewMethod=NO,ownControllerMethod=NO;for(NSDictionary *m in evidence[@"viewLifecycleCandidates"])if([m[@"selector"] isEqual:@"didMoveToWindow"]&&[m[@"declaredIn"] isEqual:@"HookEvidenceFixtureButton"]&&![m[@"inherited"] boolValue])ownViewMethod=YES;
 for(NSDictionary *m in evidence[@"controller"][@"lifecycleCandidates"])if([m[@"selector"] isEqual:@"viewDidLayoutSubviews"]&&[m[@"declaredIn"] isEqual:@"HookEvidenceFixtureController"])ownControllerMethod=YES;
 Check(ownViewMethod&&ownControllerMethod,@"lifecycle candidates include exact declaring classes for custom overrides");
 Check(![evidence[@"lifecycleExecutionObserved"] boolValue]&&![evidence[@"stabilityVerified"] boolValue]&&[evidence[@"limitations"] length]>0,@"declarations never falsely claim lifecycle tracing or proven stability");
 NSDictionary *repeat=[runtime execute:@"object_info" arguments:@{} error:nil][@"hookEvidence"];Check([repeat[@"instanceID"] isEqual:evidence[@"instanceID"]]&&[repeat[@"signature"] isEqual:evidence[@"signature"]],@"repeated observations preserve instance identity and locator signature");
 [evidenceButton removeFromSuperview];[runtime setValue:HostWindow forKey:@"selectedObject"];
 NSDictionary *result=Command(chat,@"minimize_chat",@{@"surface":@"target"});
 Check([result[@"result"][@"minimized"] boolValue]&&![result[@"result"][@"chatVisible"] boolValue],@"AI minimizes its own chat after dismissal completes");
 Check(FLEXManager.sharedManager.isHidden,@"target App exposed by hiding FLEX overlay");
 Check([[chat valueForKey:@"sessionID"] isEqual:@"test-session"]&&[[chat valueForKey:@"jobID"] isEqual:@"job-fixture"],@"minimize preserves session and task");
 Check(timer==[chat valueForKey:@"agentTimer"]&&timer.valid,@"same polling timer survives minimize");
 [chat showConnectionState:2];
 FLEXDylixStatusWindow *status=[chat valueForKey:@"statusWindow"];
 Check(status&&!status.hidden,@"minimize shows a separate live status capsule");
 Check(!status.isKeyWindow&&HostWindow.isKeyWindow,@"status window never steals host key window");
 Check([status hitTest:CGPointMake(1,1) withEvent:nil]==nil,@"outside capsule touches pass through to target app");
 Check([status hitTest:status.capsule.center withEvent:nil]!=nil,@"capsule has its own usable touch target");
 [runtime setValue:status.capsule forKey:@"selectedObject"];NSDictionary *target=[runtime execute:@"screen_elements" arguments:@{} error:nil];
 BOOL capsuleInTarget=NO;for(NSDictionary *item in target[@"elements"])if([item[@"accessibilityID"] isEqual:@"dylix.agent.status"])capsuleInTarget=YES;
 Check(!capsuleInTarget&&target[@"elements"]!=nil,@"selecting an agent overlay cannot turn it into target App evidence");[runtime setValue:HostWindow forKey:@"selectedObject"];
 status.capsule.frame=CGRectMake(-900,9000,184,60);[status clampToSafeArea];
 Check(CGRectContainsRect(status.bounds,status.capsule.frame),@"dragged capsule clamps inside visible screen");
 result=Command(chat,@"chat_status",@{});Check([result[@"result"][@"targetReady"] boolValue]&&[result[@"result"][@"statusVisible"] boolValue],@"status capsule does not count as target-blocking FLEX overlay");
 [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@1,@"type":@"tool_started",@"id":@"gesture-status",@"name":@"flex_control",@"arguments":@{@"operation":@"gesture"}}]}];
 Check([status.capsule.accessibilityLabel containsString:@"请勿触屏"]&&[status.capsule.accessibilityLabel containsString:@"正在操作页面"],@"screen control displays real operation and no-touch warning");
 [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@2,@"type":@"tool_result",@"id":@"gesture-status"},@{@"sequence":@3,@"type":@"tool_started",@"id":@"build-status",@"name":@"build_project",@"arguments":@{}}]}];
 Check([status.capsule.accessibilityLabel containsString:@"正在本机构建"]&&![status.capsule.accessibilityLabel containsString:@"请勿触屏"],@"build event shows build state without pretending to touch screen");
 [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@4,@"type":@"tool_result",@"id":@"build-status"},@{@"sequence":@5,@"type":@"text",@"text":@"fixture"}]}];
 Check([status.capsule.accessibilityLabel containsString:@"正在回复"],@"text event switches capsule to replying");
 [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@1,@"type":@"tool_started",@"id":@"gesture-status",@"name":@"flex_control",@"arguments":@{@"operation":@"gesture"}}]}];
 Check(![status.capsule.accessibilityLabel containsString:@"请勿触屏"],@"replayed older events cannot restore a stale control warning");
 [chat setValue:@(NSProcessInfo.processInfo.systemUptime-22) forKey:@"lastTaskUpdate"];[chat refreshAgentStatus];
 Check([status.capsule.accessibilityLabel containsString:@"等待更新"],@"stalled stream shows elapsed wait instead of invented progress");
 [chat showConnectionState:3];Check([status.capsule.accessibilityLabel containsString:@"连接中断"],@"connection loss supersedes stale running status");[chat showConnectionState:2];
 [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@6,@"type":@"waiting_approval"}]}];
 Check([status.capsule.accessibilityLabel containsString:@"等待你的确认"],@"approval event is distinguished from model thinking");
 [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@7,@"type":@"assistant_start"}]}];
 [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];Check(status.hidden,@"capsule hides when app leaves foreground");
 [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];Check(!status.hidden,@"capsule restores on foreground without restarting task");
 for(NSNumber *dark in @[@NO,@YES]){
  status.overrideUserInterfaceStyle=dark.boolValue?UIUserInterfaceStyleDark:UIUserInterfaceStyleLight;
  [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@(dark.boolValue?9:8),@"type":@"tool_started",@"id":@"visual-control",@"name":@"flex_control",@"arguments":@{@"operation":@"gesture"}}]}];
  [status layoutIfNeeded];UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc]initWithSize:status.bounds.size];UIImage *image=[renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx){[HostWindow drawViewHierarchyInRect:HostWindow.bounds afterScreenUpdates:YES];[status drawViewHierarchyInRect:status.bounds afterScreenUpdates:YES];}];
  NSString *path=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:dark.boolValue?@"status-dark.png":@"status-light.png"];[UIImagePNGRepresentation(image) writeToFile:path atomically:YES];
 }
 [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@10,@"type":@"tool_result",@"id":@"visual-control"}]}];
 NSUInteger polls=chat.polls;Check(Await(^{return chat.polls>polls;},2),@"real timer continues polling while minimized");
 NSArray *elements=[runtime execute:@"screen_elements" arguments:@{} error:nil][@"elements"];NSString *buttonID=nil;
 for(NSDictionary *item in elements)if([item[@"label"] isEqual:@"Target smoke button"]&&[item[@"class"] isEqual:@"UIButton"])buttonID=item[@"id"];
 Check(buttonID.length>0,@"target elements discoverable without manual selection");
 NSString *targetScrollID=nil;for(NSDictionary *element in elements)if([element[@"class"] isEqual:@"UIScrollView"]&&[element[@"label"] isEqual:@"Fixture scroll"])targetScrollID=element[@"id"];
 NSDictionary *targetScrollResult=[runtime execute:@"scroll_view" arguments:@{@"id":targetScrollID?:@"",@"direction":@"up",@"pages":@0.75} error:nil];Check(![targetScrollResult[@"scrolled"] boolValue]&&[targetScrollResult[@"reachedBoundary"] boolValue]&&fabs(self.targetScroll.contentOffset.y+6)<.01,@"target top inset reports boundary and no actual movement");
 targetScrollResult=[runtime execute:@"scroll_view" arguments:@{@"id":targetScrollID?:@"",@"direction":@"down",@"pages":@0.5} error:nil];Check([targetScrollResult[@"scrolled"] boolValue]&&![targetScrollResult[@"reachedBoundary"] boolValue]&&fabs([targetScrollResult[@"delta"][@"y"] doubleValue]-50)<.01,@"target downward scroll reports actual displacement from negative inset");
 CGFloat previousY=self.targetScroll.contentOffset.y;targetScrollResult=[runtime execute:@"scroll_view" arguments:@{@"id":targetScrollID?:@"",@"direction":@"right",@"pages":@0.5} error:nil];Check([targetScrollResult[@"scrolled"] boolValue]&&fabs([targetScrollResult[@"delta"][@"x"] doubleValue]-80)<.01&&self.targetScroll.contentOffset.y==previousY,@"horizontal scrolling preserves the unrelated vertical offset");
 targetScrollResult=[runtime execute:@"scroll_view" arguments:@{@"id":targetScrollID?:@"",@"direction":@"up",@"pages":@0.75} error:nil];Check([targetScrollResult[@"scrolled"] boolValue]&&[targetScrollResult[@"reachedBoundary"] boolValue]&&fabs(self.targetScroll.contentOffset.y+6)<.01,@"target scroll can move and reach top boundary in the same request");
 FLEXDylixTouchDriver *driver=[FLEXDylixTouchDriver new];NSDictionary *backend=[FLEXDylixTouchDriver backendCapabilities];
 NSLog(@"Touch backend probe %@",backend);Check([backend[@"available"] boolValue],@"in-process touch backend probes actual system interfaces");
 __block BOOL gestureDone=NO;__block NSString *gestureError=nil;
 NSArray *start=@[[NSValue valueWithCGPoint:CGPointMake(100,300)],[NSValue valueWithCGPoint:CGPointMake(100,300)]];
 [driver performPaths:@[start] window:HostWindow duration:.08 completion:^(NSDictionary *r,NSString *e){gestureError=e;gestureDone=YES;}];
 Await(^{return (int)gestureDone;},3);Check(!gestureError&&Await(^{return self.gestureTaps>0;},1),@"real touch sequence reaches UITapGestureRecognizer");
 gestureDone=NO;gestureError=nil;[driver performPaths:@[start] window:HostWindow duration:.65 completion:^(NSDictionary *r,NSString *e){gestureError=e;gestureDone=YES;}];
 Await(^{return (int)gestureDone;},3);Check(!gestureError&&self.gestureLongPresses>0,@"real timed touch reaches UILongPressGestureRecognizer");
 gestureDone=NO;gestureError=nil;NSArray *drag=@[[NSValue valueWithCGPoint:CGPointMake(100,300)],[NSValue valueWithCGPoint:CGPointMake(240,380)]];
 [driver performPaths:@[drag] window:HostWindow duration:.5 completion:^(NSDictionary *r,NSString *e){gestureError=e;gestureDone=YES;}];
 Await(^{return (int)gestureDone;},3);Check(!gestureError&&self.gesturePans>0,@"real moving touch reaches UIPanGestureRecognizer");
 [runtime execute:@"activate_control" arguments:@{@"id":buttonID?:@""} error:nil];Check(self.tapped==1,@"target UIButton actually activated while chat minimized");
 result=Command(chat,@"gesture",@{@"kind":@"double_tap",@"x":@100,@"y":@300});Check(!result[@"error"]&&self.gestureDoubleTaps>0,@"chat command delivers real double tap");
 result=Command(chat,@"gesture",@{@"kind":@"pinch",@"x":@180,@"y":@340,@"start_radius":@30,@"end_radius":@80});Check(!result[@"error"]&&self.gesturePinches>0,@"chat command reaches real UIPinchGestureRecognizer");
 result=Command(chat,@"gesture",@{@"kind":@"rotate",@"x":@180,@"y":@340,@"radius":@50,@"angle":@90});Check(!result[@"error"]&&self.gestureRotations>0,@"chat command reaches real UIRotationGestureRecognizer");
 result=Command(chat,@"gesture",@{@"kind":@"tap",@"x":@(-5),@"y":@300});Check([result[@"error"] length]>0,@"out of window touch rejected");
 result=Command(chat,@"gesture",@{@"kind":@"pinch",@"x":@180,@"y":@340,@"start_radius":@0});Check([result[@"error"] length]>0,@"explicit zero radius rejected rather than replaced by default");
 NSString *fieldID=nil,*switchID=nil;for(NSDictionary *item in [runtime execute:@"screen_elements" arguments:@{} error:nil][@"elements"]){if([item[@"label"] isEqual:@"Fixture input"]&&[item[@"class"] isEqual:@"UITextField"])fieldID=item[@"id"];if([item[@"label"] isEqual:@"Fixture switch"]&&[item[@"class"] isEqual:@"UISwitch"])switchID=item[@"id"];}
 result=Command(chat,@"input_text",@{@"id":fieldID?:@"",@"text":@"你好 FLEX",@"replace":@YES});Check(!result[@"error"]&&[self.field.text isEqual:@"你好 FLEX"]&&self.edits>0,@"native text input edits actual field and emits editing event");
 result=Command(chat,@"input_text",@{@"id":fieldID?:@"",@"text":@"reject-fixture",@"replace":@YES});Check([result[@"error"] length]>0&&[self.field.text isEqual:@"你好 FLEX"],@"native text field delegate can reject input");
 NSDictionary *ids=@{@"Fixture text view":@"UITextView",@"Fixture slider":@"UISlider",@"Fixture segments":@"UISegmentedControl",@"Fixture stepper":@"UIStepper"};NSMutableDictionary *live=[NSMutableDictionary new];for(NSDictionary *item in [runtime execute:@"screen_elements" arguments:@{} error:nil][@"elements"])if([ids[item[@"label"]?:@""] isEqual:item[@"class"]])live[item[@"label"]]=item[@"id"];
 result=Command(chat,@"input_text",@{@"id":live[@"Fixture text view"]?:@"",@"text":@"Multiline fixture",@"replace":@YES});Check(!result[@"error"]&&[self.textView.text isEqual:@"Multiline fixture"]&&self.textViewChanges>0,@"text view input reaches native didChange delegate");
 result=Command(chat,@"input_text",@{@"id":live[@"Fixture text view"]?:@"",@"text":@"reject-fixture",@"replace":@YES});Check([result[@"error"] length]>0&&[self.textView.text isEqual:@"Multiline fixture"],@"native text view delegate can reject input");
 NSUInteger changes=self.valueChanges;result=Command(chat,@"set_control_value",@{@"id":live[@"Fixture slider"]?:@"",@"value":@0.5});Check(!result[@"error"]&&self.slider.value==.5&&self.valueChanges==changes+1,@"slider value and native event match");
 changes=self.valueChanges;result=Command(chat,@"set_control_value",@{@"id":live[@"Fixture segments"]?:@"",@"index":@1});Check(!result[@"error"]&&self.segments.selectedSegmentIndex==1&&self.valueChanges==changes+1,@"segmented value and native event match");
 changes=self.valueChanges;result=Command(chat,@"set_control_value",@{@"id":live[@"Fixture stepper"]?:@"",@"value":@4});Check(!result[@"error"]&&self.stepper.value==4&&self.valueChanges==changes+1,@"stepper value and native event match");
 result=Command(chat,@"set_control_value",@{@"id":live[@"Fixture slider"]?:@"",@"value":@2});Check([result[@"error"] length]>0&&self.slider.value==.5,@"out of native control range is rejected");
 self.field.secureTextEntry=YES;result=Command(chat,@"input_text",@{@"id":fieldID?:@"",@"text":@"denied"});Check([result[@"error"] length]>0,@"secure text input rejected");self.field.secureTextEntry=NO;
 changes=self.valueChanges;result=Command(chat,@"set_control_value",@{@"id":switchID?:@"",@"enabled":@YES});Check(!result[@"error"]&&self.toggle.on&&self.valueChanges==changes+1,@"native switch value changes with valueChanged callback");
 self.toggle.superview.hidden=YES;result=Command(chat,@"set_control_value",@{@"id":switchID?:@"",@"enabled":@NO});Check([result[@"error"] length]>0&&self.toggle.on,@"hidden ancestor prevents control mutation");self.toggle.superview.hidden=NO;
 __block BOOL cancelled=NO;[runtime performGesture:@{@"kind":@"drag",@"x":@100,@"y":@300,@"end_x":@220,@"end_y":@380,@"duration":@2} completion:^(NSDictionary *r,NSString *e){cancelled=e.length>0;}];[runtime cancelPendingInput];Check(cancelled,@"pending touch sends cancellation and finishes immediately");
 result=Command(chat,@"class_header",@{@"name":@"UIView",@"start_line":@1,@"line_count":@1});Check([result[@"result"][@"text"] isEqual:@"@interface UIView : UIResponder"]&&[result[@"result"][@"next_line"] intValue]==2,@"class header returns bounded first page and continuation");
 result=Command(chat,@"class_header",@{@"name":@"NotARealFixtureClass"});Check([result[@"error"] length]>0,@"unknown runtime class rejected");
 NSDictionary *capture=[runtime execute:@"capture_screen" arguments:@{} error:nil];
 Check([capture[@"imageBase64"] length]>0&&[capture[@"scope"] isEqual:@"target_app_window"]&&[capture[@"bytes"] unsignedIntegerValue]<=120*1024,@"real target screenshot encoded within transport bound");
 [status.capsule sendActionsForControlEvents:UIControlEventTouchUpInside];
 Check(Await(^{return chat.viewIfLoaded.window&&![[chat valueForKey:@"uiTransitioning"] boolValue];},4)&&[[chat valueForKey:@"jobID"] isEqual:@"job-fixture"]&&timer.valid,@"tapping capsule reopens retained chat without stopping task or reconnecting");
 result=Command(chat,@"restore_chat",@{});Check([result[@"result"][@"chatVisible"] boolValue]&&![result[@"result"][@"minimized"] boolValue],@"AI restores the same chat");
 Check(status.hidden,@"restored chat hides capsule without ending task");
 UILabel *activity=[chat valueForKey:@"activityLabel"];
 [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@100,@"type":@"analysis_summary",@"text":@"fixture"}]}];
 Check([activity.text containsString:@"思考"]&&status.hidden,@"expanded chat shows actual reasoning event without a floating overlay");
 [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@101,@"type":@"status",@"message":@"连接有数据，等待模型内容"}]}];
 Check([activity.text containsString:@"等待模型内容"],@"expanded chat distinguishes heartbeat waiting from reasoning");
 [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@102,@"type":@"tool_started",@"id":@"read-test",@"name":@"flex_live_read",@"arguments":@{@"operation":@"view_tree"}}]}];
 Check([activity.text containsString:@"读取视图树"],@"expanded chat shows the concrete live operation");
 [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@103,@"type":@"status",@"message":@"waiting"}]}];
 Check([activity.text containsString:@"读取视图树"],@"transport status cannot overwrite an active tool operation");
 [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@104,@"type":@"tool_result",@"id":@"read-test"},@{@"sequence":@105,@"type":@"flex_capture_status",@"captureID":@"capture-test",@"stage":@"captured"}]}];
 Check([activity.text containsString:@"截图已获取"]&&![activity.text containsString:@"已随请求发送"],@"capturing a screenshot never pretends it was uploaded");
 [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@106,@"type":@"flex_capture_status",@"captureID":@"capture-test",@"stage":@"sending"}]}];
 Check([activity.text containsString:@"截图正在发送"],@"screenshot preparing request is separate from confirmed upload");
 [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@107,@"type":@"flex_capture_status",@"captureID":@"capture-test",@"stage":@"sent"},@{@"sequence":@108,@"type":@"text",@"text":@"fixture"}]}];
 Check([activity.text containsString:@"截图已随请求发送"]&&[activity.text containsString:@"正在回复"],@"reply and confirmed screenshot upload are visible together");
 [chat.view layoutIfNeeded];
 Check(activity.numberOfLines==2&&activity.frame.size.height>=28,@"compact header gives task and screenshot status two readable lines");
 for(NSNumber *dark in @[@NO,@YES]){
  chat.overrideUserInterfaceStyle=dark.boolValue?UIUserInterfaceStyleDark:UIUserInterfaceStyleLight;[chat.view layoutIfNeeded];
  UIView *chatSurface=chat.navigationController.view;[chatSurface layoutIfNeeded];UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc]initWithSize:chatSurface.bounds.size];UIImage *preview=[renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx){[chatSurface drawViewHierarchyInRect:chatSurface.bounds afterScreenUpdates:YES];}];
  NSString *path=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:dark.boolValue?@"chat-status-dark.png":@"chat-status-light.png"];[UIImagePNGRepresentation(preview) writeToFile:path atomically:YES];
 }
 chat.overrideUserInterfaceStyle=UIUserInterfaceStyleUnspecified;

 [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@106,@"type":@"flex_capture_status",@"captureID":@"old-capture",@"stage":@"failed"}]}];
 Check([activity.text containsString:@"截图已随请求发送"],@"replayed screenshot status cannot alter the current capture");
 [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@110,@"type":@"flex_capture_status",@"captureID":@"capture-test",@"stage":@"failed"}]}];
 Check([activity.text containsString:@"截图请求失败"],@"model request failure remains visible after upload");
 [chat updateTaskFromJob:@{@"events":@[],@"flexCaptureStatus":@{@"sequence":@120,@"captureID":@"missed-capture",@"stage":@"sent"}}];
 Check([activity.text containsString:@"截图已随请求发送"],@"latest screenshot snapshot survives bounded event-history eviction");
 [chat setValue:nil forKey:@"captureStatus"];
 [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@111,@"type":@"tool_started",@"id":@"gesture-expanded",@"name":@"flex_control",@"arguments":@{@"operation":@"gesture"}}]}];
 Check([activity.text containsString:@"请勿触屏"]&&[activity.text containsString:@"操作页面"],@"expanded chat shows no-touch warning during real screen operations");
 [chat updateTaskFromJob:@{@"events":@[@{@"sequence":@112,@"type":@"tool_result",@"id":@"gesture-expanded"}]}];

 result=Command(chat,@"gesture",@{@"kind":@"tap",@"x":@100,@"y":@300});Check([result[@"error"] length]>0,@"target gesture rejected while chat overlay is visible");
 Check([chat valueForKey:@"runtime"]==runtime&&[[chat valueForKey:@"sessionID"] isEqual:@"test-session"],@"restore keeps runtime and session identity");
 NSArray *catalog=[runtime execute:@"tool_catalog" arguments:@{} error:nil][@"tools"];Check(catalog.count==FLEXGlobalsRowCount+5,@"catalog enumerates globals and five named extensions");
 Check(![catalog[FLEXGlobalsRowAppKeychainItems][@"agentOpenSupported"] boolValue],@"credential UI not exposed by catalog automation");
 result=Command(chat,@"open_tool",@{@"tool_id":@"global.0"});Check(!result[@"error"]&&![result[@"result"][@"chatVisible"] boolValue],@"AI opens native tool after minimizing chat");
 NSDictionary *state=[runtime execute:@"flex_ui_state" arguments:@{} error:nil];Check([state[@"controller"] isEqual:@"FLEXLiveObjectsController"]&&[state[@"visibleRows"] count]>0,@"FLEX UI state reports real visible rows");
 FLEXLiveObjectsController *list=(id)[FLEXUtility topViewControllerInWindow:FLEXManager.sharedManager.explorerWindow];
 [runtime execute:@"set_search" arguments:@{@"query":@"UIView"} error:nil];Check([list respondsToSelector:@selector(searches)]&&list.searches==1&&[list.navigationItem.searchController.searchBar.text isEqual:@"UIView"],@"search dispatch reaches native delegate");
 NSDictionary *row=[state[@"visibleRows"] firstObject];NSString *failure=nil;
 Check(![runtime execute:@"select_row" arguments:@{@"id":@"stale-id",@"section":@0,@"row":@0} error:&failure]&&failure.length,@"stale row identity rejected before navigation");failure=nil;
 [runtime execute:@"select_row" arguments:@{@"id":row[@"id"]?:@"",@"section":row[@"section"]?:@0,@"row":row[@"row"]?:@0} error:&failure];Check(!failure&&list.navigationController.viewControllers.count==2,@"allowed visible row navigates native list");
 failure=nil;Check(![runtime execute:@"select_row" arguments:@{@"section":@0,@"row":@0} error:&failure]&&failure.length,@"detail page cannot invoke arbitrary methods through row selection");
 result=Command(chat,@"navigate_back",@{});Check(!result[@"error"]&&list.navigationController.viewControllers.count==1,@"AI navigates back within FLEX");
 state=[runtime execute:@"flex_ui_state" arguments:@{} error:nil];NSString *scrollID=nil;
 for(NSDictionary *element in state[@"elements"])if([element[@"class"] isEqual:@"UITableView"])scrollID=element[@"id"];
 CGPoint before=list.tableView.contentOffset;NSDictionary *scrollResult=[runtime execute:@"flex_scroll" arguments:@{@"id":scrollID?:@"",@"direction":@"down",@"pages":@1} error:nil];Check(list.tableView.contentOffset.y>before.y&&[scrollResult[@"scrolled"] boolValue]&&[scrollResult[@"delta"][@"y"] doubleValue]>0,@"native FLEX list scrolls using returned live ID and actual delta");
 [runtime execute:@"flex_scroll" arguments:@{@"id":scrollID?:@"",@"direction":@"up",@"pages":@2} error:nil];CGPoint top=list.tableView.contentOffset;
 scrollResult=[runtime execute:@"flex_scroll" arguments:@{@"id":scrollID?:@"",@"direction":@"up",@"pages":@1} error:nil];Check(![scrollResult[@"scrolled"] boolValue]&&[scrollResult[@"reachedBoundary"] boolValue]&&[scrollResult[@"reason"] isEqual:@"boundary"]&&CGPointEqualToPoint(top,list.tableView.contentOffset),@"repeated upward scroll at top reports boundary without false success");
 [runtime execute:@"flex_scroll" arguments:@{@"id":scrollID?:@"",@"direction":@"down",@"pages":@2} error:nil];scrollResult=[runtime execute:@"flex_scroll" arguments:@{@"id":scrollID?:@"",@"direction":@"down",@"pages":@2} error:nil];Check(![scrollResult[@"scrolled"] boolValue]&&[scrollResult[@"reachedBoundary"] boolValue]&&fabs([scrollResult[@"delta"][@"y"] doubleValue])<.01,@"repeated downward scroll at bottom reports zero movement");
 result=Command(chat,@"open_tool",@{@"tool_id":@"custom.invalid"});Check([result[@"error"] length]>0,@"unregistered tool rejected");
 result=Command(chat,@"restore_chat",@{});Check([result[@"result"][@"chatVisible"] boolValue],@"restore dismisses tool and reuses conversation");
 result=Command(chat,@"open_tool",@{@"tool_id":@"extension.headers"});Check(!result[@"error"],@"headers extension opens through registered factory");
 state=[runtime execute:@"flex_ui_state" arguments:@{} error:nil];Check([state[@"controller"] isEqual:@"UCClassSearchViewController"]&&[state[@"visibleRows"] count]>0,@"embedded extension table exposes visible rows");
 row=[state[@"visibleRows"] firstObject];result=Command(chat,@"select_row",@{@"id":row[@"id"]?:@"",@"section":row[@"section"]?:@0,@"row":row[@"row"]?:@0});Check(!result[@"error"]&&[[FLEXUtility topViewControllerInWindow:FLEXManager.sharedManager.explorerWindow].title isEqual:@"Extension detail fixture"],@"non-table-controller extension row navigates its native delegate");
 result=Command(chat,@"open_tool",@{@"tool_id":@"extension.disassembly"});Check(!result[@"error"],@"disassembly extension opens through registered factory");
 result=Command(chat,@"restore_chat",@{});Check([result[@"result"][@"chatVisible"] boolValue],@"extension navigation restores same conversation");
 [chat closeTapped];Check(Await(^{return !chat.viewIfLoaded.window&&![[chat valueForKey:@"uiTransitioning"] boolValue];},3)&&!FLEXManager.sharedManager.isHidden,@"manual minimize returns to the existing FLEX menu");
 result=Command(chat,@"chat_status",@{});Check([result[@"result"][@"minimized"] boolValue]&&[result[@"result"][@"taskRunning"] boolValue]&&!chat.cancels&&timer.valid,@"menu minimize keeps task and polling active without pause");
 [FLEXManager.sharedManager presentTool:^{return nav;} completion:nil];Check(Await(^{return chat.viewIfLoaded.window!=nil&&!nav.isBeingPresented;},3),@"native menu presentation reuses retained chat navigation");
 result=Command(chat,@"chat_status",@{});Check(![result[@"result"][@"minimized"] boolValue]&&[result[@"result"][@"sessionID"] isEqual:@"test-session"]&&[chat valueForKey:@"agentTimer"]==timer&&[[chat valueForKey:@"jobID"] isEqual:@"job-fixture"],@"menu reopen resets visibility while retaining session task and timer");
 [chat stopAgentTapped];Check(chat.cancels==1&&[[chat valueForKey:@"agentStopped"] boolValue],@"stop latches locally and requests remote cancellation");
 result=Command(chat,@"minimize_chat",@{});Check([result[@"error"] containsString:@"停止"],@"queued control blocked after stop");
 // Simulate a late permission callback from before Stop after a new task has
 // cleared the stopped latch. Its generation must still prevent execution.
 NSString *stale=NSUUID.UUID.UUIDString;NSUInteger generation=[[chat valueForKey:@"agentGeneration"] unsignedIntegerValue];
 NSMutableDictionary *epochs=[chat valueForKey:@"commandGenerations"];epochs[stale]=@(generation-1);[chat setValue:@NO forKey:@"agentStopped"];
 [chat finishAgentCommand:@{@"id":stale,@"operation":@"minimize_chat",@"arguments":@{},@"expiresAt":@(NSDate.date.timeIntervalSince1970+30)} allowed:YES];
 Await(^{return chat.replies[stale]!=nil;},2);Check([chat.replies[stale][@"error"] containsString:@"停止"],@"late approval from stopped task cannot execute in a new task");
 [chat setValue:@YES forKey:@"agentStopped"];
 [chat closeTapped];Check(Await(^{return !chat.viewIfLoaded.window;},3)&&timer.valid,@"manual minimize preserves polling too");
 NSUInteger failures=0;for(NSDictionary *check in Checks)if(![check[@"passed"] boolValue])failures++;
 NSDictionary *report=@{@"checks":Checks,@"failures":@(failures),@"scope":@"production chat/runtime + UIKit; transport and FLEX service fixtures"};
 NSString *path=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/results.json"];[[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];[[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToFile:path atomically:YES];
 NSLog(@"FLEX UI smoke finished: %lu checks, %lu failures",(unsigned long)Checks.count,(unsigned long)failures);
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(AppDelegate.class));}}
