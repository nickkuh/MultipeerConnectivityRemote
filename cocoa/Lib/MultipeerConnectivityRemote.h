//
//  MultipeerConnectivityRemote.h
//  MultipeerConnectivityRemote
//
//  Created by Nick Kuh on 19/02/2015.
//  Copyright (c) 2015 Mumbo Apps Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

#define NotificationMultipeerConnectivityActivePeersChanged                                 @"NotificationMultipeerConnectivityActivePeersChanged"
#define NotificationMultipeerConnectivityReceivedInvitationFromARemoteDevice                 @"NotificationMultipeerConnectivityReceivedInvitationFromARemoteDevice"

#define NotificationMultipeerConnectivityEvent                                              @"NotificationMultipeerConnectivityEvent"


@interface MultipeerConnectivityRemote : NSObject

+(MultipeerConnectivityRemote *)shared;

//The name that this device will be displayed as to other devices eg Nick's iPhone (automatically created)
@property (nonatomic, strong) NSString *displayName;

//A service name for your app - same string must be used for all devices that need to connect to one another
@property (nonatomic, strong) NSString *serviceType;

//Devices connect to one another by advertising and finding one another. isAdvertisingAndBrowsing needs to be true for this device to find others and let others know of it's existance
@property (nonatomic) BOOL isAdvertisingAndBrowsing;

//Lists all compatible MCPeerIDs detected in the network - some connected and some not connected
@property (nonatomic, strong, readonly) NSArray *activePeers;

//Checks if we have an active session with this peer
-(BOOL)hasConnectedSessionForPeer:(MCPeerID *)peerID;

//Awaiting invite response from peer - eg continue to show an activity indicator
-(BOOL)isAwaitingInviteResponseForPeer:(MCPeerID *)peerID;

//Invite is intended to be sent and will either be responded to by the recipient or time-out
//invitationMessage such as "Allow Nick's iPhone to remote control this device?"
-(void)invitePeer:(MCPeerID *)peerID invitationMessage:(NSString *)invitationMessage responseBlock:(void(^)(BOOL accepted))responseBlock;
-(void)respondToInvite:(NSString *)inviteID accept:(BOOL)accept;

@end
