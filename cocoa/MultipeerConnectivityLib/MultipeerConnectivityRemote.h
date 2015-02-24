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
#define NotificationMultipeerConnectivityReceivedInfoFromAConnectedRemoteDevice                       @"NotificationMultipeerConnectivityReceivedInfoFromAConnectedRemoteDevice"


#define NotificationMultipeerConnectivityEvent                                              @"NotificationMultipeerConnectivityEvent"




@interface MultipeerConnectivityRemote : NSObject

+(MultipeerConnectivityRemote *)shared;

//The name that this device will be displayed as to other devices eg Nick's iPhone (automatically created)
@property (nonatomic, strong) NSString *displayName;

//A service name for your app - same string must be used for all devices that need to connect to one another
@property (nonatomic, strong) NSString *serviceType;

//Devices connect to one another by advertising and finding one another. isAdvertisingAndBrowsing needs to be true for this device to find others and let others know of it's existance
@property (nonatomic) BOOL isAdvertising;
@property (nonatomic) BOOL isBrowsing;

//Lists all compatible MCPeerIDs detected in the network - some connected and some not connected
@property (nonatomic, strong, readonly) NSArray *activePeers;

//Checks if we have an active session with this peer
-(BOOL)hasConnectedSessionForPeer:(MCPeerID *)peerID;

//Awaiting invite response from peer - eg continue to show an activity indicator
-(BOOL)isAwaitingInviteResponseForPeer:(MCPeerID *)peerID;

//Invite is intended to be sent and will either be responded to by the recipient or time-out
//invitationMessage such as "Allow Nick's iPhone to remote control this device?"
//connectionBlock will be executed as soon as the connection completes or fails
-(void)invitePeer:(MCPeerID *)peerID invitationMessage:(NSString *)invitationMessage connectionBlock:(void(^)(BOOL connected))connectionBlock;

//When a Mac or iPhone receives a connection request from a remote it responds via this method
//If the receiving device chooses to reject the connection then the connectionBlock should be nil
//If the receiving device chooses to accept the connection then it can optionally pass in a connectionBlock in order to execute code
//like passing some initial data back to the remote once the connection establishes
-(void)respondToInvite:(NSString *)inviteID fromPeer:(MCPeerID *)peerID accept:(BOOL)accept connectionBlock:(void(^)(BOOL connected))connectionBlock;


//Both remotes and remotely controlled devices use this method to communicate custom data with other devices
//If a peerID is specified then only that peer will be send the info dictionary
//If nil is passed for peerID then all connected peers will be sent the info dictionary
-(void)sendInfo:(NSDictionary *)info toPeer:(MCPeerID *)peerID callbackBlock:(void(^)(BOOL succeeded, NSDictionary *responseInfo))callbackBlock;

//Device A can call Device B and get a callback. Device B responds via the respondToInfo:toPeer:infoID:
-(void)respondToInfo:(NSDictionary *)info toPeer:(MCPeerID *)peerID infoResponseID:(NSString *)infoResponseID;

@end
