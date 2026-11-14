static void Backup249Screenshot(UIViewController *page,NSString *name){[page.view layoutIfNeeded];UIGraphicsImageRenderer *render=[[UIGraphicsImageRenderer alloc]initWithBounds:page.view.bounds];NSData *data=UIImagePNGRepresentation([render imageWithActions:^(UIGraphicsImageRendererContext *ctx){[page.view drawViewHierarchyInRect:page.view.bounds afterScreenUpdates:YES];}]);[data writeToFile:[Docs() stringByAppendingPathComponent:[name stringByAppendingString:@".png"]] atomically:YES];}
// Production backup UI integration; all mutations use simulator-owned fixtures.
static UIViewController *TMCBackup249Regression(void){
 UIViewController *page=DXBackupController();UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:page];
 NSMutableArray *checks=[NSMutableArray new];void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[checks addObject:@{@"name":name,@"passed":@(ok)}];};
 NSString *fixture=[Docs() stringByAppendingPathComponent:@"Projects/Backup249Fixture"],*file=[fixture stringByAppendingPathComponent:@"payload.bin"];
 [NSFileManager.defaultManager createDirectoryAtPath:fixture withIntermediateDirectories:YES attributes:nil error:nil];
 NSMutableData *chunk=[NSMutableData dataWithLength:1024*1024];arc4random_buf(chunk.mutableBytes,chunk.length);[NSFileManager.defaultManager createFileAtPath:file contents:nil attributes:nil];NSFileHandle *writer=[NSFileHandle fileHandleForWritingAtPath:file];for(int i=0;i<32;i++)[writer writeData:chunk];[writer closeFile];
 __block NSUInteger ticks=0;__block BOOL started=NO,sawProgress=NO;__block NSSet *before=nil;
 __block NSTimer *watch=nil;watch=[NSTimer scheduledTimerWithTimeInterval:.05 repeats:YES block:^(NSTimer *timer){
 if(++ticks>1200){check(NO,@"backup UI workflow completes in time");[timer invalidate];JSONWrite(checks,[Docs() stringByAppendingPathComponent:@"backup249-results.json"],nil);watch=nil;return;}
 if(!page.isViewLoaded||[[page valueForKey:@"scanning"] boolValue])return;
 UIButton *button=[page valueForKey:@"actionButton"];UILabel *summary=[page valueForKey:@"summary"],*status=[page valueForKey:@"status"];
 if(!started){started=YES;check(page.navigationItem.rightBarButtonItem==nil,@"backup entry no longer uses navigation share icon");check(button.enabled&&[button.configuration.title isEqual:@"立即备份"]&&!nav.toolbarHidden,@"bottom immediate-backup button is enabled and visible");check([summary.text containsString:@"预计约"]&&[summary.text containsString:@"已选"],@"selected total and approximate duration displayed");
 UITableViewController *table=(id)page;UITableViewCell *cell=[table tableView:table.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];check([cell.textLabel.text containsString:@"MB"],@"project category displays source size");
 NSString *initial=summary.text;[table tableView:table.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];check(![summary.text isEqual:initial],@"selection immediately updates size summary");
 [page setValue:[NSMutableSet setWithObject:@"projects"] forKey:@"selected"];[page setValue:@"backup-test-249" forKey:@"password"];[page performSelector:NSSelectorFromString(@"updateSummary")];[table.tableView reloadData];
 Backup249Screenshot((id)nav,@"backup249-ready");NSString *backups=[Docs() stringByAppendingPathComponent:@"DylixBackups"];before=[NSSet setWithArray:[NSFileManager.defaultManager contentsOfDirectoryAtPath:backups error:nil]?:@[]];[button sendActionsForControlEvents:UIControlEventTouchUpInside];check([[page valueForKey:@"busy"] boolValue]&&[button.configuration.title isEqual:@"终止备份"],@"one tap starts independent backup with terminate control");return;
 }
 NSProgress *progress=[page valueForKey:@"progress"];
 if([[page valueForKey:@"busy"] boolValue]){if(!sawProgress&&progress.fractionCompleted>0&&progress.fractionCompleted<1&&[status.text containsString:@"%"]){sawProgress=YES;Backup249Screenshot((id)nav,@"backup249-progress");}return;}
 check(sawProgress,@"live percentage visible during real backup");check(progress.fractionCompleted==1&&[status.text containsString:@"100%"]&&[status.text containsString:@"用时"],@"completion shows percentage actual duration and file size");check([button.configuration.title isEqual:@"立即备份"]&&button.enabled,@"button recovers after completion");
 UIAlertController *done=(id)page.presentedViewController;check([done isKindOfClass:UIAlertController.class]&&[done.title isEqual:@"备份完成"],@"completion does not automatically open share sheet");
 Backup249Screenshot((id)done,@"backup249-complete");
 NSString *backups=[Docs() stringByAppendingPathComponent:@"DylixBackups"];for(NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:backups error:nil])if(![before containsObject:name]){NSString *package=[backups stringByAppendingPathComponent:name];check([[NSFileManager.defaultManager attributesOfItemAtPath:package error:nil][NSFileSize] unsignedLongLongValue]>1000,@"backup package persisted");[NSFileManager.defaultManager removeItemAtPath:package error:nil];}
 [NSFileManager.defaultManager removeItemAtPath:fixture error:nil];JSONWrite(checks,[Docs() stringByAppendingPathComponent:@"backup249-results.json"],nil);[timer invalidate];watch=nil;
 }];return nav;
}
