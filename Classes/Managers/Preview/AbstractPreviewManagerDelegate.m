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
//  AbstractPreviewManagerDelegate.m
//
// Delegate for the previewManager when browsing a repository
// It is reposible of updating the UITableViewCells to reflect the current progress of a document preview load,
// pushing the actual preview of a document into a navigation stack or into the detail view in the iPad
// It will also handle cancelled or failed downloads gracefully.

#import "AbstractPreviewManagerDelegate.h"

@implementation AbstractPreviewManagerDelegate

@synthesize repositoryItems = _repositoryItems;
@synthesize tableView = _tableView;
@synthesize navigationController = _navigationController;
@synthesize presentNewDocumentPopover = _presentNewDocumentPopover;
@synthesize presentEditMode = _presentEditMode;
@synthesize selectedAccountUUID = _selectedAccountUUID;
@synthesize tenantID = _tenantID;

- (void)dealloc
{
    [_repositoryItems release];
    [_tableView release];
    [_navigationController release];
    [_selectedAccountUUID release];
    [_tenantID release];
    [super dealloc];
}

#pragma mark - PreviewManagerDelegate Methods

- (void)previewManager:(PreviewManager *)manager downloadCancelled:(DownloadInfo *)info
{
    NSIndexPath *indexPath = [self getIndexPathForItem:info.repositoryItem]; //[RepositoryNodeUtils indexPathForNodeWithGuid:info.repositoryItem.guid inItems:self.repositoryItems];
    RepositoryItemTableViewCell *cell = (RepositoryItemTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    RepositoryItemCellWrapper *cellWrapper = [self.repositoryItems objectAtIndex:indexPath.row];
    
    [manager setProgressIndicator:nil];
    [cell.progressBar setProgress:0.0f];
    [cell.progressBar setHidden:YES];
    [cell.details setHidden:NO];
    [cell.favIcon setHidden:NO];
    [self setIsDownloadingPreview:NO forWrapper:cellWrapper];
    
    [self.tableView setAllowsSelection:YES];
    [self setPresentNewDocumentPopover:NO];
}

- (void)previewManager:(PreviewManager *)manager downloadFailed:(DownloadInfo *)info withError:(NSError *)error
{
    NSIndexPath *indexPath = [self getIndexPathForItem:info.repositoryItem];
    RepositoryItemTableViewCell *cell = (RepositoryItemTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    RepositoryItemCellWrapper *cellWrapper = [self.repositoryItems objectAtIndex:indexPath.row];
    
    [manager setProgressIndicator:nil];
    [cell.progressBar setProgress:0.0f];
    [cell.progressBar setHidden:YES];
    [cell.details setHidden:NO];
    [cell.favIcon setHidden:NO];
    [self setIsDownloadingPreview:NO forWrapper:cellWrapper];
    
    [self.tableView setAllowsSelection:YES];
    [self setPresentNewDocumentPopover:NO];
}

- (void)previewManager:(PreviewManager *)manager downloadFinished:(DownloadInfo *)info
{
    NSIndexPath *indexPath = [self getIndexPathForItem:info.repositoryItem];
    RepositoryItemTableViewCell *cell = (RepositoryItemTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    RepositoryItemCellWrapper *cellWrapper = [self.repositoryItems objectAtIndex:indexPath.row];
    
    [manager setProgressIndicator:nil];
    [cell.progressBar setProgress:0.0f];
    [cell.progressBar setHidden:YES];
    [cell.details setHidden:NO];
    [cell.favIcon setHidden:NO];
    [self setIsDownloadingPreview:NO forWrapper:cellWrapper];
    
	[self showDocument:info];
    
    [self.tableView setAllowsSelection:YES];
    [self setPresentNewDocumentPopover:NO];
    [self setPresentEditMode:NO];
}

- (void)previewManager:(PreviewManager *)manager downloadStarted:(DownloadInfo *)info
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSIndexPath *indexPath = [self getIndexPathForItem:info.repositoryItem];
        RepositoryItemTableViewCell *cell = (RepositoryItemTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
        RepositoryItemCellWrapper *cellWrapper = [self.repositoryItems objectAtIndex:indexPath.row];
        
        [manager setProgressIndicator:cell.progressBar];
        [cell.progressBar setProgress:manager.currentProgress];
        [cell.details setHidden:YES];
        [cell.favIcon setHidden:YES];
        [cell.progressBar setHidden:NO];
        [self setIsDownloadingPreview:YES forWrapper:cellWrapper];
    });
}

#pragma mark - Show Favourite Document

- (void)showDocument:(DownloadInfo *)info
{
    DocumentViewController *doc = [[DocumentViewController alloc] initWithNibName:kFDDocumentViewController_NibName bundle:[NSBundle mainBundle]];
	[doc setCmisObjectId:info.repositoryItem.guid];
    [doc setCanEditDocument:info.repositoryItem.canSetContentStream];
    [doc setContentMimeType:info.repositoryItem.contentStreamMimeType];
    [doc setHidesBottomBarWhenPushed:YES];
    [doc setPresentNewDocumentPopover:self.presentNewDocumentPopover];
    [doc setPresentEditMode:self.presentEditMode];
    [doc setSelectedAccountUUID:self.selectedAccountUUID];
    [doc setTenantID:self.tenantID];
    [doc setShowReviewButton:NO];
    DownloadMetadata *fileMetadata = info.downloadMetadata;
    NSString *filename = fileMetadata.key;
    [doc setFileMetadata:fileMetadata];
    [doc setFileName:filename];
    [doc setFilePath:info.tempFilePath];
    [doc setIsRestrictedDocument:[[AlfrescoMDMLite sharedInstance] isRestrictedDocument:fileMetadata]];

    // Special case in the iPhone to avoid chained animations when presenting the edit view
    // only right after creating a file, otherwise we animate the transition
    if (!IS_IPAD && self.presentEditMode)
    {
        [self.navigationController pushViewController:doc animated:NO];
    }
    else  
    {
        [IpadSupport pushDetailController:doc withNavigation:self.navigationController andSender:self];
    }
	[doc release];
}

- (NSIndexPath *)getIndexPathForItem:(RepositoryItem *)item
{
    return [RepositoryNodeUtils indexPathForNodeWithGuid:item.guid inItems:self.repositoryItems inSection:0];
}

- (void)setIsDownloadingPreview:(BOOL)downloading forWrapper:(RepositoryItemCellWrapper *)cellWrapper
{
    [cellWrapper setIsDownloadingPreview:downloading];
}

@end
