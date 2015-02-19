//
//  MacViewController.m
//  MultipeerConnectivityRemote
//
//  Created by Nick Kuh on 19/02/2015.
//  Copyright (c) 2015 Mumbo Apps Ltd. All rights reserved.
//

#import "MacViewController.h"
#import "MultipeerConnectivityRemote.h"

@interface MacViewController ()

@end

@implementation MacViewController

-(void) setup
{
    [MultipeerConnectivityRemote shared].serviceType = @"myapp-service";
    [MultipeerConnectivityRemote shared].isAdvertisingAndBrowsing = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotificationMultipeerConnectivityReceivedInvitationFromARemoteDevice:) name:NotificationMultipeerConnectivityReceivedInvitationFromARemoteDevice object:[MultipeerConnectivityRemote shared]];
    
}

-(id) initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self setup];
    }
    return self;
}

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}


#pragma mark Notification Handlers

-(void) handleNotificationMultipeerConnectivityReceivedInvitationFromARemoteDevice:(NSNotification *)notification
{
    NSAlert *alert = [[NSAlert alloc] init];
   // alert.alertStyle = NSWarningAlertStyle;
    alert.messageText = [NSString stringWithFormat:@"%@", notification.userInfo[@"invitationMessage"]];
    
    
    [alert addButtonWithTitle:@"Allow"];
    [alert addButtonWithTitle:@"Ignore"];
    
    __block NSString *inviteID = notification.userInfo[@"inviteID"];
    
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if( returnCode > 1000 ) {
            NSLog(@"Ignore");
            [[MultipeerConnectivityRemote shared] respondToInvite:inviteID accept:NO];
        }
        else {
            NSLog(@"Allow");
            [[MultipeerConnectivityRemote shared] respondToInvite:inviteID accept:YES];
        }
    }];

}

@end
