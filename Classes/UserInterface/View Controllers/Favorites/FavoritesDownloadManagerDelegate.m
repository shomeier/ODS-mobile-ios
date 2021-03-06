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
//  FavoritesDownloadManagerDelegate.m
//

#import "FavoritesDownloadManagerDelegate.h"
#import "FavoriteTableCellWrapper.h"
#import "FavoriteTableViewCell.h"
#import "DocumentViewController.h"
#import "IpadSupport.h"

@implementation FavoritesDownloadManagerDelegate

@synthesize repositoryItems = _repositoryItems;
@synthesize tableView = _tableView;
@synthesize navigationController = _navigationController;
@synthesize presentNewDocumentPopover = _presentNewDocumentPopover;
@synthesize selectedAccountUUID = _selectedAccountUUID;
@synthesize tenantID = _tenantID;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_repositoryItems release];
    [_tableView release];
    [_navigationController release];
    [_selectedAccountUUID release];
    [_tenantID release];
    [super dealloc];
}

- (id)init
{
    if (self = [super init])
    {
        /* Registering for Download Manager Notifications */
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadStarted:) name:kNotificationFavoriteDownloadStarted object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadFinished:) name:kNotificationFavoriteDownloadFinished object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadFailed:) name:kNotificationFavoriteDownloadFailed object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadCancelled:) name:kNotificationFavoriteDownloadCancelled object:nil];
        
        /* Registering for Upload Manager Notifications */
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadStarted:) name:kNotificationFavoriteUploadStarted object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadFinished:) name:kNotificationFavoriteUploadFinished object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadFailed:) name:kNotificationFavoriteUploadFailed object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadCancelled:) name:kNotificationFavoriteUploadCancelled object:nil];
    }
    
    return self;
}

#pragma mark - Download Manager Notifications 

- (void)downloadCancelled:(NSNotification *)notification
{
    NSIndexPath *indexPath = [self indexPathForNodeWithGuid:[notification.userInfo objectForKey:@"downloadObjectId"]];
    FavoriteTableCellWrapper *cellWrapper = [self.repositoryItems objectAtIndex:indexPath.row];
    
    [[FavoriteDownloadManager sharedManager] setProgressIndicator:nil forObjectId:[notification.userInfo objectForKey:@"downloadObjectId"]];

    [cellWrapper setActivityType:SyncActivityTypeDownload];
    [cellWrapper setIsActivityInProgress:NO];
    
    if ([notification.userInfo objectForKey:@"isPreview"] == nil)
    {
        [self updateSyncStatus:SyncStatusCancelled forRow:indexPath];
    }
    else 
    {
        [cellWrapper setIsPreviewInProgress:NO];
    }
    
    [self updateCellDetails:indexPath];
    
    [self.tableView setAllowsSelection:YES];
    [self setPresentNewDocumentPopover:NO];
}

- (void)downloadFailed:(NSNotification *)notification
{
    NSIndexPath *indexPath = [self indexPathForNodeWithGuid:[notification.userInfo objectForKey:@"downloadObjectId"]];
    FavoriteTableCellWrapper *cellWrapper = [self.repositoryItems objectAtIndex:indexPath.row];
    
    [[FavoriteDownloadManager sharedManager] setProgressIndicator:nil forObjectId:[notification.userInfo objectForKey:@"downloadObjectId"]];

    [cellWrapper setActivityType:SyncActivityTypeDownload];
    [cellWrapper setIsActivityInProgress:NO];
    
    if ([notification.userInfo objectForKey:@"isPreview"] == nil)
    {
        [self updateSyncStatus:SyncStatusFailed forRow:indexPath];
    }
    else 
    {
        [cellWrapper setIsPreviewInProgress:NO];
    }
    
    [self updateCellDetails:indexPath];
    
    [self.tableView setAllowsSelection:YES];
    [self setPresentNewDocumentPopover:NO];
}

- (void)downloadFinished:(NSNotification *)notification
{
    NSString *objectId = [notification.userInfo objectForKey:@"downloadObjectId"];
    NSIndexPath *indexPath = [self indexPathForNodeWithGuid:objectId];
    FavoriteTableCellWrapper *cellWrapper = [self.repositoryItems objectAtIndex:indexPath.row];
    
    [[FavoriteDownloadManager sharedManager] setProgressIndicator:nil forObjectId:objectId];

    [cellWrapper setActivityType:SyncActivityTypeIdle];
    [cellWrapper setIsActivityInProgress:NO];
    
    if ([notification.userInfo objectForKey:@"isPreview"] == nil)
    {
        [self updateSyncStatus:SyncStatusSuccessful forRow:indexPath];
    }
    else 
    {
        [cellWrapper setIsPreviewInProgress:NO];
    }
    
    BOOL isDocumentForPreview = [[notification.userInfo objectForKey:@"showDoc"] isEqualToString:@"Yes"];
    if (isDocumentForPreview)
    {
        DocumentViewController *doc = [[DocumentViewController alloc] initWithNibName:kFDDocumentViewController_NibName bundle:[NSBundle mainBundle]];
        [doc setCmisObjectId:[notification.userInfo objectForKey:@"downloadObjectId"]];
        
        DownloadInfo *info = [notification.userInfo objectForKey:@"downloadInfo"];
        [doc setContentMimeType:info.repositoryItem.contentStreamMimeType];
        [doc setCanEditDocument:info.repositoryItem.canSetContentStream];
        [doc setHidesBottomBarWhenPushed:YES];
        [doc setPresentNewDocumentPopover:self.presentNewDocumentPopover];
        [doc setSelectedAccountUUID:info.selectedAccountUUID];
        [doc setTenantID:info.tenantID];
        [doc setShowReviewButton:NO];
        
        DownloadMetadata *fileMetadata = info.downloadMetadata;
        NSString *filename = fileMetadata.key;
        [doc setFileMetadata:fileMetadata];
        [doc setFileName:filename];
        [doc setFilePath:info.tempFilePath];
        [doc setIsRestrictedDocument:[[AlfrescoMDMLite sharedInstance] isRestrictedDocument:fileMetadata]];
        
        [IpadSupport pushDetailController:doc withNavigation:self.navigationController andSender:self];
        [doc release];
    }
    [self updateCellDetails:indexPath];
    
    [self.tableView setAllowsSelection:YES];
    [self setPresentNewDocumentPopover:NO];
}

- (void)downloadStarted:(NSNotification *)notification
{
    NSIndexPath *indexPath = [self indexPathForNodeWithGuid:[notification.userInfo objectForKey:@"downloadObjectId"]];
    FavoriteTableViewCell *cell = (FavoriteTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    FavoriteTableCellWrapper *cellWrapper = [self.repositoryItems objectAtIndex:indexPath.row];
    
    [[FavoriteDownloadManager sharedManager] setProgressIndicator:cell.progressBar forObjectId:[notification.userInfo objectForKey:@"downloadObjectId"]];
    
    [cell.progressBar setProgress:[[FavoriteDownloadManager sharedManager] currentProgressForObjectId:[notification.userInfo objectForKey:@"downloadObjectId"]]];

    [cellWrapper setActivityType:SyncActivityTypeDownload];
    [cellWrapper setIsActivityInProgress:YES];
    
    if ([notification.userInfo objectForKey:@"isPreview"] == nil)
    {
        [self updateSyncStatus:SyncStatusLoading forRow:indexPath];
    }
    else 
    {
        [cellWrapper setIsPreviewInProgress:YES];
    }
    
    [self updateCellDetails:indexPath];
    
    [self.tableView setAllowsSelection:NO];
    [self setPresentNewDocumentPopover:NO];
}

#pragma mark - Preview Manager Delegates

- (void)previewManager:(PreviewManager *)manager downloadCancelled:(DownloadInfo *)info
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:info, @"downloadInfo", info.cmisObjectId, @"downloadObjectId",@"Yes", @"isPreview", nil];
    
    [self downloadCancelled: [NSNotification notificationWithName:@"" object:nil userInfo:userInfo]];
    
    [manager setProgressIndicator:nil];
}

- (void)previewManager:(PreviewManager *)manager downloadStarted:(DownloadInfo *)info
{
    NSIndexPath *indexPath = [self indexPathForNodeWithGuid:info.repositoryItem.guid];
    FavoriteTableViewCell *cell = (FavoriteTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    [manager setProgressIndicator:cell.progressBar];
    [cell.progressBar setProgress:manager.currentProgress];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:info, @"downloadInfo",info.cmisObjectId, @"downloadObjectId",@"Yes", @"isPreview", nil];
    [self downloadStarted: [NSNotification notificationWithName:@"" object:nil userInfo:userInfo]];
}

- (void)previewManager:(PreviewManager *)manager downloadFinished:(DownloadInfo *)info
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:info, @"downloadInfo", info.cmisObjectId, @"downloadObjectId", @"Yes", @"showDoc", @"Yes", @"isPreview", nil];
    [self downloadFinished: [NSNotification notificationWithName:@"" object:nil userInfo:userInfo]];
}

- (void)previewManager:(PreviewManager *)manager downloadFailed:(DownloadInfo *)info withError:(NSError *)error
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:info, @"downloadInfo", info.cmisObjectId, @"downloadObjectId", error, @"downloadError", @"Yes", @"isPreview", nil];
    [self downloadFailed: [NSNotification notificationWithName:@"" object:nil userInfo:userInfo]];
}

#pragma mark - Upload Manager Notifications 

- (void) uploadStarted:(NSNotification *)notification
{
    UploadInfo *uploadInfo = [[notification userInfo] objectForKey:@"uploadInfo"];
    NSIndexPath *indexPath = [self indexPathForNodeWithGuid:uploadInfo.repositoryItem.guid];
    
    FavoriteTableViewCell *cell = (FavoriteTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    FavoriteTableCellWrapper *cellWrapper = [self.repositoryItems objectAtIndex:indexPath.row];
    
    [uploadInfo.uploadRequest setUploadProgressDelegate:cell.progressBar];

    [cellWrapper setActivityType:SyncActivityTypeUpload];
    [cellWrapper setIsActivityInProgress:YES];

    [self updateSyncStatus:SyncStatusLoading forRow:indexPath];
    [self updateCellDetails:indexPath];
    
    [self.tableView setAllowsSelection:NO];
    [self setPresentNewDocumentPopover:NO];
    
}

- (void) uploadFinished:(NSNotification *)notification
{
    UploadInfo *uploadInfo = [[notification userInfo] objectForKey:@"uploadInfo"];
    NSIndexPath *indexPath = [self indexPathForNodeWithGuid:uploadInfo.repositoryItem.guid];
    
    FavoriteTableCellWrapper *cellWrapper = [self.repositoryItems objectAtIndex:indexPath.row];
    
    [uploadInfo.uploadRequest setUploadProgressDelegate:nil];

    [cellWrapper setActivityType:SyncActivityTypeIdle];
    [cellWrapper setIsActivityInProgress:NO];
    [cellWrapper setRepositoryItem:uploadInfo.repositoryItem];

    [self updateSyncStatus:SyncStatusSuccessful forRow:indexPath];
    [self updateCellDetails:indexPath];
    
    [self.tableView setAllowsSelection:YES];
    [self setPresentNewDocumentPopover:NO];
}

- (void) uploadFailed:(NSNotification *)notification
{
    UploadInfo *uploadInfo = [[notification userInfo] objectForKey:@"uploadInfo"];
    NSIndexPath *indexPath = [self indexPathForNodeWithGuid:uploadInfo.repositoryItem.guid];
    FavoriteTableCellWrapper *cellWrapper = [self.repositoryItems objectAtIndex:indexPath.row];
    
    [uploadInfo.uploadRequest setUploadProgressDelegate:nil];

    [cellWrapper setActivityType:SyncActivityTypeUpload];
    [cellWrapper setIsActivityInProgress:NO];

    [self updateSyncStatus:SyncStatusFailed forRow:indexPath];
    [self updateCellDetails:indexPath];
    
    [self.tableView setAllowsSelection:YES];
    [self setPresentNewDocumentPopover:NO];
    
}

- (void) uploadCancelled:(NSNotification *)notification
{
    
    UploadInfo *uploadInfo = [[notification userInfo] objectForKey:@"uploadInfo"];
    NSIndexPath *indexPath = [self indexPathForNodeWithGuid:uploadInfo.repositoryItem.guid];
    FavoriteTableCellWrapper *cellWrapper = [self.repositoryItems objectAtIndex:indexPath.row];
    
    [uploadInfo.uploadRequest setUploadProgressDelegate:nil];

    [cellWrapper setActivityType:SyncActivityTypeUpload];
    [cellWrapper setIsActivityInProgress:NO];

    [self updateSyncStatus:SyncStatusCancelled forRow:indexPath];
    [self updateCellDetails:indexPath];   
    
    [self.tableView setAllowsSelection:YES];
    [self setPresentNewDocumentPopover:NO];
    
}

#pragma mark - helper Methods

- (NSIndexPath *)indexPathForNodeWithGuid:(NSString *)itemGuid
{
    NSIndexPath *indexPath = nil;
    NSArray *items = [self repositoryItems];
    
    if (itemGuid != nil && items != nil)
    {
        // Define a block predicate to search for the item being viewed
        BOOL (^matchesRepostoryItem)(FavoriteTableCellWrapper *, NSUInteger, BOOL *) = ^ (FavoriteTableCellWrapper *cellWrapper, NSUInteger idx, BOOL *stop)
        {
            BOOL matched = NO;
            RepositoryItem *repositoryItem = [cellWrapper anyRepositoryItem];
            if ([[repositoryItem guid] isEqualToString:itemGuid] == YES)
            {
                matched = YES;
                *stop = YES;
            }
            return matched;
        };
        
        // See if there's an item in the list with a matching guid, using the block defined above
        NSUInteger matchingIndex = [items indexOfObjectPassingTest:matchesRepostoryItem];
        if (matchingIndex != NSNotFound)
        {
            indexPath = [NSIndexPath indexPathForRow:matchingIndex inSection:0];
        }
    }
    
    return indexPath;
}

- (void)updateSyncStatus:(SyncStatus)status forRow:(NSIndexPath *)indexPath
{
    FavoriteTableViewCell *cell = (FavoriteTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    FavoriteTableCellWrapper *cellWrapper = [self.repositoryItems objectAtIndex:indexPath.row];
    
    [cellWrapper updateSyncStatus:status forCell:cell];
}

- (void)updateCellDetails:(NSIndexPath *)indexPath
{
    FavoriteTableViewCell *cell = (FavoriteTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    FavoriteTableCellWrapper *cellWrapper = [self.repositoryItems objectAtIndex:indexPath.row];
    
    [cellWrapper updateCellDetails:cell];
}

@end

