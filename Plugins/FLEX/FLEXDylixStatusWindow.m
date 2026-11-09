#import "FLEXDylixStatusWindow.h"

@interface DXStatusRootController : UIViewController
@end
@implementation DXStatusRootController
- (void)viewDidLayoutSubviews {[super viewDidLayoutSubviews];[(FLEXDylixStatusWindow *)self.view.window clampToSafeArea];}
@end

@interface FLEXDylixStatusWindow ()
@property (nonatomic) UIButton *capsule;
@property UILabel *heading, *detail;
@property UIView *dot;
@property UIActivityIndicatorView *spinner;
@property BOOL positioned;
@end

@implementation FLEXDylixStatusWindow
- (instancetype)initWithWindowScene:(UIWindowScene *)scene {
 if((self=[super initWithWindowScene:scene]))[self configure];return self;
}
- (instancetype)initWithFrame:(CGRect)frame {
 if((self=[super initWithFrame:frame]))[self configure];return self;
}
- (void)configure {
 if(self.capsule)return;
 self.hidden=YES;self.backgroundColor=UIColor.clearColor;self.windowLevel=UIWindowLevelAlert+2;
 self.rootViewController=[DXStatusRootController new];self.rootViewController.view.backgroundColor=UIColor.clearColor;
 self.capsule=[UIButton buttonWithType:UIButtonTypeCustom];self.capsule.frame=CGRectMake(0,0,184,60);
 self.capsule.backgroundColor=UIColor.secondarySystemBackgroundColor;self.capsule.layer.cornerRadius=22;
 self.capsule.layer.borderWidth=.5;self.capsule.layer.borderColor=UIColor.separatorColor.CGColor;
 self.capsule.layer.shadowColor=UIColor.blackColor.CGColor;self.capsule.layer.shadowOpacity=.16;self.capsule.layer.shadowRadius=10;self.capsule.layer.shadowOffset=CGSizeMake(0,3);
 self.capsule.accessibilityIdentifier=@"dylix.agent.status";self.capsule.accessibilityHint=@"轻点返回同一 AI 会话，可拖动调整位置";
 [self.capsule addTarget:self action:@selector(openTapped) forControlEvents:UIControlEventTouchUpInside];
 [self.capsule addGestureRecognizer:[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(pan:)]];
 self.dot=[[UIView alloc]initWithFrame:CGRectMake(12,14,6,6)];self.dot.layer.cornerRadius=3;self.dot.userInteractionEnabled=NO;
 self.heading=[[UILabel alloc]initWithFrame:CGRectMake(25,9,147,20)];self.heading.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];self.heading.textColor=UIColor.labelColor;
 self.detail=[[UILabel alloc]initWithFrame:CGRectMake(25,31,147,17)];self.detail.font=[UIFont systemFontOfSize:11 weight:UIFontWeightMedium];self.detail.textColor=UIColor.secondaryLabelColor;
 self.heading.adjustsFontSizeToFitWidth=YES;self.heading.minimumScaleFactor=.85;self.detail.lineBreakMode=NSLineBreakByTruncatingTail;
 self.spinner=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];self.spinner.frame=CGRectMake(5,29,19,19);self.spinner.transform=CGAffineTransformMakeScale(.6,.6);
 for(UIView *v in @[self.dot,self.heading,self.detail,self.spinner]){v.userInteractionEnabled=NO;[self.capsule addSubview:v];}
 [self.rootViewController.view addSubview:self.capsule];
}
- (BOOL)canBecomeKeyWindow {return NO;}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
 if(self.hidden||self.alpha<.01||!CGRectContainsPoint(self.capsule.frame,point))return nil;
 return [super hitTest:point withEvent:event];
}
- (void)updateTitle:(NSString *)title detail:(NSString *)detail color:(UIColor *)color busy:(BOOL)busy {
 self.heading.text=title;self.detail.text=detail;self.dot.backgroundColor=color;self.spinner.color=color;
 self.capsule.accessibilityLabel=[NSString stringWithFormat:@"Dylix AI，%@，%@",title,detail];
 if(busy&&!UIAccessibilityIsReduceMotionEnabled())[self.spinner startAnimating];else[self.spinner stopAnimating];
 [self clampToSafeArea];
}
- (void)clampToSafeArea {
 if(!self.capsule)return;
 CGRect bounds=self.rootViewController.view.bounds;UIEdgeInsets safe=self.safeAreaInsets;
 CGFloat width=MIN(184,MAX(140,bounds.size.width-24));CGRect frame=self.capsule.frame;frame.size=CGSizeMake(width,60);
 if(!self.positioned&&bounds.size.width>0){frame.origin=CGPointMake(bounds.size.width-width-12,MAX(safe.top+12,bounds.size.height*.22));self.positioned=YES;}
 CGFloat minX=safe.left+8,maxX=MAX(minX,bounds.size.width-safe.right-width-8),minY=safe.top+8,maxY=MAX(minY,bounds.size.height-safe.bottom-68);
 frame.origin.x=MIN(maxX,MAX(minX,frame.origin.x));frame.origin.y=MIN(maxY,MAX(minY,frame.origin.y));self.capsule.frame=frame;
 self.heading.frame=CGRectMake(25,9,width-37,20);self.detail.frame=CGRectMake(25,31,width-37,17);
}
- (void)pan:(UIPanGestureRecognizer *)gesture {
 CGPoint delta=[gesture translationInView:self.rootViewController.view];self.capsule.center=CGPointMake(self.capsule.center.x+delta.x,self.capsule.center.y+delta.y);[gesture setTranslation:CGPointZero inView:self.rootViewController.view];[self clampToSafeArea];
 if(gesture.state==UIGestureRecognizerStateEnded||gesture.state==UIGestureRecognizerStateCancelled){
  CGRect f=self.capsule.frame;UIEdgeInsets safe=self.safeAreaInsets;f.origin.x=CGRectGetMidX(f)<self.bounds.size.width/2?safe.left+8:self.bounds.size.width-safe.right-f.size.width-8;
  if(UIAccessibilityIsReduceMotionEnabled()){self.capsule.frame=f;return;}[UIView animateWithDuration:.18 animations:^{self.capsule.frame=f;}];
 }
}
- (void)openTapped {if(self.openChat)self.openChat();}
@end
