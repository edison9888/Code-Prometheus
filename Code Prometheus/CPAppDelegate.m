//
//  CPAppDelegate.m
//  Code Prometheus
//
//  Created by mirror on 13-8-6.
//  Copyright (c) 2013年 Mirror. All rights reserved.
//

#import "CPAppDelegate.h"
#import "LKDBHelper.h"
#import "CPDB.h"
#import <MAMapKit/MAMapKit.h>
#import "CPServer.h"
#import "CPLocalNotificationManager.h"
#import <EAIntroView.h>


#warning 如果切到后台,继续同步！
@interface CPAppDelegate()<EAIntroDelegate>

@end

@implementation CPAppDelegate

#pragma mark - 生命周期

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // 日志
    [[CPLog sharedLog] prepareLog];
    
    CPLogInfo(@"%s",__FUNCTION__);
    
    // 记录首次启动
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"everLaunched"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"everLaunched"];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"firstLaunch"];
    }else{
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"firstLaunch"];
    }
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"firstLaunch"]) {
        CPLogInfo(@"第一次启动应用");
        CPLogInfo(@"初始化 License");
        CPSetMemberLicense([[NSDate date] timeIntervalSince1970]+2592000);
    }
    
    // 创建数据库
    [CPDB creatDBIfNotExist];
    
    // 地图
    [MAMapServices sharedServices].apiKey = (NSString *)MapAPIKey;
    
    // 推送
#warning 开发版需要更改推送方式
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert];
    NSDictionary* payload = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if (payload)
    {
        CPLogInfo(@"应用启动前,收到了推送:%@",payload);
        [self application:application didReceiveRemoteNotification:payload];
    }
    
    // 状态栏颜色
    if (CP_IS_IOS7_AND_UP) {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    }
    
    return YES;
}
- (void)applicationWillTerminate:(UIApplication *)application
{
    CPLogInfo(@"%s",__FUNCTION__);
}
- (void)applicationDidBecomeActive:(UIApplication *)application{
    CPLogInfo(@"%s",__FUNCTION__);

    [[CPLocalNotificationManager shared] down];
    
    [CPServer loginAutoWithBlock:^(BOOL success,NSString* message) {
        [CPServer checkLicenseBlock:^(BOOL success, NSString *message,NSTimeInterval expirationDate) {
            if (success) {
                if (!CPMemberLicense || CPMemberLicense != expirationDate) {
                    CPLogInfo(@"更新 license :%@->%@",[NSDate dateWithTimeIntervalSince1970:CPMemberLicense],[NSDate dateWithTimeIntervalSince1970:expirationDate]);
                    CPSetMemberLicense(expirationDate);
                }else{
                    CPLogVerbose(@"不用更新 license %@",[NSDate dateWithTimeIntervalSince1970:CPMemberLicense]);
                }
            }else{
                CPLogWarn(@"check lisence 失败:%@",message);
            }
        }];
        if (success) {
            [CPServer sync];
        }
    }];
    
    
    // 引导页
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"hasIntroduction"]) {
        
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"hasIntroduction"];
        
        EAIntroPage *page1 = [EAIntroPage pageWithCustomView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro_01"]]];
        
        EAIntroPage *page2 = [EAIntroPage pageWithCustomView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro_02"]]];
        
        EAIntroPage *page3 = [EAIntroPage pageWithCustomView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro_03"]]];
        
        EAIntroPage *page4 = [EAIntroPage pageWithCustomView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro_04"]]];
        
        EAIntroView *intro = [[EAIntroView alloc] initWithFrame:self.window.bounds andPages:@[page1,page2,page3,page4]];
        intro.pageControl.pageIndicatorTintColor = [UIColor colorWithRed:204/255.0 green:204/255.0 blue:204/255.0 alpha:1];
        intro.pageControl.currentPageIndicatorTintColor = [UIColor colorWithRed:95/255.0 green:206/255.0 blue:200/255.0 alpha:1];
        intro.pageControlY = 20;
        
        intro.skipButton = nil;
        [intro setDelegate:self];
        [intro showInView:self.window animateDuration:0.0];
    }
}
- (void)applicationWillResignActive:(UIApplication *)application{
    CPLogInfo(@"%s",__FUNCTION__);
    [[CPLocalNotificationManager shared] fire];
}

-(void)applicationWillEnterForeground:(UIApplication *)application{
    CPLogInfo(@"%s",__FUNCTION__);
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    CPLogInfo(@"%s",__FUNCTION__);
//    // 后台运行
//    UIApplication* app = [UIApplication sharedApplication];
//    CPLogWarn(@"进入后台运行模式,剩余时间:%f",[app backgroundTimeRemaining]);
//    __block UIBackgroundTaskIdentifier task = [app beginBackgroundTaskWithExpirationHandler:^{
//        CPLogWarn(@"后台运行,剩余时间结束!,剩余时间:%f",[app backgroundTimeRemaining]);
//        [app endBackgroundTask:task];
//        task = UIBackgroundTaskInvalid;
//    }];
}


#pragma mark - 远程推送
- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
    CPLogInfo(@"%s",__FUNCTION__);
    const unsigned *tokenBytes = [deviceToken bytes];
    NSString *hexToken = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x",
                          ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]),
                          ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]),
                          ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];
    
    CPLogInfo(@"获取到 token : %@", hexToken);
    [CPServer pushToken:hexToken withBlock:^(BOOL success) {
    }];
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
    CPLogInfo(@"%s",__FUNCTION__);
    CPLogError(@"获取推送 token 失败, error: %@", error);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo{
    CPLogInfo(@"%s",__FUNCTION__);
    CPLogInfo(@"获取到远程推送消息:%@",userInfo);
//    if ([[userInfo objectForKey:@"aps"] objectForKey:@"alert"]!=NULL) {
//        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"推送通知"
//                                                       message:[[userInfo objectForKey:@"aps"] objectForKey:@"alert"]
//                                                      delegate:self
//                                             cancelButtonTitle:@" 关闭"
//                                             otherButtonTitles:@" 更新状态",nil];
//        [alert show];
//    }
}

#pragma mark - 本地推送
- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification{
    CPLogInfo(@"%s",__FUNCTION__);
    CPLogInfo(@"获取到本地推送消息:%@",notification);
}

#pragma mark - Open URL
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    CPLogInfo(@"%s",__FUNCTION__);
    CPLogVerbose(@"Handle Open URL:%@",url);
    [[NSNotificationCenter defaultCenter] postNotificationName:CP_HANDLE_OPEN_URL_Notification object:url userInfo:nil];
	return YES;
}

//#pragma mark - EAIntroDelegate
//- (void)introDidFinish:(EAIntroView *)introView {
//    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"hasIntroduction"];
//}
@end
