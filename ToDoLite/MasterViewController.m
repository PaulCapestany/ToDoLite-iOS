//
//  MasterViewController.m
//  ToDoLite
//
//  Created by Pasin Suriyentrakorn on 10/11/14.
//  Copyright (c) 2014 Pasin Suriyentrakorn. All rights reserved.
//

#import "MasterViewController.h"
#import "DetailViewController.h"
#import "AppDelegate.h"
#import "Profile.h"
#import "List.h"

static void *listsQueryContext = &listsQueryContext;

@interface MasterViewController () {
    CBLReplication *repl;
}

@property CBLDatabase *database;
@property CBLLiveQuery *liveQuery;
@property NSArray *listsResult;

@end

@implementation MasterViewController

- (void)awakeFromNib {
    [super awakeFromNib];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.preferredContentSize = CGSizeMake(320.0, 600.0);
    }
    
    // There is a bug in iOS8 UISplitViewController on iPads that doesn't set the main button item
    // correctly during its first display. A work would be manually setting the master
    // controller title here.
    self.title = @"ToDo Lists";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setup];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (!self.database) {
        [self setup];
    }
    
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    [app addObserver:self forKeyPath:@"database"
             options:(NSKeyValueObservingOptionNew |  NSKeyValueObservingOptionOld) context:nil];

    self.loginButton.title = [app isUserLoggedIn] ? @"Logout" : @"Login";

    NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
    if (selected) {
        [self.tableView deselectRowAtIndexPath:selected animated:NO];
    }
    
    repl = app.push;
    
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(reloadAfterPendingPush:)
                                                 name:kCBLReplicationChangeNotification object:repl];
}

- (void)viewWillDisappear:(BOOL)animated {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    [app removeObserver:self forKeyPath:@"database" context:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kCBLReplicationChangeNotification object:repl];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    [self.liveQuery removeObserver:self forKeyPath:@"rows" context:listsQueryContext];
}

-(void) reloadAfterPendingPush:(NSNotification *)notification {
    [self.tableView reloadData];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        CBLQueryRow *row = [self.listsResult objectAtIndex:indexPath.row];
        List *list = [List modelForDocument:row.document];
        
        DetailViewController *controller;
        if ([[segue destinationViewController] isKindOfClass:[UINavigationController class]]) {
            controller = (DetailViewController *)[[segue destinationViewController] topViewController];
        } else {
            controller = [segue destinationViewController];
        }
        
        if ([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] != NSOrderedAscending) {
            controller.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
            controller.navigationItem.leftItemsSupplementBackButton = YES;
        } else {
            // For iOS7, Setting the display mode is done in DetailViewController.setList: method.
        }
        
        controller.list = list;
    }
}

#pragma mark - Buttons

- (IBAction)addButtonAction:(id)sender {
    UIAlertView* alert= [[UIAlertView alloc] initWithTitle:@"New ToDo List"
                                                   message:@"Title for new list:"
                                                  delegate:self
                                         cancelButtonTitle:@"Cancel"
                                         otherButtonTitles:@"Create", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert show];
}

- (IBAction)loginButtonAction:(id)sender {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    if ([app isUserLoggedIn]) {
        [app logout];
    } else {
        [app loginWithFacebook:^(BOOL success, NSError *error) {
            if (success) {
                self.loginButton.title = @"Logout";
            } else {
                [app showMessage:@"Facebook Login Error. Please try again." withTitle:@"Error"];
            }
        }];
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alert didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex > 0) {
        NSString* title = [alert textFieldAtIndex:0].text;
        if (title.length > 0) {
            [self createListWithTitle:title];
        }
    }
}

#pragma mark - Table View Datasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.listsResult.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"List" forIndexPath:indexPath];
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    CBLQueryRow* row = [self.listsResult objectAtIndex:indexPath.row];
    cell.textLabel.text = [row.document propertyForKey:@"title"];
    
    int64_t delay = 1.5;
    // avoid having all text start gray only to immediately turn black (otherwise there is a flicker effect that users might think is a bug)
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC);
    dispatch_after(time, dispatch_get_main_queue(), ^(void){
        if ([repl isDocumentPending:row.document]) {
            cell.textLabel.textColor = [UIColor grayColor];
        } else {
            cell.textLabel.textColor = [UIColor blackColor];
        }
    });
    
    return cell;
}

#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        CBLQueryRow* row = [self.listsResult objectAtIndex:indexPath.row];
        List *list = [List modelForDocument:row.document];
        [list deleteList:nil];
    }
}

#pragma mark - Observers

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    if (object == app && [keyPath isEqual:@"database"]) {
        [self setup];
    }
    if (context == listsQueryContext) {
        self.listsResult = self.liveQuery.rows.allObjects;
        [self.tableView reloadData];
    }
}

#pragma mark - Database

// In this View Controller, we show an example of a Live Query
// and KVO to update the Table View accordingly when data changed.
// See DetailViewController and ShareViewController for
// examples of a Live Query used with the CBLUITableSource api.
- (void)setup {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    self.database = app.database;
    
    [self.liveQuery removeObserver:self forKeyPath:@"rows" context:listsQueryContext];
    if (self.database != nil) {
        self.liveQuery = [List queryListsInDatabase:self.database].asLiveQuery;
        [self.liveQuery addObserver:self forKeyPath:@"rows" options:0 context:listsQueryContext];
    } else {
        self.liveQuery = nil;
    }
    
    [self.tableView reloadData];
}

- (List *)createListWithTitle:(NSString*)title {
    List *list = [List modelForNewDocumentInDatabase:self.database];
    list.title = title;
    
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    NSString *currentUserId = app.currentUserId;
    if (currentUserId) {
        Profile *owner = [Profile profileInDatabase:self.database forExistingUserId:currentUserId];
        list.owner = owner;
    }
    
    NSError *error;
    if (![list save:&error]) {
        [app showMessage:@"Cannot create a new list" withTitle:@"Error"];
        return nil;
    }
    
    return list;
}

@end
