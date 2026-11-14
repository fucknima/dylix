// Same list/navigation objects survive collapse and expansion; drafts stay alive.
@interface UIViewController (TFWorkspaceSaveContract)
- (BOOL)save;
@end
@interface TFWorkspaceSplit : UISplitViewController <UISplitViewControllerDelegate>
@property UINavigationController *listNavigation,*detailNavigation;
@property BOOL transferring;
@property UIViewController *placeholder;
@property (weak) UIViewController *returnButtonOwner;
@property UIBarButtonItem *returnHomeButton;
- (void)updateReturnHomeButton:(BOOL)needed;
@end
@interface TFWorkspaceListNavigation : TMCNavigationController
@property(weak) TFWorkspaceSplit *workspaceSplit;
@end
@implementation TFWorkspaceListNavigation
- (void)pushViewController:(UIViewController *)controller animated:(BOOL)animated{TFWorkspaceSplit *split=self.workspaceSplit;if(split&&!split.collapsed&&split.traitCollection.horizontalSizeClass==UIUserInterfaceSizeClassRegular&&!split.transferring&&self.viewControllers.count==1){UIViewController *current=split.detailNavigation.topViewController;if([current respondsToSelector:@selector(save)]&&![(id)current save])return;[split.detailNavigation setViewControllers:@[controller] animated:NO];return;}[super pushViewController:controller animated:animated];}
@end
@implementation TFWorkspaceSplit
- (void)returnToWorkspaceHome{UIViewController *current=self.detailNavigation.topViewController;if([current respondsToSelector:@selector(save)]&&![(id)current save])return;[self.detailNavigation setViewControllers:@[self.placeholder] animated:NO];}
- (void)updateReturnHomeButton:(BOOL)needed{
 UIViewController *target=needed&&!self.collapsed?self.detailNavigation.viewControllers.firstObject:nil;if(target==self.placeholder)target=nil;
 if(self.returnButtonOwner!=target){if(self.returnButtonOwner){NSMutableArray *items=[self.returnButtonOwner.navigationItem.leftBarButtonItems mutableCopy];[items removeObject:self.returnHomeButton];self.returnButtonOwner.navigationItem.leftBarButtonItems=items;}self.returnButtonOwner=target;}
 if(target){if(!self.returnHomeButton){self.returnHomeButton=[[UIBarButtonItem alloc]initWithTitle:@"主页" style:UIBarButtonItemStylePlain target:self action:@selector(returnToWorkspaceHome)];self.returnHomeButton.accessibilityLabel=@"返回主页并显示底部导航栏";}NSMutableArray *items=[target.navigationItem.leftBarButtonItems mutableCopy]?:[NSMutableArray new];if(![items containsObject:self.returnHomeButton]){[items insertObject:self.returnHomeButton atIndex:0];target.navigationItem.leftBarButtonItems=items;}}
}
- (instancetype)initWithList:(UINavigationController *)list{if((self=[super initWithStyle:UISplitViewControllerStyleDoubleColumn])){self.delegate=self;self.listNavigation=list;self.detailNavigation=[[TMCNavigationController alloc]init];((TFWorkspaceListNavigation *)list).workspaceSplit=self;UIViewController *empty=[UIViewController new];self.placeholder=empty;empty.title=@"工作台";empty.view.backgroundColor=UIColor.systemBackgroundColor;UILabel *hint=[UILabel new];hint.text=@"从左侧选择项目或会话";hint.textColor=UIColor.secondaryLabelColor;hint.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];hint.translatesAutoresizingMaskIntoConstraints=NO;[empty.view addSubview:hint];[NSLayoutConstraint activateConstraints:@[[hint.centerXAnchor constraintEqualToAnchor:empty.view.centerXAnchor],[hint.centerYAnchor constraintEqualToAnchor:empty.view.centerYAnchor]]];self.detailNavigation.viewControllers=@[empty];self.preferredDisplayMode=UISplitViewControllerDisplayModeOneBesideSecondary;self.preferredSplitBehavior=UISplitViewControllerSplitBehaviorTile;self.minimumPrimaryColumnWidth=280;self.maximumPrimaryColumnWidth=360;self.preferredPrimaryColumnWidthFraction=.28;[self setViewController:list forColumn:UISplitViewControllerColumnPrimary];[self setViewController:self.detailNavigation forColumn:UISplitViewControllerColumnSecondary];}return self;}
- (UISplitViewControllerColumn)splitViewController:(UISplitViewController *)split topColumnForCollapsingToProposedTopColumn:(UISplitViewControllerColumn)proposed{self.transferring=YES;NSArray *detail=self.detailNavigation.viewControllers;if(detail.count&&detail.firstObject!=self.placeholder){NSMutableArray *stack=[self.listNavigation.viewControllers mutableCopy];[self.detailNavigation setViewControllers:@[] animated:NO];[stack addObjectsFromArray:detail];[self.listNavigation setViewControllers:stack animated:NO];}self.transferring=NO;return UISplitViewControllerColumnPrimary;}
- (UISplitViewControllerDisplayMode)splitViewController:(UISplitViewController *)split displayModeForExpandingToProposedDisplayMode:(UISplitViewControllerDisplayMode)proposed{self.transferring=YES;NSArray *stack=self.listNavigation.viewControllers;if(stack.count>1){NSArray *detail=[stack subarrayWithRange:NSMakeRange(1,stack.count-1)];[self.listNavigation setViewControllers:@[stack.firstObject] animated:NO];[self.detailNavigation setViewControllers:detail animated:NO];}else if(!self.detailNavigation.viewControllers.count)[self.detailNavigation setViewControllers:@[self.placeholder] animated:NO];self.transferring=NO;return UISplitViewControllerDisplayModeOneBesideSecondary;}
@end
static UIViewController *TFAdaptiveWorkspace(UINavigationController *navigation){TFWorkspaceSplit *split=[[TFWorkspaceSplit alloc]initWithList:navigation];split.tabBarItem=navigation.tabBarItem;return split;}
static UINavigationController *TFWorkspaceNavigation(UIViewController *controller){if([controller isKindOfClass:TFWorkspaceSplit.class])return ((TFWorkspaceSplit *)controller).listNavigation;return [controller isKindOfClass:UINavigationController.class]?(id)controller:controller.navigationController;}
