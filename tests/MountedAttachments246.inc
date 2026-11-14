#import "../App/AI/Attachments/TFAIDirectoryRegistry.h"
#import "../App/AI/Attachments/TFAIAttachmentStore.h"
@interface UIViewController (TF246Calls)
- (void)attachMenu;
- (void)chooseMountedAttachment;
- (void)selectMountedDirectory;
@end
static UIButton *TF246Button(UIView *view,NSString *identifier){if([view isKindOfClass:UIButton.class]&&[view.accessibilityIdentifier isEqual:identifier])return (id)view;for(UIView *child in view.subviews){UIButton *found=TF246Button(child,identifier);if(found)return found;}return nil;}
UIViewController *TMCMounted246Regression(void){
 NSMutableArray *checks=[NSMutableArray new];void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[checks addObject:@{@"name":name,@"passed":@(ok)}];};
 NSString *root=[Docs() stringByAppendingPathComponent:@"Mount246Fixture"],*file=[root stringByAppendingPathComponent:@"fixture.xm"];
 [NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];[@"// MOUNT246_READ_OK\n%hook Fixture\n%end\n" writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:nil];
 for(NSDictionary *old in TFAIDirectoryRegistry.entries)if([old[@"path"] isEqual:@"Mount246Fixture"])[TFAIDirectoryRegistry remove:old[@"directoryGrant"] error:nil];
 NSDictionary *grant=[TFAIDirectoryRegistry add:[NSURL fileURLWithPath:root] error:nil];check(grant!=nil,@"global mount registered");
 NSString *scope=[@"mount246-" stringByAppendingString:NSUUID.UUID.UUIDString];NSMutableDictionary *session=[TFAISessions create:scope title:@"挂载附件验证"];
 UIViewController *chat=TFAIChatFixtureController(@"",scope,[TFAIV2FakeRuntime new],nil);TFAIConfigureChat(chat,session,YES,nil);
 UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:chat];
 void(^finish)(void)=^{JSONWrite(checks,[Docs() stringByAppendingPathComponent:@"mounted246-results.json"],nil);[TFAIDirectoryRegistry remove:grant[@"directoryGrant"] error:nil];[TFAISessions remove:session[@"id"] project:scope];};
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
 [chat attachMenu];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,600*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
 UIButton *button=TF246Button(chat.presentedViewController.view,@"attachment-source-mounted");check(button!=nil,@"conversation attachment menu exposes mounted folders");if(!button){finish();return;}check(button.configuration.image!=nil,@"mounted attachment button has visible icon");TF235Screenshot((id)chat.presentedViewController,@"data248-attachment-menu");[button sendActionsForControlEvents:UIControlEventTouchUpInside];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
 UINavigationController *browser=(id)chat.presentedViewController;UITableViewController *list=(id)browser.topViewController;NSArray *rows=[list valueForKey:@"rows"];NSUInteger row=[rows indexOfObjectPassingTest:^BOOL(NSDictionary *entry,NSUInteger i,BOOL *stop){return [entry[@"directoryGrant"] isEqual:grant[@"directoryGrant"]];}];check(row!=NSNotFound,@"mounted directory appears in conversation picker");if(row==NSNotFound){finish();return;}
 [list.tableView.delegate tableView:list.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,600*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
 UITableViewController *tree=(id)browser.topViewController;NSArray *files=[tree valueForKey:@"rows"];NSUInteger i=[files indexOfObjectPassingTest:^BOOL(NSDictionary *entry,NSUInteger idx,BOOL *stop){return [entry[@"path"] isEqual:@"fixture.xm"];}];check(i!=NSNotFound,@"live mounted file appears");if(i==NSNotFound){finish();return;}
 [tree.tableView.delegate tableView:tree.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{
 NSArray *attachments=[chat valueForKey:@"attachments"];check(attachments.count==1,@"selected single file reaches conversation draft");NSError *error=nil;NSArray *resolved=TFAIResolveAttachments(attachments,&error);check(resolved.count==1&&!error,@"selected file resolves through real send-time attachment pipeline");NSDictionary *single=resolved.firstObject;NSDictionary *read=TFAIReadAttachmentReferences(@{@"fixture":single?:@{}},@{@"id":@"fixture",@"action":@"read"},&error);check([read.description containsString:@"MOUNT246_READ_OK"]&&!error,@"AI attachment read returns real selected content");
 TF235Screenshot((id)nav,@"data246-single-file");[chat chooseMountedAttachment];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,700*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
 UINavigationController *b=(id)chat.presentedViewController;UITableViewController *l=(id)b.topViewController;NSArray *dirs=[l valueForKey:@"rows"];NSUInteger j=[dirs indexOfObjectPassingTest:^BOOL(NSDictionary *entry,NSUInteger idx,BOOL *stop){return [entry[@"directoryGrant"] isEqual:grant[@"directoryGrant"]];}];if(j==NSNotFound){check(NO,@"second mount selection");finish();return;}
 [l.tableView.delegate tableView:l.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:j inSection:0]];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[(id)b.topViewController selectMountedDirectory];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
 NSArray *all=[chat valueForKey:@"attachments"];NSDictionary *directory=all.lastObject;check(all.count==2&&directory[@"directoryGrant"]!=nil,@"whole mount added as one directory reference");check(![directory[@"directoryGrant"] isEqual:grant[@"directoryGrant"]],@"chat directory reference independent from global mount");
 NSDictionary *contents=TFAIReadAttachmentReferences(@{@"directory":directory?:@{}},@{@"id":@"directory",@"action":@"list"},nil);check([contents.description containsString:@"fixture.xm"],@"AI read tool lists whole attached directory");
 TFAIRevokeDirectory(directory,nil);check(TFAIReadDirectoryReference(grant,@{@"action":@"validate"},nil)!=nil,@"revoking conversation directory leaves global mount valid");
 check([[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] containsString:@"MOUNT246_READ_OK"],@"source file preserved");finish();
 });});});});});});});});return nav;
}
