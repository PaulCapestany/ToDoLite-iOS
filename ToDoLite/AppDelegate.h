//
//  AppDelegate.h
//  ToDoLite
//
//  Created by Pasin Suriyentrakorn on 10/11/14.
//  Copyright (c) 2014 Pasin Suriyentrakorn. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CouchbaseLite/CouchbaseLite.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic, readonly) CBLDatabase *database;

@property (nonatomic) CBLReplication *push;

@property (strong, nonatomic, readonly) NSString *currentUserId;

// For UISplitViewController
@property (readonly, strong, nonatomic) UIPopoverController *popoverController;

// For UISplitViewController (iOS7)
@property (readonly, strong, nonatomic) UIBarButtonItem *displayModeButtonItem;

- (void)loginAsGuest;

- (void)loginWithFacebook:(void (^)(BOOL success, NSError *error))result;

- (BOOL)isGuestLoggedIn;

- (BOOL)isUserLoggedIn;

- (void)logout;

- (void)showMessage:(NSString *)text withTitle:(NSString *)title;

- (void)replaceRootViewController:(UIViewController *)controller;

@end
