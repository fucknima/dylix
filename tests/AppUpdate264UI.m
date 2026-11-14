#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../App/AI/Resources/DXAppUpdate.h"
static NSString *remote=@"9.0.0";static NSUInteger checks=0;
static void FixtureCheck(id self,SEL cmd,void(^completion)(NSDictionary *,NSError *)){checks++;dispatch_async(dispatch_get_main_queue(),^{completion(@{@"version":remote},nil);});}
@interface UpdateProof:UIResponder<UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@property NSMutableArray *rows;
@property UIViewController *page;
@end
@implementation UpdateProof
- (void)record:(BOOL)ok name:(NSString *)name{[self.rows addObject:@{@"test":name,@"passed":@(ok)}];}
- (void)later:(NSTimeInterval)delay block:(void(^)(void))block{dispatch_after(dispatch_time(DISPATCH_TIME_NOW,delay*NSEC_PER_SEC),dispatch_get_main_queue(),block);}
- (void)finish:(NSString *)phase{NSString *path=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:[phase stringByAppendingString:@".json"]];[[NSJSONSerialization dataWithJSONObject:self.rows options:NSJSONWritingPrettyPrinted error:nil]writeToFile:path atomically:YES];}
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options{
 method_setImplementation(class_getInstanceMethod(DXAppUpdate.class,@selector(check:)),(IMP)FixtureCheck);
 self.rows=[NSMutableArray new];self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];self.page=[UIViewController new];self.page.view.backgroundColor=UIColor.systemBackgroundColor;self.window.rootViewController=self.page;[self.window makeKeyAndVisible];
 BOOL restore=[NSProcessInfo.processInfo.arguments containsObject:@"restore"];
 if(restore){
  [self record:[[NSUserDefaults.standardUserDefaults stringForKey:@"DylixIgnoredUpdateVersion"]isEqual:@"9.0.0"] name:@"ignored version survives process restart"];
  [self later:.4 block:^{DXAppUpdatePresent(self.page,NO);[self later:.7 block:^{[self record:!self.page.presentedViewController name:@"ignored release does not automatically alert after restart"];remote=@"9.0.1";DXAppUpdatePresent(self.page,NO);[self later:.7 block:^{UIAlertController *alert=(id)self.page.presentedViewController;[self record:[alert isKindOfClass:UIAlertController.class]&&[alert.title isEqual:@"发现新版本"] name:@"next release automatically alerts despite previous ignore"];[self finish:@"restore"];}];}];}];return YES;
 }
 [NSUserDefaults.standardUserDefaults removeObjectForKey:@"DylixIgnoredUpdateVersion"];
 [self later:.4 block:^{UIAlertController *busy=[UIAlertController alertControllerWithTitle:@"其他提示" message:nil preferredStyle:UIAlertControllerStyleAlert];[busy addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];[self.page presentViewController:busy animated:NO completion:nil];DXAppUpdateOnLaunch(self.page);DXAppUpdateOnLaunch(self.page);
 [self later:3.5 block:^{[self record:checks==1 name:@"cold launch checks only once even when invoked twice"];[self record:self.page.presentedViewController==busy name:@"update does not cover existing alert"];[busy dismissViewControllerAnimated:NO completion:nil];}];
 [self later:4.8 block:^{UIAlertController *alert=(id)self.page.presentedViewController;[self record:[alert isKindOfClass:UIAlertController.class]&&[alert.title isEqual:@"发现新版本"] name:@"pending launch update appears after competing alert closes"];UIAlertAction *ignore=nil;for(UIAlertAction *a in alert.actions)if([a.title isEqual:@"忽略此版本"])ignore=a;[self record:alert.actions.count==3&&ignore!=nil name:@"update dialog offers update ignore and later"];void(^handler)(UIAlertAction *)=[ignore valueForKey:@"handler"];if(handler)handler(ignore);
 [alert dismissViewControllerAnimated:NO completion:^{DXAppUpdatePresent(self.page,NO);[self later:.5 block:^{[self record:!self.page.presentedViewController name:@"ignored version suppresses subsequent automatic dialog"];DXAppUpdatePresent(self.page,YES);[self later:1 block:^{UIAlertController *manual=(id)self.page.presentedViewController;[self record:[manual.title isEqual:@"发现新版本"] name:@"manual check still offers ignored version"];[self finish:@"initial"];}];}];}];}];}];return YES;
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(UpdateProof.class));}}
