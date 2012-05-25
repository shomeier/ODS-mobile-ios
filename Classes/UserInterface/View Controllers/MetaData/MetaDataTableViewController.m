/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is the Alfresco Mobile App.
 *
 * The Initial Developer of the Original Code is Zia Consulting, Inc.
 * Portions created by the Initial Developer are Copyright (C) 2011-2012
 * the Initial Developer. All Rights Reserved.
 *
 *
 * ***** END LICENSE BLOCK ***** */
//
//  MetaDataTableViewController.m
//

#import "MetaDataTableViewController.h"
#import "Theme.h"
#import "MetaDataCellController.h"
#import "IFTemporaryModel.h"
#import "IFMultilineCellController.h"
#import "PropertyInfo.h"
#import "IFTextCellController.h"
#import "NodeRef.h"
#import "Utility.h"
#import "IFButtonCellController.h"
#import "LinkRelationService.h"
#import "TableCellViewController.h"
#import "FileDownloadManager.h"
#import "RepositoryServices.h"
#import "FolderItemsHTTPRequest.h"
#import "VersionHistoryTableViewController.h"
#import "MBProgressHUD.h"
#import "AccountManager.h"
#import "MetadataMapViewController.h"

static NSArray * cmisPropertiesToDisplay = nil;
@interface MetaDataTableViewController(private)
-(void)startHUD;
-(void)stopHUD;
@end


@implementation MetaDataTableViewController
@synthesize delegate;
@synthesize cmisObjectId;
@synthesize metadata;
@synthesize propertyInfo;
@synthesize describedByURL;
@synthesize mode;
@synthesize tagsArray;
@synthesize taggingRequest;
@synthesize cmisObject;
@synthesize errorMessage;
@synthesize downloadMetadata;
@synthesize downloadProgressBar;
@synthesize versionHistoryRequest;
@synthesize isVersionHistory;
@synthesize HUD;
@synthesize selectedAccountUUID;
@synthesize tenantID;
@synthesize longitude = _longitude;
@synthesize latitude = _latitude;
@synthesize hasLatitude = _hasLatitude;
@synthesize hasLongitude = _hasLongitude;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [taggingRequest clearDelegatesAndCancel];
    [versionHistoryRequest clearDelegatesAndCancel];
    
    [cmisObjectId release];
    [metadata release];
	[propertyInfo release];
    [describedByURL release];
    [mode release];
    [tagsArray release];
    [taggingRequest release];
    [cmisObject release];
    [errorMessage release];
    [downloadMetadata release];
    [downloadProgressBar release];
    [versionHistoryRequest release];
    [HUD release];
    [selectedAccountUUID release];
    [tenantID release];
    
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

+ (void)initialize {
    // TODO This should be externalized to the properties file
    // NOTE: lists the keys in order of appearance
    if ( !cmisPropertiesToDisplay) {
        cmisPropertiesToDisplay = [[NSArray alloc] initWithObjects:@"cmis:name", @"cm:title",@"cm:description", @"cmis:createdBy", 
                                   @"cmis:creationDate", @"cmis:lastModifiedBy", @"cmis:lastModificationDate", @"cm:author",
                                   @"cmis:versionLabel", @"cm:longitude", @"cm:latitude",
                                   @"exif:dateTimeOriginal", @"exif:exposureTime", @"exif:flash", @"exif:fNumber",
                                   @"exif:focalLength", @"exif:isoSpeedRatings", @"exif:manufacturer", @"exif:model",
                                   @"exif:orientation", @"exif:pixelXDimension", @"exif:pixelYDimension", @"exif:resolutionUnit",
                                   @"exif:software", @"exif:xResolution", @"exif:yResolution", nil];
        
    }
}

- (id)initWithStyle:(UITableViewStyle)style cmisObject:(RepositoryItem *)cmisObj accountUUID:(NSString *)uuid tenantID:(NSString *)aTenantID
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
        [self setMode:@"VIEW_MODE"];  // TODO... Constants // VIEW | EDIT | READONLY (?)
        [self setTagsArray:nil];
        [self setCmisObject:cmisObj];
        [self setSelectedAccountUUID:uuid];
        [self setTenantID:aTenantID];
        self.hasLatitude = NO;
        self.hasLongitude = NO;
        self.latitude = 0;
        self.longitude = 0;
    }
    return self;
}


#pragma mark - View lifecycle

- (void)viewDidUnload {
    [super viewDidUnload];
    
    self.tableView = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    BOOL usingAlfresco = [[AccountManager sharedManager] isAlfrescoAccountForAccountUUID:selectedAccountUUID];
    
    [Theme setThemeForUINavigationBar:self.navigationController.navigationBar];
    
    [self.navigationItem setTitle:[metadata objectForKey:@"cmis:name"]]; // XXX probably should check if value exists
    
    if ([self.mode isEqualToString:@"VIEW_MODE"]) {
        
        // TODO Check if editable
    
//        UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit 
//                                                                                    target:self 
//                                                                                    action:@selector(editButtonPressed)];
//        [self.navigationItem setRightBarButtonItem:editButton];
//        [editButton release];
    }
    else if ([self.mode isEqualToString:@"EDIT_MODE"]) {
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
                                                                                    target:self 
                                                                                    action:@selector(doneButtonPressed)];
        [self.navigationItem setRightBarButtonItem:doneButton];
        [doneButton release];
        
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel 
                                                                                      target:self action:@selector(cancelButtonPressed)];
        [self.navigationItem setLeftBarButtonItem:cancelButton animated:YES];
        [cancelButton release];
    }

    if (usingAlfresco) {
        @try {
            if(!errorMessage) {
                self.taggingRequest = [TaggingHttpRequest httpRequestGetNodeTagsForNode:[NodeRef nodeRefFromCmisObjectId:cmisObjectId] 
                                                                            accountUUID:selectedAccountUUID tenantID:self.tenantID];
                [self.taggingRequest setDelegate:self];
                [self.taggingRequest startAsynchronous];
            }
        }
        @catch (NSException *exception) {
            NSLog(@"FATAL: tagging request failed on viewDidload");
        }
        @finally {
        }
    }
}

#pragma mark -
#pragma mark ASIHTTPRequest

-(void)requestFinished:(TaggingHttpRequest *)request
{
    if([request isKindOfClass:[FolderItemsHTTPRequest class]]) {
        FolderItemsHTTPRequest *vhRequest = (FolderItemsHTTPRequest *)request;
        VersionHistoryTableViewController *controller = [[VersionHistoryTableViewController alloc] initWithStyle:UITableViewStyleGrouped 
                                                                                                  versionHistory:vhRequest.children 
                                                                                                     accountUUID:selectedAccountUUID 
                                                                                                        tenantID:self.tenantID];
        
        [self.navigationController pushViewController:controller animated:YES];
        [controller release];
        
    } else {
        NSArray *parsedTags = [TaggingHttpRequest tagsArrayWithResponseString:[request responseString] accountUUID:selectedAccountUUID];
        [self setTagsArray:parsedTags];
        [self updateAndReload];
    }
    
    [self stopHUD];
}

-(void)requestFailed:(TaggingHttpRequest *)request
{
    NSLog(@"Error from the request: %@", [request.error description]);
    [self stopHUD];
}

- (void)editButtonPressed {
    // DO NOTHING, Currently not being used
//    MetaDataTableViewController *viewController = [[MetaDataTableViewController alloc] initWithStyle:UITableViewStylePlain];
//    [viewController setMode:@"EDIT_MODE"];
//    [viewController setMetadata:[[self.metadata copy] autorelease]];
//    [viewController setPropertyInfo:[[self.propertyInfo copy] autorelease]];
//    [viewController setDescribedByURL:self.describedByURL];
//    [viewController setDelegate:self.delegate];
//    
//    [self.navigationController pushViewController:viewController animated:YES];
//    [viewController release];
}

- (void)doneButtonPressed {
    // NSLOG DO SOMETHING
    NSLog(@"DONE BUTTON PRESSED, EXECUTE A SAVE!");
    
    // Peform Save
    
    if (self.delegate) {
        [self.delegate tableViewController:self metadataDidChange:YES];
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)cancelButtonPressed {
    
    if (self.delegate) {
        [self.delegate tableViewController:self metadataDidChange:NO];
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Always Rotate
    return YES;
}


#pragma mark -
#pragma mark Generic Table View Construction

- (void)constructTableGroups
{
    if (![self.model isKindOfClass:[IFTemporaryModel class]]) {
        IFTemporaryModel *tempModel = [[IFTemporaryModel alloc] initWithDictionary:[NSMutableDictionary dictionaryWithDictionary:metadata]];
        [self setModel:tempModel];
        [tempModel release];
	}
    
    // Arrays for section headers, bodies and footers
	NSMutableArray *headers = [NSMutableArray array];
	NSMutableArray *groups =  [NSMutableArray array];
	NSMutableArray *footers = [NSMutableArray array];
    
    if(metadata) {
        NSMutableArray *metadataCellGroup = [NSMutableArray arrayWithCapacity:[metadata count]];
        NSMutableArray *imageMetadataCellGroup = [NSMutableArray array];
        NSArray *sortedKeys = [metadata allKeys];
        for (NSString *key in cmisPropertiesToDisplay) {
            if (![sortedKeys containsObject:key]) 
            {
                continue;
            }
            id value = [model objectForKey:key];
            NSString *valueText = @"";
            if (nil == value) {
                valueText = @"";
            }
            else if ([value isKindOfClass:[NSString class]])
            {
                valueText = value;
            }
            else if ([value isKindOfClass:[NSNumber class]])
            {
                valueText = [value stringValue];
            } 
            
            if ([valueText isEqualToString:@""]) {
                continue;
            }
            
            
            if ([key hasPrefix:@"cm:longitude"]) {
                self.hasLongitude = YES;
                self.longitude = [valueText floatValue];
                continue;
            }
            if ([key hasPrefix:@"cm:latitude"]) {
                self.hasLatitude = YES;
                self.latitude = [valueText floatValue];
                continue;
            }
            
            
            PropertyInfo *i = [self.propertyInfo objectForKey:key];
            
//            NSString *displayKey = i.displayName ? i.displayName : [StringSplitter stringForKey:key withDelimiter:nil];
//            displayKey = [NSString stringWithFormat:@"%@:", displayKey];
            
            NSString *displayKey = NSLocalizedString(key, key);
            
            if (self.mode && [self.mode isEqualToString:@"EDIT_MODE"]) { // TODO Externalize this string
                
                IFTextCellController *cellController = [[IFTextCellController alloc] initWithLabel:displayKey andPlaceholder:@"" 
                                                                                             atKey:key inModel:self.model];
                [metadataCellGroup addObject:cellController];
                [cellController release];
                
                // FIXME: IMPLEMENT ME
                
            } else {
                
                if ([i.propertyType isEqualToString:@"datetime"]) {
                    NSString *value = formatDateTime([model objectForKey:key]);
                    key = [key stringByAppendingString:@"Ex"];
                    [model setObject:value forKey:key];
                }
                
                MetaDataCellController *cellController = [[MetaDataCellController alloc] initWithLabel:displayKey 
                                                                                                 atKey:key inModel:self.model];
                if ([key hasPrefix:@"exif"]) 
                {
                    [imageMetadataCellGroup addObject:cellController];
                }
                else 
                {
                    [metadataCellGroup addObject:cellController];
                }
                [cellController release];
            }
        }
        
        // TODO: Handle Edit MOde
        if (self.tagsArray && ([tagsArray count] > 0)) {
            [model setObject:([tagsArray componentsJoinedByString:@", "]) forKey:@"tags"];
            MetaDataCellController *tagsCellController = [[MetaDataCellController alloc] initWithLabel:@"Tags:" atKey:@"tags" inModel:self.model];
            [metadataCellGroup addObject:tagsCellController];
            [tagsCellController release];
        }
        
        [headers addObject:@"General"];
        [groups addObject:metadataCellGroup];
        [footers addObject:@""];
        
        if (0 < [imageMetadataCellGroup count]) 
        {
            [headers addObject:@"Image Information"];
            [groups addObject:imageMetadataCellGroup];
            [footers addObject:@""];
            if (self.hasLatitude && self.hasLongitude) {
                NSMutableArray *mapGroup = [NSMutableArray array];
                IFButtonCellController *mapButton = [[IFButtonCellController alloc] 
                                                     initWithLabel:NSLocalizedString(@"metadata.button.view.loadImageMap", @"Load Map") 
                                                    withAction:@selector(viewImageLocation) onTarget:self];
                [mapButton setBackgroundColor:[UIColor whiteColor]];
                [mapGroup addObject:mapButton];
                [mapButton release];
                [headers addObject:@""];
                [groups addObject:mapGroup];
                [footers addObject:@""];
            }
            
        }
        
        
        NSMutableArray *versionsHistoryGroup = [NSMutableArray array];
        NSString *versionHistoryURI = [[LinkRelationService shared] hrefForLinkRelationString:@"version-history" onCMISObject:cmisObject];
        
        if(!isVersionHistory && versionHistoryURI) {
            IFButtonCellController *viewVersionHistoryButton = [[IFButtonCellController alloc] initWithLabel:NSLocalizedString(@"metadata.button.view.version.history", @"View Version History") 
                                                                                                  withAction:@selector(viewVersionHistoryButtonClicked) onTarget:self];
            [viewVersionHistoryButton setBackgroundColor:[UIColor whiteColor]];
            [versionsHistoryGroup addObject:viewVersionHistoryButton];
            [viewVersionHistoryButton release];
            [headers addObject:@""];
            [groups addObject:versionsHistoryGroup];
            [footers addObject:@""];
        }
        
        
    } else if(errorMessage) {
        NSMutableArray *noMetadataGroup = [NSMutableArray arrayWithCapacity:1];
        TableCellViewController *cellController = [[TableCellViewController alloc] init];
        cellController.textLabel.text = errorMessage ;
        
        [noMetadataGroup addObject:cellController];
        [cellController release];
        
        [headers addObject:@""];
        [groups addObject:noMetadataGroup];
        [footers addObject:@""];
        
        [self.tableView setAllowsSelection:NO];
    }

    tableGroups = [groups retain];
	tableHeaders = [headers retain];
	tableFooters = [footers retain];
	[self assignFirstResponderHostToCellControllers];
}

- (void)viewVersionHistoryButtonClicked
{
    NSString *versionHistoryURI = [[LinkRelationService shared] hrefForLinkRelationString:@"version-history" onCMISObject:cmisObject];
    FolderItemsHTTPRequest *down = [[FolderItemsHTTPRequest alloc] initWithURL:[NSURL URLWithString:versionHistoryURI] accountUUID:selectedAccountUUID];
    [down setDelegate:self];
    [down setShow500StatusError:NO];
    [self setVersionHistoryRequest:down];
    [down startAsynchronous];
    [self startHUD];
    
    [down release];
}

/**
 TODO
 - give warning if no latitude or longitude values are given. UIAlertView
 - if location services are not enabled - allow users to go to Settings app from the UIAlertView
 */
- (void)viewImageLocation
{
    if (!self.hasLatitude || !self.hasLongitude) 
    { //TODO - we shouldn't really get here
        return;
    }
    CLLocationCoordinate2D coordinate;
    coordinate.latitude = self.latitude;
    coordinate.longitude = self.longitude;
    MetadataMapViewController *mapController = [[[MetadataMapViewController alloc]initWithCoordinates:coordinate andMetadata:metadata]autorelease];
    [self.navigationController pushViewController:mapController animated:YES];
}


#pragma mark -
#pragma mark DownloadProgressBarDelegate methods

- (void)redownloadButtonClicked
{
    NSURL *contentURL = [NSURL URLWithString:downloadMetadata.contentLocation];
    [self setDownloadProgressBar:[DownloadProgressBar createAndStartWithURL:contentURL delegate:self 
                                                                    message:NSLocalizedString(@"Downloading Document", @"Downloading Document")
                                                                   filename:downloadMetadata.filename 
                                                                accountUUID:selectedAccountUUID 
                                                                   tenantID:self.tenantID]];
    [[self downloadProgressBar] setCmisObjectId:downloadMetadata.objectId];
    [[self downloadProgressBar] setCmisContentStreamMimeType:downloadMetadata.contentStreamMimeType];
    [[self downloadProgressBar] setVersionSeriesId:downloadMetadata.versionSeriesId];
    
    RepositoryItem *item = [[RepositoryItem alloc] init];
    item.describedByURL = downloadMetadata.describedByUrl;
    item.metadata = [NSMutableDictionary dictionaryWithDictionary: downloadMetadata.metadata];
    [[self downloadProgressBar] setRepositoryItem:item];
    
    [item release];
}

- (void) download:(DownloadProgressBar *)down completeWithPath:(NSString *)filePath {
    DownloadMetadata *fileMetadata = down.downloadMetadata;
    [[FileDownloadManager sharedInstance] setDownload:fileMetadata.downloadInfo forKey:[filePath lastPathComponent] withFilePath:filePath];
    UIAlertView *saveConfirmationAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"documentview.download.confirmation.title", @"")
                                                                    message:NSLocalizedString(@"documentview.download.confirmation.message", @"The document has been saved to your device")
                                                                   delegate:nil 
                                                          cancelButtonTitle: @"Close" 
                                                          otherButtonTitles:nil, nil];
    [saveConfirmationAlert show];
    [saveConfirmationAlert release];
}

- (void) downloadWasCancelled:(DownloadProgressBar *)down {
    
    NSLog(@"Download was cancelled!");
}

#pragma mark -
#pragma mark MetaDataTableViewDelegate

- (void)tableViewController:(MetaDataTableViewController *)controller metadataDidChange:(BOOL)metadataDidChange
{
    // TODO
    
}

#pragma mark - MBProgressHUD Helper Methods

- (void)startHUD
{
	if (!self.HUD)
    {
        self.HUD = createAndShowProgressHUDForView(self.view);
	}
}

- (void)stopHUD
{
	if (self.HUD)
    {
        stopProgressHUD(self.HUD);
		self.HUD = nil;
	}
}

- (void) cancelActiveConnection:(NSNotification *) notification {
    NSLog(@"applicationWillResignActive in MetaDataTableViewController");
    [taggingRequest clearDelegatesAndCancel];
    [versionHistoryRequest cancel];
}


@end
