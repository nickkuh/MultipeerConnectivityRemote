//
//  AvailableDevicesViewController.m
//  MultipeerConnectivityRemote
//
//  Created by Nick Kuh on 19/02/2015.
//  Copyright (c) 2015 Mumbo Apps Ltd. All rights reserved.
//

#import "AvailableDevicesViewController.h"
#import "MultipeerConnectivityRemote.h"

@interface AvailableDevicesViewController ()<UIAlertViewDelegate, UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSMutableDictionary *responses;
@property (weak, nonatomic) IBOutlet UISwitch *advertisingSwitch;
@property (weak, nonatomic) IBOutlet UIView *noPeersView;


@end

static int tag = 1;

@implementation AvailableDevicesViewController

-(void)setup
{
    //NotificationMultipeerConnectivityActivePeersChanged
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotificationMultipeerConnectivityActivePeersChanged:) name:NotificationMultipeerConnectivityActivePeersChanged object:[MultipeerConnectivityRemote shared]];
    
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotificationMultipeerConnectivityReceivedInvitationFromARemoteDevice:) name:NotificationMultipeerConnectivityReceivedInvitationFromARemoteDevice object:[MultipeerConnectivityRemote shared]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotificationMultipeerConnectivityReceivedInfoFromAConnectedRemoteDevice:) name:NotificationMultipeerConnectivityReceivedInfoFromAConnectedRemoteDevice object:[MultipeerConnectivityRemote shared]];
    
   //[MultipeerConnectivityRemote shared].serviceType = @"myapp-service";
    [MultipeerConnectivityRemote shared].serviceType = @"silverback";
    [MultipeerConnectivityRemote shared].isAdvertising =  [MultipeerConnectivityRemote shared].isBrowsing = YES;//Start browsing and advertising...
    
    self.responses = [NSMutableDictionary new];
}

-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
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


-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.advertisingSwitch.on = [MultipeerConnectivityRemote shared].isAdvertising;
}

-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reloadData];
}

- (IBAction)switchToggled:(id)sender {
    [MultipeerConnectivityRemote shared].isAdvertising = self.advertisingSwitch.on;
}

- (IBAction)refreshTapped:(id)sender {
    BOOL advertisingBefore = [MultipeerConnectivityRemote shared].isAdvertising;
    BOOL browsingBefore = [MultipeerConnectivityRemote shared].isBrowsing;
    
    [MultipeerConnectivityRemote shared].isAdvertising = [MultipeerConnectivityRemote shared].isBrowsing = NO;
    
    [MultipeerConnectivityRemote shared].isAdvertising = advertisingBefore;
    [MultipeerConnectivityRemote shared].isBrowsing = browsingBefore;
    
}

-(void)reloadData
{
   
    BOOL hasActivePeers = [MultipeerConnectivityRemote shared].activePeers.count > 0;
    
    if(hasActivePeers) {
        [self.tableView reloadData];
    }
    
    self.tableView.hidden = !hasActivePeers;
    self.noPeersView.hidden = hasActivePeers;
    
    

}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [MultipeerConnectivityRemote shared].activePeers.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
    MCPeerID *peerID = [MultipeerConnectivityRemote shared].activePeers[indexPath.row];
    cell.textLabel.text = peerID.displayName;
    
    if ([[MultipeerConnectivityRemote shared] hasConnectedSessionForPeer:peerID]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.accessoryView = nil;
    }
    else {
        //either inviting or not connected
        if ([[MultipeerConnectivityRemote shared] isAwaitingInviteResponseForPeer:peerID]) {
            cell.accessoryType = UITableViewCellAccessoryNone;
            
            UIActivityIndicatorView *av = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            [av startAnimating];
            cell.accessoryView = av;
        }
        else {
            //Available to connect
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    MCPeerID *peerID = [MultipeerConnectivityRemote shared].activePeers[indexPath.row];
    
    if ([[MultipeerConnectivityRemote shared] hasConnectedSessionForPeer:peerID]) {
        [[MultipeerConnectivityRemote shared] sendInfo:@{@"m":@"Pong!"} toPeer:peerID];
    }
    else if (![[MultipeerConnectivityRemote shared] isAwaitingInviteResponseForPeer:peerID]) {
        
        __weak AvailableDevicesViewController *weakSelf = self;
        
        [[MultipeerConnectivityRemote shared] invitePeer:peerID invitationMessage:[NSString stringWithFormat:@"Allow %@  to remote control your device?",[MultipeerConnectivityRemote shared].displayName] connectionBlock:^(BOOL connected) {
            if (connected) {
                NSLog(@"Accepted & connected!");
            }
            else {
                NSLog(@"Failed to connect!");
            }
            [weakSelf reloadData];
        }];
        
        [weakSelf.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

#pragma mark Notification Handlers

-(void) handleNotificationMultipeerConnectivityActivePeersChanged:(NSNotification *)notification
{
    [self reloadData];
}

-(void) handleNotificationMultipeerConnectivityReceivedInvitationFromARemoteDevice:(NSNotification *)notification
{
    
    
    MCPeerID *peerID = notification.userInfo[@"peerID"];
    NSString *inviteID = notification.userInfo[@"inviteID"];
    
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"" message:[NSString stringWithFormat:@"%@", notification.userInfo[@"invitationMessage"]] delegate:self cancelButtonTitle:@"Ignore" otherButtonTitles:@"Allow", nil];
    av.delegate = self;
    [av show];
    av.tag = tag;
    
    self.responses[@(av.tag)] = @{@"type":@"invite",@"peerID":peerID,@"inviteID":inviteID};
    
    tag++;
    
}

-(void) handleNotificationMultipeerConnectivityReceivedInfoFromAConnectedRemoteDevice:(NSNotification *)notification
{
    
    NSDictionary *info = notification.userInfo[@"info"];
    
    MCPeerID *peerID = notification.userInfo[@"peerID"];
    
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Info Received from %@", peerID.displayName] message:[NSString stringWithFormat:@"%@", info[@"m"]] delegate:nil cancelButtonTitle:@"Done" otherButtonTitles:@"Send Pong!", nil];
    av.delegate = self;
    [av show];
    av.tag = tag;
    
    self.responses[@(av.tag)] = @{@"type":@"info",@"peerID":peerID,@"info":@{@"m":@"Pong!"}};
    
    tag++;
   
    
    
    
}

#pragma mark UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView.tag > 0) {
        NSDictionary *dict = self.responses[@(alertView.tag)];
        [self.responses removeObjectForKey:@(alertView.tag)];
         MCPeerID *peerID = dict[@"peerID"];
        
        NSString *type = dict[@"type"];
        
        
        if ([type isEqualToString:@"invite"]) {
            BOOL accepted = buttonIndex != alertView.cancelButtonIndex;
            NSString *inviteID = dict[@"inviteID"];
            if (accepted) {
                
                __weak AvailableDevicesViewController *weakSelf = self;
                
                [[MultipeerConnectivityRemote shared] respondToInvite:inviteID fromPeer:peerID accept:YES connectionBlock:^(BOOL connected) {
                    if (connected) {
                        [weakSelf reloadData];
                        NSLog(@"We are now being controlled by a remote: %@",peerID.displayName);
                        NSLog(@"Send back some initial syncronisation instruction?");
                        [[MultipeerConnectivityRemote shared] sendInfo:@{@"m":@"Welcome, you've connected successfully - what do you want me to do?!"} toPeer:peerID];
                    }
                }];
            }
            else {
                [[MultipeerConnectivityRemote shared] respondToInvite:inviteID fromPeer:peerID accept:NO connectionBlock:nil];
            }
        }
        if ([type isEqualToString:@"info"]) {
            if (buttonIndex != alertView.cancelButtonIndex) {
                if ([[MultipeerConnectivityRemote shared] hasConnectedSessionForPeer:peerID]) {
                    [[MultipeerConnectivityRemote shared] sendInfo:dict[@"info"] toPeer:peerID];
                }
            }
           
        }
        
        
    }
}

@end
