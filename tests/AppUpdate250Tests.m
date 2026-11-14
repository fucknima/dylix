#import "../App/AI/Resources/DXAppUpdate.h"
static int total=0;
static void Check(BOOL ok,NSString *name){if(!ok){NSLog(@"FAIL %@",name);exit(1);}total++;NSLog(@"PASS %@",name);}
int main(int argc,char **argv){@autoreleasepool{
 NSURL *site=[NSURL URLWithString:@"https://dylib.cn/"];NSError *error=nil;
 NSDictionary *r=DXAppUpdateFromHTML(@"<a class='download-file' href='downloads/Dylix-1.2.3.ipa' download>下载</a>",site,&error);Check([r[@"version"] isEqual:@"1.2.3"]&&[r[@"ipaURL"] isEqual:@"https://dylib.cn/downloads/Dylix-1.2.3.ipa"],@"relative official IPA filename supplies version");
 r=DXAppUpdateFromHTML(@"<a href=\"https://dylib.cn/downloads/Dylix-1.1.1-build250-unsigned.ipa\">Get</a>",site,&error);Check([r[@"version"] isEqual:@"1.1.1"],@"build suffix parsed without changing semantic version");
 Check(DXAppVersionIsNewer(@"1.10.0",@"1.9.9"),@"numeric comparison not lexical");Check(!DXAppVersionIsNewer(@"1.1.1",@"1.1.1"),@"equal release not update");Check(!DXAppVersionIsNewer(@"1.1.0",@"1.1.1"),@"older website never offers downgrade");Check(!DXAppVersionIsNewer(@"1.1.0.0",@"1.1"),@"trailing zeros compare equal");Check(!DXAppVersionIsNewer(@"unknown",@"1.0.0"),@"invalid version refused");
 Check(!DXAppUpdateFromHTML(@"<a href='https://evil.example/downloads/Dylix-9.9.9.ipa'>x</a>",site,&error),@"foreign IPA origin refused");Check(!DXAppUpdateFromHTML(@"<a href='http://dylib.cn/downloads/Dylix-9.9.9.ipa'>x</a>",site,&error),@"insecure download origin refused");Check(!DXAppUpdateFromHTML(@"<a href='downloads/Other-9.9.9.ipa'>x</a><b>Dylix 9.9.9</b>",site,&error),@"marketing text and other app ignored");Check(!DXAppUpdateFromHTML(@"<a href='downloads/Dylix-1.2.3.ipa'>x</a>",[NSURL URLWithString:@"https://evil.example/"],&error),@"foreign homepage refused");
 r=DXAppUpdateFromHTML(@"<a href='downloads/Dylix-1.2.3.ipa'>x</a><a href='downloads/Dylix-1.10.0.ipa'>x</a>",site,&error);Check([r[@"version"] isEqual:@"1.10.0"],@"highest official IPA release selected");
 NSString *key=@"DylixIgnoredUpdateVersion";NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;id saved=[defaults objectForKey:key];[defaults removeObjectForKey:key];
 DXAppUpdate *updates=DXAppUpdate.shared;NSDictionary *next=@{@"version":@"1.2.0"};
 Check([updates shouldOfferRelease:next installedVersion:@"1.1.2" manual:NO],@"new release offers automatic alert");
 [updates ignoreVersion:@"1.2.0"];
 Check(![[DXAppUpdate new] shouldOfferRelease:next installedVersion:@"1.1.2" manual:NO],@"ignored release persists across manager instances");
 Check(![updates shouldOfferRelease:@{@"version":@"1.2.0.0"} installedVersion:@"1.1.2" manual:NO],@"equivalent ignored version stays suppressed");
 Check([updates shouldOfferRelease:next installedVersion:@"1.1.2" manual:YES],@"manual check can still offer ignored release");
 Check([updates shouldOfferRelease:@{@"version":@"1.2.1"} installedVersion:@"1.1.2" manual:NO],@"later release offers automatic alert");
 Check(![updates shouldOfferRelease:next installedVersion:@"1.2.0" manual:YES],@"already installed release is not offered");
 Check(![updates shouldOfferRelease:nil installedVersion:@"1.1.2" manual:NO],@"failed check has no automatic alert");
 [updates ignoreVersion:@"bad"];
 Check([[defaults stringForKey:key] isEqual:@"1.2.0"],@"invalid ignored version leaves preference unchanged");
 if(saved)[defaults setObject:saved forKey:key];else[defaults removeObjectForKey:key];
 NSString *html=[NSString stringWithContentsOfFile:@(argv[1]) encoding:NSUTF8StringEncoding error:nil];r=DXAppUpdateFromHTML(html,site,&error);Check(r!=nil,@"actual website snapshot parses");NSLog(@"LIVE_SNAPSHOT %@",r);
 __block BOOL finished=NO;__block NSDictionary *live=nil;__block NSError *failure=nil;__block int calls=0;
 [DXAppUpdate.shared check:^(NSDictionary *v,NSError *e){live=v;failure=e;finished=YES;calls++;}];[DXAppUpdate.shared check:^(NSDictionary *v,NSError *e){calls++;}];NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:35];while((!finished||calls<2)&&deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.03]];Check(finished&&calls==2&&live&&!failure,@"live HTTPS homepage check with coalesced callers");
 NSLog(@"TOTAL %d update checks passed; official version %@",total,live[@"version"]);
}return 0;}
