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
//  FolderTableViewDataSource.m
//

#import "FolderTableViewDataSource.h"
#import "Utility.h"
#import "FileUtils.h"
#import "FileDownloadManager.h"
#import "RepositoryServices.h"
#import "AppProperties.h"
#import "DownloadsViewController.h"
#import "IpadSupport.h"
#import "DownloadSummaryTableViewCell.h"
#import "DownloadFailureSummaryTableViewCell.h"
#import "AlfrescoMDMLite.h"
#import "SessionKeychainManager.h"
#import "AccountManager.h"

NSString * const kDownloadManagerSection = @"DownloadManager";
NSString * const kDownloadedFilesSection = @"DownloadedFiles";

NSInteger const kRestrictedImageViewTag = 30;

@interface FolderTableViewDataSource ()
@property (nonatomic, readwrite, retain) NSURL *folderURL;
@property (nonatomic, readwrite, retain) NSString *folderTitle;
@property (nonatomic, readwrite, retain) NSMutableArray *children;
@property (nonatomic, readwrite, retain) NSMutableDictionary *downloadsMetadata;
@property (nonatomic, readwrite) BOOL noDocumentsSaved;
@property (nonatomic, readwrite) BOOL downloadManagerActive;
@property (nonatomic, readwrite, retain) NSMutableArray *sectionKeys;
@property (nonatomic, readwrite, retain) NSMutableDictionary *sectionContents;

- (UIButton *)makeDetailDisclosureButton;
- (UITableViewCell *)tableView:(UITableView *)tableView downloadProgressCellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (UITableViewCell *)tableView:(UITableView *)tableView downloadFailuresCellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (UITableViewCell *)tableView:(UITableView *)tableView downloadedFileCellForRowAtIndexPath:(NSIndexPath *)indexPath;

@end

@implementation FolderTableViewDataSource
@synthesize folderURL = _folderURL;
@synthesize folderTitle = _folderTitle;
@synthesize children = _children;
@synthesize downloadsMetadata = _downloadsMetadata;
@synthesize editing = _editing;
@synthesize multiSelection = _multiSelection;
@synthesize noDocumentsSaved = _noDocumentsSaved;
@synthesize downloadManagerActive = _downloadManagerActive;
@synthesize currentTableView = _currentTableView;
@synthesize sectionKeys = _sectionKeys;
@synthesize sectionContents = _sectionContents;
@synthesize documentFilter = _documentFilter;
@synthesize noDocumentsFooterTitle = _noDocumentsFooterTitle;


#pragma mark Memory Management

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

	[_folderURL release];
	[_folderTitle release];
	[_children release];
    [_downloadsMetadata release];
    [_currentTableView release];
    [_sectionKeys release];
    [_sectionContents release];
    [_documentFilter release];
    [_noDocumentsFooterTitle release];
    
	[super dealloc];
}

#pragma mark Initialization

- (id)initWithURL:(NSURL *)url
{
    self = [self initWithURL:url andDocumentFilter:nil];
    return self;
}

- (id)initWithURL:(NSURL *)url andDocumentFilter:(id<DocumentFilter>)documentFilter
{
    self = [super init];
	if (self)
    {
        [self setNoDocumentsFooterTitle:NSLocalizedString(@"downloadview.footer.no-documents", @"No Downloaded Documents")];
        [self setDocumentFilter:documentFilter];
        [self setDownloadManagerActive:[[[DownloadManager sharedManager] allDownloads] count] > 0];
		[self setFolderURL:url];
		[self setChildren:[NSMutableArray array]];
        [self setDownloadsMetadata:[NSMutableDictionary dictionary]];
		[self refreshData];
		
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadQueueChanged:) name:kNotificationDownloadQueueChanged object:nil];

		// TODO: Check to make sure provided URL exists if local file system
	}
	return self;
}

#pragma mark -

#pragma mark UITableViewDataSource Cell Renderers

- (UITableViewCell *)tableView:(UITableView *)tableView downloadProgressCellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	DownloadSummaryTableViewCell *cell = (DownloadSummaryTableViewCell *)[tableView dequeueReusableCellWithIdentifier:kDownloadSummaryCellIdentifier];
    if (cell == nil)
    {
        cell = [[[DownloadSummaryTableViewCell alloc] initWithIdentifier:kDownloadSummaryCellIdentifier] autorelease];
    }
        
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView downloadFailuresCellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	DownloadFailureSummaryTableViewCell *cell = (DownloadFailureSummaryTableViewCell *)[tableView dequeueReusableCellWithIdentifier:kDownloadFailureSummaryCellIdentifier];
    if (cell == nil)
    {
        cell = [[[DownloadFailureSummaryTableViewCell alloc] initWithIdentifier:kDownloadFailureSummaryCellIdentifier] autorelease];
    }
    
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView downloadedFileCellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *cellIdentifier = @"folderChildTableCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (nil == cell)
    {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier] autorelease];
		[[cell textLabel] setFont:[UIFont boldSystemFontOfSize:17.0f]];
		[[cell detailTextLabel] setFont:[UIFont italicSystemFontOfSize:14.0f]];
        
        UIImageView *restrictedView = [[[UIImageView alloc] initWithFrame:CGRectMake(cell.contentView.frame.size.width - 24, 0, 24, 24)] autorelease];
        restrictedView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
        restrictedView.tag = kRestrictedImageViewTag;
        [cell.contentView addSubview:restrictedView];
	}
	
	NSString *title = @"";
	NSString *details = @"";
	UIImage *iconImage = nil;
	
	if ([[self folderURL] isFileURL] && [self.children count] > 0) 
    {
		NSError *error;
		NSString *fileURLString = [(NSURL *)[self.children objectAtIndex:indexPath.row] path];
		NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fileURLString error:&error];
		long fileSize = [[fileAttributes objectForKey:NSFileSize] longValue];
        NSDate *modificationDate = [fileAttributes objectForKey:NSFileModificationDate];
        // We use the formatDocumentFromDate() because it formats the date according the user settings
        NSString *modDateString = formatDocumentDateFromDate(modificationDate);
		
        DownloadMetadata *metadata = [self.downloadsMetadata objectForKey:[fileURLString lastPathComponent]];

        /**
         * mhatfield: 06 June 2012
         * Pulling the displayed filename from the metadata could show two files with the same name. Confusing for the user?
         */
        /*
        if (metadata)
        {
            title = metadata.filename;
        }
        else
        {
            title = [fileURLString lastPathComponent];
        }
         */
        title = [fileURLString lastPathComponent];
        
		// !!!: Check if we got an error and handle gracefully
        // TODO: Needs to be localized
		details = [NSString stringWithFormat:@"%@ • %@", modDateString, [FileUtils stringForLongFileSize:fileSize]];
		iconImage = imageForFilename(title);
        
        [cell setAccessoryType:UITableViewCellAccessoryNone];
        
        RepositoryInfo *repoInfo = [[RepositoryServices shared] getRepositoryInfoForAccountUUID:metadata.accountUUID tenantID:metadata.tenantID];
        NSString *currentRepoId = [repoInfo repositoryId];
        BOOL showMetadata = [[AppProperties propertyForKey:kDShowMetadata] boolValue];
        
        if ([currentRepoId isEqualToString:[metadata repositoryId]] && showMetadata && !self.multiSelection) 
        {
            [cell setAccessoryView:[self makeDetailDisclosureButton]];
        }
        else
        {
            [cell setAccessoryView:nil];
            [cell setAccessoryType:UITableViewCellAccessoryNone];
        }
        
        // Check if the file is restricted
        BOOL isRestricted = [[AlfrescoMDMLite sharedInstance] isRestrictedDownload:title];
        UIImageView *imgView = (UIImageView *)[cell.contentView viewWithTag:kRestrictedImageViewTag];
        imgView.image = isRestricted ? [UIImage imageNamed:@"restricted-file"] : nil;

        // Check if the file's offline restriction timeout has expired
        BOOL isExpired = [[AlfrescoMDMLite sharedInstance] isDownloadExpired:title withAccountUUID:metadata.accountUUID];
        cell.contentView.alpha = isExpired ? 0.5 : 1.0;
        
        [tableView setAllowsSelection:YES];
	} 
    else if (self.noDocumentsSaved)
    {
        title = self.noDocumentsFooterTitle;
        [[cell imageView] setImage:nil];
        details = nil;
        [cell setAccessoryType:UITableViewCellAccessoryNone];
        [tableView setAllowsSelection:NO];
    } 
    else
    {
		// FIXME: implement when going over the network
	}
	
	[[cell textLabel] setText:title];
	[[cell detailTextLabel] setText:details];
    
    if (iconImage)
    {
        [[cell imageView] setImage:iconImage];
    }
	
	return cell;
}

#pragma mark UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.currentTableView = tableView;
    SEL rendererSelector = nil;

    NSString *key = [self.sectionKeys objectAtIndex:indexPath.section];
    NSArray *contents = [self.sectionContents objectForKey:key];
    id cellContents = [contents objectAtIndex:indexPath.row];
    
    if ([key isEqualToString:kDownloadManagerSection])
    {
        if ([cellContents isEqualToString:kDownloadSummaryCellIdentifier])
        {
            rendererSelector = @selector(tableView:downloadProgressCellForRowAtIndexPath:);
        }
        else if ([cellContents isEqualToString:kDownloadFailureSummaryCellIdentifier])
        {
            rendererSelector = @selector(tableView:downloadFailuresCellForRowAtIndexPath:);
        }
    }
    else
    {
        rendererSelector = @selector(tableView:downloadedFileCellForRowAtIndexPath:);
    }
    
    return [self performSelector:rendererSelector withObject:tableView withObject:indexPath];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSString *key = [[self sectionKeys] objectAtIndex:section];
    NSArray *contents = [[self sectionContents] objectForKey:key];
    NSInteger numberOfRows = [contents count];

    return numberOfRows;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [self.sectionKeys count];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	AlfrescoLogDebug(@"Deleted the cell: %d", indexPath.row);
    NSURL *fileURL = [[self.children objectAtIndex:indexPath.row] retain];
    NSString *filename = [fileURL lastPathComponent];
	BOOL fileExistsInFavorites = [[FileDownloadManager sharedInstance] downloadExistsForKey:filename];
    [self setEditing:YES];
    
	if (fileExistsInFavorites)
    {
        [[FileDownloadManager sharedInstance] removeDownloadInfoForFilename:filename];
		AlfrescoLogDebug(@"Removed File '%@'", filename);
    }
    
    [self refreshData];
    [self setNoDocumentsSaved:NO];
    [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
    
    DownloadsViewController *delegate = (DownloadsViewController *)[tableView delegate];
    if ([fileURL isEqual:delegate.selectedFile])
    {
        [IpadSupport clearDetailController];
    }
    
    if ([self.children count] == 0)
    {
        [self setNoDocumentsSaved:YES];
        [tableView reloadData];
    }
    
    [fileURL release];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    NSString *footerText = @"";
    NSString *key = [[self sectionKeys] objectAtIndex:section];

    if ([key isEqualToString:kDownloadedFilesSection])
    {
        if ([self.children count] > 0)
        {
            NSString *documentsText;
            switch ([self.children count])
            {
                case 1:
                    documentsText = NSLocalizedString(@"downloadview.footer.one-document", @"1 Document");
                    break;
                default:
                    documentsText = [NSString stringWithFormat:NSLocalizedString(@"downloadview.footer.multiple-documents", @"%d Documents"), 
                                     [self.children count]];
                    break;
            }
            footerText = [NSString stringWithFormat:@"%@ %@", documentsText, [FileUtils stringForLongFileSize:totalFilesSize]];	
        }
        else
        {
            footerText = self.noDocumentsFooterTitle;
        }
    }
    
    return footerText;
}

#pragma mark - Instance Methods

- (UIButton *)makeDetailDisclosureButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeInfoDark];
    [button addTarget:self action:@selector(accessoryButtonTapped:withEvent:) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)accessoryButtonTapped:(UIControl *)button withEvent:(UIEvent *)event
{
    AlfrescoLogDebug(@"accessory view tapped");
    NSIndexPath *indexPath = [self.currentTableView indexPathForRowAtPoint:[[[event touchesForView:button] anyObject] locationInView:self.currentTableView]];
    if (indexPath != nil)
    {
        [self.currentTableView.delegate tableView:self.currentTableView accessoryButtonTappedForRowWithIndexPath:indexPath];
    }
}

- (void)refreshData
{
    NSMutableArray *keys = [[NSMutableArray alloc] init];
    NSMutableDictionary *contents = [[NSMutableDictionary alloc] init];
    
	[[self children] removeAllObjects];
    [[self downloadsMetadata] removeAllObjects];
    
    /**
     * In-progress or failed downloads (only for non-multiselect mode)?
     */
    DownloadManager *manager = [DownloadManager sharedManager];
    if (!self.multiSelection && [manager.allDownloads count] > 0)
    {
        NSMutableArray *dmContent = [[NSMutableArray alloc] initWithCapacity:2];
        if ([manager.activeDownloads count] > 0)
        {
            [dmContent addObject:kDownloadSummaryCellIdentifier];
        }
        if ([manager.failedDownloads count] > 0)
        {
            [dmContent addObject:kDownloadFailureSummaryCellIdentifier];
        }
        
        // Safety check
        if ([dmContent count] > 0)
        {
            [contents setObject:dmContent forKey:kDownloadManagerSection];
            [keys addObject:kDownloadManagerSection];
        }
        [dmContent release];
    }

    /**
     * Downloaded files
     */
	if ([[self folderURL] isFileURL])
    {
		[self setFolderTitle:[[self.folderURL path] lastPathComponent]];
        totalFilesSize = 0;
		
		// !!!: Need to program defensively and check for an error ...
		NSEnumerator *folderContents = [[NSFileManager defaultManager] enumeratorAtURL:[self folderURL]
                                                            includingPropertiesForKeys:[NSArray arrayWithObject:NSURLNameKey]
                                                                               options:NSDirectoryEnumerationSkipsHiddenFiles|NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                                                          errorHandler:^BOOL(NSURL *url, NSError *error) {
            AlfrescoLogDebug(@"Error retrieving the download folder contents in URL: %@ and error: %@", url, error);
            return YES;
        }];
		
		for (NSURL *fileURL in folderContents)
		{
            NSError *error;
            NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[fileURL path] error:&error];
            totalFilesSize += [[fileAttributes objectForKey:NSFileSize] longValue];
			
			BOOL isDirectory;
			[[NSFileManager defaultManager] fileExistsAtPath:[fileURL path] isDirectory:&isDirectory];
			
			// only add files, no directories nor the Inbox
            // also a documentFilter can filter a document by name, for a nil documentFilter or a valid document name will return NO
            // for an invalid document name the filter will return YES
			if (!isDirectory && ![[fileURL path] isEqualToString: @"Inbox"] && ![self.documentFilter filterDocumentWithName:[fileURL path]])
            {
                NSMutableArray *components = (NSMutableArray *)[fileURL pathComponents];
                if ([[components objectAtIndex:1] isEqualToString:@"private"])
                {
                    [components removeObjectAtIndex:1];
                    fileURL = [NSURL fileURLWithPathComponents:components];
                }
				[self.children addObject:fileURL];
                
                NSDictionary *downloadInfo = [[FileDownloadManager sharedInstance] downloadInfoForFilename:[fileURL lastPathComponent]];
                
                if (downloadInfo)
                {
                    DownloadMetadata *metadata = [[DownloadMetadata alloc] initWithDownloadInfo:downloadInfo];
                    [self.downloadsMetadata setObject:metadata forKey:[fileURL lastPathComponent]];
                    [metadata release];
                }
            }
		}
        
        [contents setObject:self.children forKey:kDownloadedFilesSection];
        [keys addObject:kDownloadedFilesSection];
	}
	else
    {
		//	FIXME: implement me
	}
    
    [self setNoDocumentsSaved:[self.children count] == 0];
    
    if (self.multiSelection)
    {
        [self.currentTableView setAllowsMultipleSelectionDuringEditing:!self.noDocumentsSaved];
        [self.currentTableView setEditing:!self.noDocumentsSaved];
    }
    else
    {
        //[self.currentTableView setEditing:NO]; //we keep edit status
    }
    
    [self setSectionKeys:keys];
    [self setSectionContents:contents];
    
    [keys release];
    [contents release];
}

- (id)cellDataObjectForIndexPath:(NSIndexPath *)indexPath
{
    NSString *key = [[self sectionKeys] objectAtIndex:indexPath.section];
    NSArray *contents = [[self sectionContents] objectForKey:key];

	return [contents objectAtIndex:indexPath.row];
}

- (id)downloadMetadataForIndexPath:(NSIndexPath *)indexPath
{
    NSURL *fileURL = (NSURL *)[self.children objectAtIndex:indexPath.row];
	return [[self downloadsMetadata] objectForKey:[fileURL lastPathComponent]];
}

- (NSArray *)selectedDocumentsURLs
{
    NSArray *selectedIndexes = [self.currentTableView indexPathsForSelectedRows];
    NSMutableArray *selectedURLs = [NSMutableArray arrayWithCapacity:[selectedIndexes count]];
    for (NSIndexPath *indexPath in selectedIndexes)
    {
        [selectedURLs addObject:[self.children objectAtIndex:indexPath.row]];
    }
    
    return [NSArray arrayWithArray:selectedURLs];
}

#pragma mark - Download notifications

- (void)downloadQueueChanged:(NSNotification *)notification
{
    [self refreshData];
    [self.currentTableView reloadData];
}

@end
