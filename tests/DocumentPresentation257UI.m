#import <UIKit/UIKit.h>
#define main DocumentPresentationFixtureMain
#define Check Document257Check
#define Put Document257Put
#define Children Document257Children
#import "DocumentPresentation257Tests.m"
#undef main
#undef Check
#undef Put
#undef Children
@interface Document257Page:UITableViewController
@property NSArray<NSURL *> *files;
@end
@implementation Document257Page
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s{return self.files.count;}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)i{UITableViewCell *c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];NSURL *u=self.files[i.row];NSNumber *directory=nil;[u getResourceValue:&directory forKey:NSURLIsDirectoryKey error:nil];c.textLabel.text=u.lastPathComponent;c.textLabel.numberOfLines=2;c.imageView.image=[UIImage systemImageNamed:directory.boolValue?@"folder.fill":@"doc.text"];c.imageView.tintColor=UIColor.systemBlueColor;c.detailTextLabel.text=directory.boolValue?[NSString stringWithFormat:@"%lu 项",(unsigned long)[NSFileManager.defaultManager contentsOfDirectoryAtPath:u.path error:nil].count]:@"文件分类与旧数据说明";c.accessoryType=directory.boolValue?UITableViewCellAccessoryDisclosureIndicator:UITableViewCellAccessoryNone;return c;}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)i{NSURL *u=self.files[i.row];NSNumber *d=nil;[u getResourceValue:&d forKey:NSURLIsDirectoryKey error:nil];if(!d.boolValue)return;Document257Page *p=[[Document257Page alloc]initWithStyle:UITableViewStyleInsetGrouped];p.title=u.lastPathComponent;p.files=[NSFileManager.defaultManager contentsOfDirectoryAtURL:u includingPropertiesForKeys:@[NSURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];[self.navigationController pushViewController:p animated:YES];}
@end
@interface Document257App:UIResponder<UIApplicationDelegate>
@property UIWindow *window;
@end
@implementation Document257App
- (BOOL)application:(UIApplication *)a didFinishLaunchingWithOptions:(NSDictionary *)o{
 self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];Document257Page *page=[[Document257Page alloc]initWithStyle:UITableViewStyleInsetGrouped];page.title=@"Dylix 文件分类验证";self.window.rootViewController=[[UINavigationController alloc]initWithRootViewController:page];[self.window makeKeyAndVisible];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
 int result=DocumentPresentationFixtureMain();NSString *docs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject,*lib=NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES).firstObject;
 NSString *project=[docs stringByAppendingPathComponent:@"Projects/KOOKNoAds"];Document257Put([project stringByAppendingPathComponent:@"MobileCompiler.json"],@"{\"name\":\"KOOKNoAds\"}");Document257Put([project stringByAppendingPathComponent:@"Tweak.xm"],@"%hook Example\n%end");
 NSString *id=@"AB381ECA-AD6C-4400-8111-0000003A47E6",*build=[docs stringByAppendingPathComponent:[@"Build-" stringByAppendingString:id]];Document257Put([build stringByAppendingPathComponent:@"KOOKNoAds_1.0.0.deb"],@"test fixture package");Document257Put([build stringByAppendingPathComponent:@"report.json"],@"{\"success\":true}");[[NSJSONSerialization dataWithJSONObject:@{@"project":project} options:0 error:nil] writeToFile:[build stringByAppendingPathComponent:@".studio-cache-owner.json"] atomically:YES];
 NSString *incomingID=@"142E7136-ED33-4400-8111-0000001ED27F",*incoming=[[docs stringByAppendingPathComponent:@"Incoming"] stringByAppendingPathComponent:incomingID],*received=[incoming stringByAppendingPathComponent:@"KOOKNoAds.xm"];Document257Put(received,@"%hook Example\n%end");[[NSJSONSerialization dataWithJSONObject:@{@"id":incomingID,@"name":@"KOOKNoAds.xm",@"path":received,@"receivedAt":@(NSDate.date.timeIntervalSince1970),@"bytes":@18,@"kind":@"file",@"detail":@"source"} options:0 error:nil] writeToFile:[incoming stringByAppendingPathComponent:@"receipt.json"] atomically:YES];
 NSString *zip=[[docs stringByAppendingPathComponent:@"ClassDumpExports"] stringByAppendingPathComponent:[id stringByAppendingPathExtension:@"zip"]];Document257Put(zip,@"fixture archive");Document257Put([[[docs stringByAppendingPathComponent:@"AIClassDumpInputs"] stringByAppendingPathComponent:id] stringByAppendingPathComponent:@"metadata.json"],@"{\"name\":\"Quantumult X.ipa\"}");TMCPrepareDocumentPresentation(docs);
 page.files=[NSFileManager.defaultManager contentsOfDirectoryAtURL:[NSURL fileURLWithPath:docs] includingPropertiesForKeys:@[NSURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];[page.tableView reloadData];
 NSMutableArray *names=[NSMutableArray new];BOOL noUUID=YES;for(NSURL *u in page.files){[names addObject:u.lastPathComponent];if(TMCDocumentWorkspace(u.lastPathComponent))noUUID=NO;}
 NSDictionary *verification=@{@"nativeFixtureExitCode":@(result),@"nativeChecks":@(checks),@"nativeFailures":@(failures),@"rootNames":names,@"nativeHiddenFilteringPassed":@(noUUID),@"version":UIDevice.currentDevice.systemVersion};[[NSJSONSerialization dataWithJSONObject:verification options:NSJSONWritingPrettyPrinted error:nil] writeToFile:[lib stringByAppendingPathComponent:@"document257-verification.json"] atomically:YES];
 });return YES;
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(Document257App.class));}}
