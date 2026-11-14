// Native progress treatment for the existing backup action; no synthetic percentages.
@interface DXBackupProgressButton : UIButton
@property CAShapeLayer *progressTrack,*progressStroke;
@property BOOL working,indeterminate;
@property double fraction;
- (void)showProgress:(double)fraction working:(BOOL)working indeterminate:(BOOL)indeterminate;
@end
@implementation DXBackupProgressButton
- (instancetype)initWithFrame:(CGRect)frame{if((self=[super initWithFrame:frame])){self.clipsToBounds=NO;self.progressTrack=[CAShapeLayer layer];self.progressStroke=[CAShapeLayer layer];for(CAShapeLayer *layer in @[self.progressTrack,self.progressStroke]){layer.fillColor=UIColor.clearColor.CGColor;layer.lineWidth=2.5;layer.lineCap=kCALineCapRound;[self.layer addSublayer:layer];}self.progressStroke.shadowRadius=5;self.progressStroke.shadowOpacity=.6;self.progressStroke.shadowOffset=CGSizeZero;}return self;}
- (void)tintColorDidChange{[super tintColorDidChange];[self setNeedsLayout];}
- (void)layoutSubviews{[super layoutSubviews];[CATransaction begin];[CATransaction setDisableActions:YES];UIBezierPath *path=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(self.bounds,-4,-4) cornerRadius:19];self.progressTrack.path=path.CGPath;self.progressStroke.path=path.CGPath;self.progressTrack.strokeColor=[self.tintColor colorWithAlphaComponent:.18].CGColor;self.progressStroke.strokeColor=self.tintColor.CGColor;self.progressStroke.shadowColor=self.tintColor.CGColor;[CATransaction commit];[self updateMotion];}
- (void)showProgress:(double)fraction working:(BOOL)working indeterminate:(BOOL)indeterminate{self.fraction=MAX(0,MIN(1,fraction));BOOL changed=self.working!=working||self.indeterminate!=indeterminate;self.working=working;self.indeterminate=indeterminate;[CATransaction begin];[CATransaction setDisableActions:YES];self.progressTrack.hidden=!working;self.progressStroke.hidden=!working;self.progressStroke.strokeEnd=indeterminate?1:self.fraction;[CATransaction commit];if(changed)[self.progressStroke removeAllAnimations];[self updateMotion];self.accessibilityValue=working?(indeterminate?@"正在准备":[NSString stringWithFormat:@"%.0f%%",self.fraction*100]):nil;}
- (void)updateMotion{if(!self.working||!self.indeterminate){self.progressStroke.lineDashPattern=nil;[self.progressStroke removeAnimationForKey:@"backup.orbit"];return;}CGFloat perimeter=2*(self.bounds.size.width+self.bounds.size.height+16-76)+2*M_PI*19;self.progressStroke.lineDashPattern=@[@(perimeter*.2),@(perimeter*.8)];if(UIAccessibilityIsReduceMotionEnabled()){[self.progressStroke removeAnimationForKey:@"backup.orbit"];return;}if(![self.progressStroke animationForKey:@"backup.orbit"]){CABasicAnimation *orbit=[CABasicAnimation animationWithKeyPath:@"lineDashPhase"];orbit.fromValue=@0;orbit.toValue=@(-perimeter);orbit.duration=1.7;orbit.repeatCount=HUGE_VALF;[self.progressStroke addAnimation:orbit forKey:@"backup.orbit"];}}
@end

// One shared inventory scan for repeated page visits; previews are never used as an export manifest.
static NSDictionary *DXInventoryPreview;
static NSTimeInterval DXInventoryDate;
static NSMutableArray *DXInventoryObservers;
static BOOL DXInventoryRunning;
static void DXLoadInventory(BOOL force,void(^changed)(NSDictionary *,BOOL,NSError *)){
 NSCAssert(NSThread.isMainThread,@"Inventory UI callbacks use main queue");
 if(!force&&DXInventoryPreview&&NSProcessInfo.processInfo.systemUptime-DXInventoryDate<30){changed(DXInventoryPreview,NO,nil);return;}
 if(!DXInventoryObservers)DXInventoryObservers=[NSMutableArray new];[DXInventoryObservers addObject:[changed copy]];changed(DXInventoryPreview,YES,nil);if(DXInventoryRunning)return;DXInventoryRunning=YES;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{NSError *error=nil;NSDictionary *estimate=DXBackupEstimateProgress(NSHomeDirectory(),[NSSet setWithArray:[DXBackupCategories() valueForKey:@"id"]],nil,^(NSDictionary *partial){dispatch_async(dispatch_get_main_queue(),^{for(void(^observer)(NSDictionary *,BOOL,NSError *) in DXInventoryObservers.copy)observer(partial,YES,nil);});},&error);dispatch_async(dispatch_get_main_queue(),^{if(estimate){DXInventoryPreview=estimate;DXInventoryDate=NSProcessInfo.processInfo.systemUptime;}DXInventoryRunning=NO;NSArray *observers=DXInventoryObservers.copy;[DXInventoryObservers removeAllObjects];for(void(^observer)(NSDictionary *,BOOL,NSError *) in observers)observer(estimate?:DXInventoryPreview,NO,error);});});
}
