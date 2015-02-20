//
//  MultipeerConnectivityRemote.m
//  MultipeerConnectivityRemote
//
//  Created by Nick Kuh on 19/02/2015.
//  Copyright (c) 2015 Mumbo Apps Ltd. All rights reserved.
//

#import "MultipeerConnectivityRemote.h"

#define kMyPeerIDKey @"kMyPeerIDKey"

@interface MultipeerConnectivityRemote()<MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, MCSessionDelegate>

@property (nonatomic, strong) NSMutableSet *activePeersSet;
@property (nonatomic, strong) NSMutableSet *invitingPeersSet;
@property (nonatomic, strong) NSMutableSet *connectedPeerRemotes;
@property (nonatomic, strong) NSMutableSet *connectedPeerRemoteRecipients;

@property (nonatomic, strong) MCNearbyServiceAdvertiser *advertiser;
@property (nonatomic, strong) MCSession *advertiserSession;
@property (nonatomic, strong) MCNearbyServiceBrowser *browser;
@property (nonatomic, strong) MCSession *browserSession;

@property (nonatomic, strong) MCPeerID *localPeerID;


@property (nonatomic, strong) NSMutableDictionary *peerIDHashToConnectionBlock;
@property (nonatomic, strong) NSMutableDictionary *invitationIDToInviteResponseBlock;


@end

@implementation MultipeerConnectivityRemote

+(MultipeerConnectivityRemote *)shared
{
    static MultipeerConnectivityRemote *_shared;
    if (_shared == nil) {
        _shared = [[MultipeerConnectivityRemote alloc] init];
    }
    return _shared;
}

#pragma mark Public API

-(NSArray *)activePeers
{
    NSArray *arr = [self.activePeersSet allObjects];
    NSSortDescriptor *nameDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"displayName" ascending:YES];
    return [arr sortedArrayUsingDescriptors:@[nameDescriptor]];
}

-(BOOL)hasConnectedSessionForPeer:(MCPeerID *)peerID
{
    return [self.connectedPeerRemotes containsObject:peerID] || [self.connectedPeerRemoteRecipients containsObject:peerID];
}

-(BOOL)isAwaitingInviteResponseForPeer:(MCPeerID *)peerID
{
    return [self.invitingPeersSet containsObject:peerID];
}

-(void)invitePeer:(MCPeerID *)peerID invitationMessage:(NSString *)invitationMessage connectionBlock:(void(^)(BOOL connected))connectionBlock
{
    
    if ([self isAwaitingInviteResponseForPeer:peerID]) {
        return;
    }
    
    
    if (connectionBlock) {
        self.peerIDHashToConnectionBlock[@(peerID.hash)] = connectionBlock;
    }
    
    [self.invitingPeersSet addObject:peerID];
    
    //[self.advertiser initWithPeer:peerID discoveryInfo:@{@"m":invitationMessage} serviceType:self.serviceType];
    
    NSData *data = [invitationMessage dataUsingEncoding:NSUTF8StringEncoding];
    
    [self.browser invitePeer:peerID toSession:self.browserSession withContext:data timeout:0];
    
}

-(void)respondToInvite:(NSString *)inviteID fromPeer:(MCPeerID *)peerID accept:(BOOL)accept connectionBlock:(void(^)(BOOL connected))connectionBlock
{
    if (accept && connectionBlock) {//if the receipient rejects the connection request then the connectionBlock will never get fired and so will be ignored here
        self.peerIDHashToConnectionBlock[@(peerID.hash)] = connectionBlock;
    }
    
    void (^invitationHandler)(BOOL accept, MCSession *session) = self.invitationIDToInviteResponseBlock[inviteID];
    
    invitationHandler(accept,self.advertiserSession);
    [self.invitationIDToInviteResponseBlock removeObjectForKey:inviteID];
}

-(void)sendInfo:(NSDictionary *)info toPeer:(MCPeerID *)peerID
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:info];
    
    NSArray *peers;
    
    if (peerID) {
         NSAssert([self hasConnectedSessionForPeer:peerID], @"Attempted to send data to a peer without a connected session");
        peers = @[peerID];
    }
    else {
        peers = [[self.connectedPeerRemotes allObjects] arrayByAddingObjectsFromArray:[self.connectedPeerRemoteRecipients allObjects]];
    }
    
    NSError *error = nil;
    
    MCSession *session = [self.connectedPeerRemotes containsObject:peerID] ? self.advertiserSession : self.browserSession;
    
    [session sendData:data toPeers:peers withMode:MCSessionSendDataReliable error:&error];
    
    if (error != nil) {
        NSLog(@"Error sending data to peers: %@",error);
    }
    
}

#pragma mark Private API

-(id) init
{
    self = [super init];
    if (self) {
        NSLog(@"MultipeerConnectivityRemote Created");
    }
    return self;
}

-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


-(void) setIsAdvertisingAndBrowsing:(BOOL)isAdvertisingAndBrowsing
{
    if (_isAdvertisingAndBrowsing == isAdvertisingAndBrowsing) {
        return;
    }
    
    _isAdvertisingAndBrowsing = isAdvertisingAndBrowsing;
    
    if (_isAdvertisingAndBrowsing) {
        [self.advertiser startAdvertisingPeer];
        [self.browser startBrowsingForPeers];
    }
    else {
        [self.browser stopBrowsingForPeers];
        [self.advertiser stopAdvertisingPeer];
        
        [self.activePeersSet removeAllObjects];
        [self notififyActivePeersChanged];
    }
}

-(void)notififyActivePeersChanged
{
    [[NSNotificationCenter defaultCenter] postNotificationName:NotificationMultipeerConnectivityActivePeersChanged object:self userInfo:nil];
}

-(NSString *)displayName
{
#if TARGET_OS_IPHONE
    return [[UIDevice currentDevice] name];
#else
    
    return [[NSHost currentHost] localizedName];
#endif
    
}



-(MCPeerID *)localPeerID
{
    if (_localPeerID == nil) {
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSData *peerIDData = [defaults dataForKey:kMyPeerIDKey];
        if (peerIDData) {
            //Deserialising the original peer id
            _localPeerID = [NSKeyedUnarchiver unarchiveObjectWithData:peerIDData];
        }
        else {
            _localPeerID = [[MCPeerID alloc] initWithDisplayName:[self displayName]];
           //Serialising the generated peer id;
            peerIDData = [NSKeyedArchiver archivedDataWithRootObject:_localPeerID];
            [defaults setObject:peerIDData forKey:kMyPeerIDKey];
            [defaults synchronize];
            
        }
        
    }
    return _localPeerID;
}


-(MCSession *) advertiserSession
{
    if (_advertiserSession == nil) {
        _advertiserSession = [[MCSession alloc] initWithPeer:self.localPeerID
                                            securityIdentity:nil
                                        encryptionPreference:MCEncryptionNone];
        _advertiserSession.delegate = self;
    }
    return _advertiserSession;
}

-(MCSession *) browserSession
{
    if (_browserSession == nil) {
        _browserSession = [[MCSession alloc] initWithPeer:self.localPeerID
                                         securityIdentity:nil
                                     encryptionPreference:MCEncryptionNone];
        _browserSession.delegate = self;
    }
    return _browserSession;
}


-(NSString *)serviceType
{
    if (_serviceType == nil) {
        _serviceType = @"mcremote-service";
    }
    
    return _serviceType;
}

-(MCNearbyServiceBrowser *)browser
{
    if (_browser == nil) {
        _browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.localPeerID serviceType:[self serviceType]];
        _browser.delegate = self;
    }
    return _browser;
}

-(MCNearbyServiceAdvertiser *)advertiser
{
    if (_advertiser == nil) {
        _advertiser =
        [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.localPeerID
                                          discoveryInfo:nil
                                            serviceType:[self serviceType]];
        _advertiser.delegate = self;
    }
    return _advertiser;
}

-(NSMutableSet *)activePeersSet
{
    if (_activePeersSet == nil) {
        _activePeersSet = [NSMutableSet new];
    }
    return _activePeersSet;
}

-(NSMutableSet *)connectedPeerRemotes
{
    if (_connectedPeerRemotes == nil) {
        _connectedPeerRemotes = [NSMutableSet new];
    }
    return _connectedPeerRemotes;
}

-(NSMutableSet *)connectedPeerRemoteRecipients
{
    if (_connectedPeerRemoteRecipients == nil) {
        _connectedPeerRemoteRecipients = [NSMutableSet new];
    }
    return _connectedPeerRemoteRecipients;
}

-(NSMutableSet *)invitingPeersSet
{
    if (_invitingPeersSet == nil) {
        _invitingPeersSet = [NSMutableSet new];
    }
    return _invitingPeersSet;
}



-(NSMutableDictionary *)peerIDHashToConnectionBlock
{
    if (_peerIDHashToConnectionBlock == nil) {
        _peerIDHashToConnectionBlock = [NSMutableDictionary new];
    }
    return _peerIDHashToConnectionBlock;
}

-(NSMutableDictionary *)invitationIDToInviteResponseBlock
{
    if (_invitationIDToInviteResponseBlock == nil) {
        _invitationIDToInviteResponseBlock = [NSMutableDictionary new];
    }
    return _invitationIDToInviteResponseBlock;
}


#pragma mark MCNearbyServiceBrowserDelegate

// Found a nearby advertising peer
- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info
{
    
    [self.activePeersSet addObject:peerID];
    [self notififyActivePeersChanged];
    
    [self shareEventMessage:[NSString stringWithFormat:@"foundPeer: %@",peerID.displayName]];
    

    
}

// A nearby peer has stopped advertising
- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
    [self.activePeersSet removeObject:peerID];
    [self notififyActivePeersChanged];
    
    [self shareEventMessage:[NSString stringWithFormat:@"lostPeer: %@",peerID.displayName]];
    
}

// Browsing did not start due to an error
- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error
{
    
    [self shareEventMessage:[NSString stringWithFormat:@"didNotStartBrowsingForPeers: %@",error]];
}

#pragma mark MCNearbyServiceAdvertiserDelegate

// Incoming invitation request.  Call the invitationHandler block with YES and a valid session to connect the inviting peer to the session.
- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void(^)(BOOL accept, MCSession *session))invitationHandler
{
    //NSLog(@"advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void(^)(BOOL accept, MCSession *session))invitationHandler");
    
    NSString *invitationMessage =
    [[NSString alloc] initWithData:context
                          encoding:NSUTF8StringEncoding];
    
    [self shareEventMessage:[NSString stringWithFormat:@"Received invite %@",invitationMessage]];
    
    NSString *uuid = [[NSUUID UUID] UUIDString];
    
    self.invitationIDToInviteResponseBlock[uuid] = invitationHandler;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NotificationMultipeerConnectivityReceivedInvitationFromARemoteDevice object:self userInfo:@{@"invitationMessage":invitationMessage,@"inviteID":uuid,@"peerID":peerID}];
    

}


// Advertising did not start due to an error
- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error
{
    NSLog(@"advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error");
}


#pragma mark MCSessionDelegate

-(void) shareEventMessage:(NSString *)message
{

    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"%@",message);
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NotificationMultipeerConnectivityEvent object:self userInfo:@{@"message":message}];
    });
}

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    // NSLog(@"session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state");
    
    switch (state) {
        case MCSessionStateConnecting:
            NSLog(@"Session Connecting....");
            break;
        case MCSessionStateConnected:
            // NSLog(@"Session Connected!");
            [self shareEventMessage:[NSString stringWithFormat:@"%@ connected",peerID.displayName]];
            [self handleSessionConnectionSucceeded:peerID isARemote:session==self.advertiserSession];
            break;
        case MCSessionStateNotConnected:
            [self shareEventMessage:[NSString stringWithFormat:@"%@ disconnected",peerID.displayName]];
            [self handleSessionConnectionFailed:peerID];

            break;
            
        default:
            break;
    }
    
}

-(void) handleSessionConnectionSucceeded:(MCPeerID *)peerID isARemote:(BOOL)isARemote {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        void (^connectionBlock)(BOOL accept) = self.peerIDHashToConnectionBlock[@(peerID.hash)];
        
        
        [self.invitingPeersSet removeObject:peerID];
        
        if (isARemote) {
            [self.connectedPeerRemotes addObject:peerID];
        }
        else {
            [self.connectedPeerRemoteRecipients addObject:peerID];
        }
  
        
        if (connectionBlock) {
            connectionBlock(YES);
            [self.peerIDHashToConnectionBlock removeObjectForKey:@(peerID.hash)];
        }
    });
    
    
    
    
}

-(void) handleSessionConnectionFailed:(MCPeerID *)peerID {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        void (^connectionBlock)(BOOL accept) = self.peerIDHashToConnectionBlock[@(peerID.hash)];
        
        
        [self.invitingPeersSet removeObject:peerID];
        
        
        if (connectionBlock) {
            connectionBlock(NO);
            [self.peerIDHashToConnectionBlock removeObjectForKey:@(peerID.hash)];
        }
    });

    
    
}


// Received data from remote peer
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *info = (NSDictionary*) [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        [self shareEventMessage:[NSString stringWithFormat:@"Received info from %@\n%@",peerID.displayName,info[@"m"]]];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NotificationMultipeerConnectivityReceivedInfoFromAConnectedRemoteDevice object:self userInfo:@{@"info":info,@"peerID":peerID}];
    });
    
    
    
}

// Received a byte stream from remote peer
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    NSLog(@"session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID");
}

// Start receiving a resource from remote peer
- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
    NSLog(@"session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress");
}

// Finished receiving a resource from remote peer and saved the content in a temporary location - the app is responsible for moving the file to a permanent location within its sandbox
- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
    NSLog(@"session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error");
}



@end
