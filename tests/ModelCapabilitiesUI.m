#import <UIKit/UIKit.h>
#import "../App/AI/UI/TFAIModelConfiguration.h"
#import "../App/AI/UI/TFAIModelControls.h"
#import "../App/AI/UI/TFAITestDetail.h"
#import "../App/AI/Providers/TFAIProtocol.h"
#import "../App/AI/Providers/TFAIRegistry.h"
@interface ModelProof : UIResponder <UIApplicationDelegate>
@property UIWindow *window;
@property NSMutableArray *rows;
@end
@implementation ModelProof
- (void)check:(BOOL)ok name:(NSString *)name{[self.rows addObject:@{@"test":name,@"passed":@(ok)}];}
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options{
 self.rows=[NSMutableArray new];self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];
 NSString *identifier=@"capability-ui231";NSMutableDictionary *connection=[@{@"id":identifier,@"name":@"中转服务",@"protocol":@"chat",@"baseURL":@"https://fixture.invalid/v1",@"model":@"6.1 sol"} mutableCopy];
 [TFAIConnections save:connection secret:nil error:nil];
 __block NSDictionary *changed=nil;UITableViewController *page=(id)TFAIModelConfigurationController(connection,^(NSDictionary *result){changed=result;});self.window.rootViewController=[[UINavigationController alloc]initWithRootViewController:page];[self.window makeKeyAndVisible];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
  [self check:[page.tableView.dataSource numberOfSectionsInTableView:page.tableView]==4 name:@"native_model_configuration_sections"];
  NSIndexPath *image=[NSIndexPath indexPathForRow:0 inSection:0];[page.tableView.delegate tableView:page.tableView didSelectRowAtIndexPath:image];
  [self check:[TFAIResolvedCapability(changed,@"image")[@"source"] isEqual:@"当前模型手动配置"] name:@"native_enable_image_persists_override"];
  [page.tableView.delegate tableView:page.tableView didSelectRowAtIndexPath:image];[self check:[TFAIResolvedCapability(changed,@"image")[@"state"] isEqual:@"unsupported"] name:@"native_disable_image"];
  [page.tableView.delegate tableView:page.tableView didSelectRowAtIndexPath:image];[self check:![TFAIResolvedCapability(changed,@"image")[@"source"] isEqual:@"当前模型手动配置"] name:@"native_restore_image_auto"];
  NSIndexPath *tools=[NSIndexPath indexPathForRow:1 inSection:0];[page.tableView.delegate tableView:page.tableView didSelectRowAtIndexPath:tools];[page.tableView.delegate tableView:page.tableView didSelectRowAtIndexPath:tools];[self check:!TFAIToolsAllowed(changed) name:@"native_tool_disable_respected"];
  [page.tableView.delegate tableView:page.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:3]];[self check:TFAIToolsAllowed(changed)&&![changed[@"capabilityOverrides"] count] name:@"native_reset_model_overrides"];
  // Render the real manual level editor and test tap-to-toggle through its delegate.
  NSMutableDictionary *manual=[changed mutableCopy];manual[@"thinkingOverrides"]=@{TFAIThinkingScope(manual):@{@"wire":@"reasoning_effort",@"levels":@[@"low",@"high"]}};
  [page setValue:manual forKey:@"connection"];[page.tableView reloadData];
  [self check:[page.tableView.dataSource tableView:page.tableView numberOfRowsInSection:1]==9 name:@"native_effort_editor_has_declared_choices"];
  [page.tableView.delegate tableView:page.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:1]];
  [self check:[[TFAIReasoningOptions(changed) valueForKey:@"id"] containsObject:@"medium"] name:@"native_effort_selection_updates_resolver"];
  NSMutableDictionary *foreign=[changed mutableCopy];foreign[@"capabilities"]=@{@"image":@"supported"};foreign[@"capabilitiesScope"]=@"another-endpoint";TFAIRecordProbeResult(foreign,@"text",@{@"status":@"supported"},nil);[self check:![foreign[@"capabilities"][@"image"] isEqual:@"supported"] name:@"256_new_probe_does_not_transfer_other_endpoint_evidence"];
  NSMutableDictionary *proved=[changed mutableCopy];proved[@"capabilities"]=@{@"image":@"supported"};TFAIRecordProbeResult(proved,@"image",nil,[NSError errorWithDomain:@"fixture" code:429 userInfo:@{NSLocalizedDescriptionKey:@"限流"}]);
  [self check:[proved[@"capabilities"][@"image"] isEqual:@"supported"]&&[proved[@"testResults"][@"image"][@"state"] isEqual:@"fail"] name:@"failed_retest_preserves_positive_evidence_but_records_failure"];
  NSString *report=TFAIProbeReport(@{@"state":@"unknown",@"diagnostics":@{@"reasoningSummary":@"实际发送：reasoning_effort=high"}},@"thinking");[self check:[report containsString:@"reasoning_effort=high"] name:@"thinking_report_exposes_actual_parameters"];
  UIViewController *controls=TFAIModelControlsController(manual,@"high",nil,nil);[controls loadViewIfNeeded];NSUInteger before=[[controls valueForKey:@"stack"] arrangedSubviews].count;[controls performSelector:NSSelectorFromString(@"rebuildControls")];[self check:before==[[controls valueForKey:@"stack"] arrangedSubviews].count name:@"model_control_rebuild_does_not_duplicate_views"];[self check:[[[controls valueForKey:@"options"] valueForKey:@"id"] containsObject:@"high"] name:@"model_control_uses_resolved_effort_options"];
  NSMutableDictionary *unknown=[connection mutableCopy];unknown[@"model"]=@"opaque-ui256";[unknown removeObjectForKey:@"capabilities"];[unknown removeObjectForKey:@"thinkingOverrides"];[unknown removeObjectForKey:@"capabilityOverrides"];
  [page setValue:unknown forKey:@"connection"];[page.tableView reloadData];
  UITableViewCell *unknownImage=[page.tableView.dataSource tableView:page.tableView cellForRowAtIndexPath:image];
  [self check:[unknownImage.detailTextLabel.text containsString:@"可尝试"]&&TFAIImagesAllowed(unknown) name:@"256_unknown_image_can_attempt_without_probe"];
  [self check:[page.tableView.dataSource tableView:page.tableView numberOfRowsInSection:2]==5 name:@"256_individual_capability_sources_visible"];
  UIViewController *unknownControls=TFAIModelControlsController(unknown,@"auto",nil,nil);[unknownControls loadViewIfNeeded];
  [self check:!((UISlider *)[unknownControls valueForKey:@"slider"]).hidden&&[[[unknownControls valueForKey:@"options"] valueForKey:@"id"] containsObject:@"high"] name:@"256_unknown_reasoning_compatibility_controls_visible"];
  [page.tableView.delegate tableView:page.tableView didSelectRowAtIndexPath:image];[page.tableView.delegate tableView:page.tableView didSelectRowAtIndexPath:image];
  [self check:!TFAIImagesAllowed(changed) name:@"256_explicit_disable_still_blocks_images"];
  [TFAIConnections remove:identifier];
  NSString *path=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"model-ui231.json"];
  [[NSJSONSerialization dataWithJSONObject:self.rows options:NSJSONWritingPrettyPrinted error:nil] writeToFile:path atomically:YES];
 });return YES;
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(ModelProof.class));}}
