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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotificationMultipeerConnectivityReceivedInfoFromAConnectedRemoteDevice:) name:NotificationMultipeerConnectivityReceivedInfoFromAConnectedRemoteDevice object:[MultipeerConnectivityRemote shared]];
    
    
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
    alert.messageText = [NSString stringWithFormat:@"%@", notification.userInfo[@"invitationMessage"]];
    
    
    [alert addButtonWithTitle:@"Allow"];
    [alert addButtonWithTitle:@"Ignore"];
    
    __block NSString *inviteID = notification.userInfo[@"inviteID"];
    __block MCPeerID *peerID = notification.userInfo[@"peerID"];
    
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if( returnCode > 1000 ) {
            NSLog(@"Ignore");
            [[MultipeerConnectivityRemote shared] respondToInvite:inviteID fromPeer:peerID accept:NO connectionBlock:nil];
        }
        else {
            NSLog(@"Allow");
             [[MultipeerConnectivityRemote shared] respondToInvite:inviteID fromPeer:peerID accept:YES connectionBlock:^(BOOL connected) {
                 if (connected) {
                     NSLog(@"We are now being controlled by a remote: %@",peerID.displayName);
                     NSLog(@"Send back some initial syncronisation instruction?");
                     [[MultipeerConnectivityRemote shared] sendInfo:@{@"m":@"Welcome, you've connected successfully - what do you want me to do?!"} toPeer:peerID];
                 }
             }];
        }
    }];

}

-(void) handleNotificationMultipeerConnectivityReceivedInfoFromAConnectedRemoteDevice:(NSNotification *)notification
{
    NSAlert *alert = [[NSAlert alloc] init];
    
    NSDictionary *info = notification.userInfo[@"info"];
    
    __block MCPeerID *peerID = notification.userInfo[@"peerID"];
    
    alert.messageText = [NSString stringWithFormat:@"Info Received from %@", peerID.displayName];
    alert.informativeText = [NSString stringWithFormat:@"%@", info[@"m"]];
    
    [alert addButtonWithTitle:@"Send Ping!"];
    [alert addButtonWithTitle:@"Done"];
    
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if( returnCode > 1000 ) {
        
        }
        else {
           [[MultipeerConnectivityRemote shared] sendInfo:@{@"m":@"Ping!"} toPeer:peerID];
        }
        
    }];
    
}



@end
