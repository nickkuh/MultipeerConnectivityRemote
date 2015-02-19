//
//  AvailableDevicesViewController.m
//  MultipeerConnectivityRemote
//
//  Created by Nick Kuh on 19/02/2015.
//  Copyright (c) 2015 Mumbo Apps Ltd. All rights reserved.
//

#import "AvailableDevicesViewController.h"
#import "MultipeerConnectivityRemote.h"

@interface AvailableDevicesViewController ()

@end

@implementation AvailableDevicesViewController

-(void)setup
{
    //NotificationMultipeerConnectivityActivePeersChanged
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotificationMultipeerConnectivityActivePeersChanged:) name:NotificationMultipeerConnectivityActivePeersChanged object:[MultipeerConnectivityRemote shared]];
   [MultipeerConnectivityRemote shared].serviceType = @"myapp-service";
    [MultipeerConnectivityRemote shared].isAdvertisingAndBrowsing = YES;//Start browsing and advertising...
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

-(id) initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
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
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
        cell.detailTextLabel.text = @"Connected";
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.accessoryView = nil;
    }
    else {
        //either inviting or not connected
        if ([[MultipeerConnectivityRemote shared] isAwaitingInviteResponseForPeer:peerID]) {
            cell.detailTextLabel.text = @"";
            cell.accessoryType = UITableViewCellAccessoryNone;
            
            UIActivityIndicatorView *av = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            [av startAnimating];
            cell.accessoryView = av;
        }
        else {
            //Available to connect
            cell.detailTextLabel.text = @"Connect";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    MCPeerID *peerID = [MultipeerConnectivityRemote shared].activePeers[indexPath.row];
    
    if (![[MultipeerConnectivityRemote shared] hasConnectedSessionForPeer:peerID] && ![[MultipeerConnectivityRemote shared] isAwaitingInviteResponseForPeer:peerID]) {
        
        __weak AvailableDevicesViewController *weakSelf = self;
        
        [[MultipeerConnectivityRemote shared] invitePeer:peerID invitationMessage:[NSString stringWithFormat:@"Allow %@  to remote control your device?",[MultipeerConnectivityRemote shared].displayName] responseBlock:^(BOOL accepted) {
            if (accepted) {
                NSLog(@"Accepted & connected!");
            }
            else {
                NSLog(@"Failed to connect!");
            }
            [weakSelf.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }];
        
        [weakSelf.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

#pragma mark Notification Handlers

-(void) handleNotificationMultipeerConnectivityActivePeersChanged:(NSNotification *)notification
{
    [self.tableView reloadData];
}

@end
