//
//  RecordTableViewController.m
//  JsonParsing
//
//  Created by Joy on 01/05/16.
//  Copyright © 2016 Joy. All rights reserved.
//

#import "RecordTableViewController.h"
#import "ParseOperation.h"
#import "Record.h"
#import "ImageDownloader.h"

#define SYSTEM_VERSION_LESS_THAN(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)


static NSString *const jsonFeed = @"https://dl.dropboxusercontent.com/u/746330/facts.json";
static NSString *const CellIdentifier = @"RecordCell";

@interface RecordTableViewController ()
// the queue to run our "ParseOperation"
@property (nonatomic, strong) NSOperationQueue *queue;

// the NSOperation driving the parsing of the RSS feed
@property (nonatomic, strong) ParseOperation *parser;

// the set of ImageDownloader objects for each record
@property (nonatomic, strong) NSMutableDictionary *imageDownloadsInProgress;




@end

@implementation RecordTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    self.imageDownloadsInProgress = [NSMutableDictionary dictionary];
    
    // Setting up the TableView
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.showsHorizontalScrollIndicator = NO;
   
    self.tableView.estimatedRowHeight = 200.0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    self.tableView.contentInset = UIEdgeInsetsMake(10,0,0,0);
    if ([self.tableView respondsToSelector:@selector(setSeparatorInset:)]) {
        [self.tableView setSeparatorInset:UIEdgeInsetsZero];
    }
    
    // Adding Pull to Refresh
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.tableView addSubview:self.refreshControl];
    [self.refreshControl addTarget:self action:@selector(refreshTable) forControlEvents:UIControlEventValueChanged];

}

- (void) viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    // fetch result set
    [self populateRecords];
}

- (void)viewDidDisappear:(BOOL)animated {
    [self terminateAllDownloads];
    [super viewDidDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


// -------------------------------------------------------------------------------
//	populateRecords
//  Populate a set of records from the given JSON url and reload the tableView afterwards
// -------------------------------------------------------------------------------
- (void)populateRecords {
    
    __block BOOL isFailured = NO;
    
    // show in the status bar that network activity is starting
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:jsonFeed]];
    
    NSURLSessionDataTask *session = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (error == nil) {
            
            
            
            // create the queue to run our ParseOperation
            self.queue = [[NSOperationQueue alloc] init];
            
            // create an ParseOperation (NSOperation subclass) to parse the RSS feed data so that the UI is not blocked
            _parser = [[ParseOperation alloc] initWithData:data];
            
            __weak RecordTableViewController *weakSelf = self;
            
            self.parser.errorHandler = ^(NSError *parseError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                    [weakSelf showFailureAlert:parseError];
                });
            };
            
            // referencing parser from within its completionBlock would create a retain cycle
            __weak ParseOperation *weakParser = self.parser;
            
            self.parser.completionBlock = ^(void) {
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                if (weakParser.recordList != nil)
                {
                    _mArrRecords = weakParser.recordList;
                    // The completion block may execute on any thread.  Because operations
                    // involving the UI are about to be performed, make sure they execute on the main thread.
                    //
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        // tell our table view to reload its data, now that parsing has completed
                        [weakSelf setTitle:(weakParser.feedTitle)?weakParser.feedTitle:@""];
                        
                        [weakSelf.tableView beginUpdates];
                        [weakSelf.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
                        [weakSelf.tableView endUpdates];
                    });
                }
                
                // we are finished with the queue and our ParseOperation
                weakSelf.queue = nil;
            };
            
            [self.queue addOperation:self.parser]; // this will start the "ParseOperation"
        
        }
        else {
            isFailured = YES;
        }
        
        if (isFailured) {
            [[NSOperationQueue mainQueue] addOperationWithBlock: ^{
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                [self showFailureAlert:error];
            }];
        }
    }];
    [session resume];
}

- (void)showFailureAlert:(NSError *)error {
    NSString *errorMessage = [error localizedDescription];

    if(SYSTEM_VERSION_LESS_THAN(@"8.0")){
        UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:@"Unable To Show Data" message:errorMessage delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [alertView show];
    }
    else {
        // alert user that our current record was deleted, and then we leave this view controller
        //
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Unable To Show Data"
                                                                       message:errorMessage
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *OKAction = [UIAlertAction actionWithTitle:@"OK"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             // dissmissal of alert completed
                                                         }];
        
        [alert addAction:OKAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
    
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [self.mArrRecords count];
}

// -------------------------------------------------------------------------------
//	setUpCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
//  Configure a tableview cell for a particular indexPath
// -------------------------------------------------------------------------------
- (void)setUpCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    
    if ([self.mArrRecords count] > 0) {
        Record *record = [self.mArrRecords objectAtIndex:indexPath.row];
        
        // Setting different fonts on a single label
        NSAttributedString *attrStr = [self customiseRecordLabel:record.recordTitle and:record.recordDescription];
        [cell.textLabel setAttributedText:attrStr];
        cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
        if (record.recordImageURLString && ![record.recordImageURLString isKindOfClass:[NSNull class]]) {
            
            // Only load cached images; defer new downloads until scrolling ends
            if (!record.recordImage) {
                if (self.tableView.dragging == NO && self.tableView.decelerating == NO) {
                    [self startImageDownload:record forIndexPath:indexPath];
                }
                // if a download is deferred or in progress, return a placeholder image
                cell.imageView.image = [UIImage imageNamed:@"Placeholder.png"];
            }
            else {
                cell.imageView.image = record.recordImage;
            }
        }
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    [cell setNeedsUpdateConstraints];
    [cell updateConstraintsIfNeeded];
    
    cell.imageView.image = nil;
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    cell.clipsToBounds = YES;
    cell.imageView.layer.cornerRadius = 5.0;
    cell.imageView.layer.masksToBounds = YES;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    [self setUpCell:cell atIndexPath:indexPath];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return UITableViewAutomaticDimension;
}

#pragma mark - Customising UILabel

// -------------------------------------------------------------------------------
//	customiseRecordLabel:(NSString *)title and:(NSString *)description
//  Customise the textLabel and returns a particular AttributedString
// -------------------------------------------------------------------------------
- (NSMutableAttributedString *)customiseRecordLabel:(NSString *)title and:(NSString *)description {
    
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:@""];
    
    NSDictionary *dict = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[UIFont systemFontOfSize:16.0], [UIColor blackColor], [UIColor clearColor], [NSParagraphStyle defaultParagraphStyle], nil] forKeys:[NSArray arrayWithObjects:NSFontAttributeName, NSForegroundColorAttributeName, NSBackgroundColorAttributeName, NSParagraphStyleAttributeName, nil]];
    
    if (title && ![title isKindOfClass:[NSNull class]]) {
        
        NSString *newTitle = [NSString stringWithFormat:@"%@\n",title];
        attrString = [[NSMutableAttributedString alloc] initWithString:newTitle attributes:dict];
    }
    
    if (description && ![description isKindOfClass:[NSNull class]]) {
        
        NSDictionary *subDict = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[UIFont systemFontOfSize:14.0], [UIColor grayColor], [UIColor clearColor], [NSParagraphStyle defaultParagraphStyle], nil] forKeys:[NSArray arrayWithObjects:NSFontAttributeName, NSForegroundColorAttributeName, NSBackgroundColorAttributeName, NSParagraphStyleAttributeName, nil]];
        
        NSMutableAttributedString *attrSubString = [[NSMutableAttributedString alloc] initWithString:description attributes:subDict];
        
        [attrString appendAttributedString:attrSubString];
    }
    return attrString;
}

#pragma mark - Table cell image support

// -------------------------------------------------------------------------------
//	startImageDownload:(Record *)record forIndexPath:(NSIndexPath *)indexPath
//  Start downloading the image for a particular record object
// -------------------------------------------------------------------------------
- (void)startImageDownload:(Record *)record forIndexPath:(NSIndexPath *)indexPath
{
    ImageDownloader *imageDownloader = (self.imageDownloadsInProgress)[indexPath];
    
    if (imageDownloader == nil) {
        
        imageDownloader = [[ImageDownloader alloc] init];
        imageDownloader.record = record;
        [imageDownloader setCompletionHandler:^{
            
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            
            // Display the newly loaded image
            cell.imageView.image = record.recordImage;
            [cell setNeedsLayout];
            
            // Remove the ImageDownloader from the in progress list.
            // This will result in it being deallocated.
            [self.imageDownloadsInProgress removeObjectForKey:indexPath];
            
        }];
        
        (self.imageDownloadsInProgress)[indexPath] = imageDownloader;
        [imageDownloader startDownload];
    }
}

// -------------------------------------------------------------------------------
//	loadImagesForOnscreenRows
//  On scroll Image loading
// -------------------------------------------------------------------------------

- (void)loadImagesForOnscreenRows
{
    if (self.mArrRecords.count > 0)
    {
        NSArray *visiblePaths = [self.tableView indexPathsForVisibleRows];
        for (NSIndexPath *indexPath in visiblePaths)
        {
            Record *record = (self.mArrRecords)[indexPath.row];
            
            if (record.recordImageURLString && ![record.recordImageURLString isKindOfClass:[NSNull class]]) {
                
                if (!record.recordImage) {
                    
                    // Avoid the image download if the cell already has an image
                    [self startImageDownload:record forIndexPath:indexPath];
                }
            }
        }
    }
}

#pragma mark - Refresh Table

// -------------------------------------------------------------------------------
//	refreshTable
//  End of explicit refreshing and reload the records again.
// -------------------------------------------------------------------------------
- (void)refreshTable {
    
    [self.refreshControl endRefreshing];
    [self terminateAllDownloads];
    [self populateRecords];
}

#pragma mark - UIScrollViewDelegate

// -------------------------------------------------------------------------------
//	scrollViewDidEndDragging:willDecelerate:
//  Load images for all onscreen rows when scrolling is finished.
// -------------------------------------------------------------------------------
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    
    if (!decelerate) {
        
        [self loadImagesForOnscreenRows];
    }
}

// -------------------------------------------------------------------------------
//	scrollViewDidEndDecelerating:scrollView
//  When scrolling stops, proceed to load the app icons that are on screen.
// -------------------------------------------------------------------------------
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    
    [self loadImagesForOnscreenRows];
}

#pragma mark - Terminate all image downloading process

// -------------------------------------------------------------------------------
//	populateRecords
//  terminate all image downloading processes if the current view is deallocated or user refreshes the table explicitly
// -------------------------------------------------------------------------------
- (void)terminateAllDownloads {
    
    // terminate all pending download connections
    NSArray *allDownloads = [self.imageDownloadsInProgress allValues];
    [allDownloads makeObjectsPerformSelector:@selector(cancelDownload)];
    
    [self.imageDownloadsInProgress removeAllObjects];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
