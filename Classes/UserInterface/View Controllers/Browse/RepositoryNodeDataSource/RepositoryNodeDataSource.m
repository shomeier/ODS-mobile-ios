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
//  RepositoryNodeDataSource.m
//

#import "RepositoryNodeDataSource.h"
#import "FolderItemsHTTPRequest.h"
#import "LinkRelationService.h"
#import "RepositoryItemCellWrapper.h"
#import "UploadInfo.h"
#import "UploadsManager.h"
#import "Utility.h"
#import "CMISObjectAndChildrenRequest.h"

UITableViewRowAnimation const kRepositoryNodeDataSourceAnimation = UITableViewRowAnimationFade;

@interface RepositoryNodeDataSource ()
/*
 Reload Request Factory selectors
 */
- (id)folderItemsHTTPRequest;
- (id)objectByIdRequest;
- (id)objectByPathRequest;
@end

@implementation RepositoryNodeDataSource
@synthesize nodeChildren = _nodeChildren;
@synthesize repositoryNode = _repositoryNode;
@synthesize reloadRequest = _reloadRequest;
@synthesize repositoryItems = _repositoryItems;
@synthesize selectedAccountUUID = _selectedAccountUUID;
@synthesize tenantID = _tenantID;
@synthesize tableView = _tableView;
@synthesize HUD = _HUD;
@synthesize delegate = _delegate;
@synthesize reloadRequestFactory = _reloadRequestFactory;
@synthesize objectId = _objectId;
@synthesize cmisPath = _cmisPath;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_nodeChildren release];
    [_repositoryNode release];
    [_reloadRequest release];
    [_repositoryItems release];
    [_selectedAccountUUID release];
    [_tenantID release];
    [_tableView release];
    [_HUD release];
    [_objectId release];
    [_cmisPath release];
    [super dealloc];
}

- (id)init
{
    return [self initWithSelectedAccountUUID:nil tenantID:nil];
}

//This is the designated initializer
- (id)initWithSelectedAccountUUID:(NSString *)selectedAccountUUID tenantID:(NSString *)tenantID;
{
    self = [super init];
    if(self)
    {
        _repositoryItems = [[NSMutableArray alloc] init];
        _selectedAccountUUID = [selectedAccountUUID copy];
        _tenantID = [tenantID copy];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadQueueChanged:) name:kNotificationUploadQueueChanged object:nil];
    }
    return self;
}

- (id)initWithRepositoryItem:(RepositoryItem *)repositoryNode andSelectedAccount:(NSString *)selectedAccountUUID
{
    self = [self initWithSelectedAccountUUID:selectedAccountUUID tenantID:nil];
    if(self)
    {
        _repositoryNode = [repositoryNode retain];
        _reloadRequestFactory = @selector(folderItemsHTTPRequest);
    }
    return self;
}

- (id)folderItemsHTTPRequest
{
    NSDictionary *optionalArguments = [[LinkRelationService shared] 
                                       optionalArgumentsForFolderChildrenCollectionWithMaxItems:nil skipCount:nil filter:nil 
                                       includeAllowableActions:YES includeRelationships:NO renditionFilter:nil orderBy:nil includePathSegment:NO];
    NSURL *getChildrenURL = [[LinkRelationService shared] getChildrenURLForCMISFolder:self.repositoryNode 
                                                                withOptionalArguments:optionalArguments];

    FolderItemsHTTPRequest *down = [[[FolderItemsHTTPRequest alloc] initWithURL:getChildrenURL accountUUID:self.selectedAccountUUID] autorelease];
    [down setDelegate:self];
    [down setDidFinishSelector:@selector(repositoryNodeRequestFinished:)];
    [down setDidFailSelector:@selector(repositoryNodeRequestFailed:)];
    [down setItem:self.repositoryNode];
    [down setParentTitle:[self.repositoryNode title]];
    return down;
}

- (id)initWithObjectId:(NSString *)objectId selectedAccount:(NSString *)uuid tenantID:(NSString *)tenantID
{
    self = [self initWithSelectedAccountUUID:uuid tenantID:tenantID];
    if(self)
    {
        _reloadRequestFactory = @selector(objectByIdRequest);
        _objectId = [objectId copy];
    }
    return self;
}

- (id)objectByIdRequest
{
    CMISObjectAndChildrenRequest *request = [[[CMISObjectAndChildrenRequest alloc] 
                                              initWithObjectId:self.objectId accountUUID:self.selectedAccountUUID tenantID:self.tenantID] autorelease];
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(repositoryNodeRequestFinished:)];
    [request setDidFailSelector:@selector(repositoryNodeRequestFailed:)];
    return request;
}

- (id)initWithCMISPath:(NSString *)cmisPath selectedAccount:(NSString *)uuid tenantID:(NSString *)tenantID
{
    self = [self initWithSelectedAccountUUID:uuid tenantID:tenantID];
    if(self)
    {
        _reloadRequestFactory = @selector(objectByPathRequest);
        _cmisPath = [cmisPath copy];
    }
    return self;
}

- (id)objectByPathRequest
{
    CMISObjectAndChildrenRequest *request = [[[CMISObjectAndChildrenRequest alloc] 
                                              initWithPath:self.cmisPath accountUUID:self.selectedAccountUUID tenantID:self.tenantID] autorelease];
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(repositoryNodeRequestFinished:)];
    [request setDidFailSelector:@selector(repositoryNodeRequestFailed:)];
    return request;
}

- (void)preLoadChildren:(NSArray *)children
{
    [self setNodeChildren:children];
    [self initRepositoryWrappersWithRepositoryItems:children];
    [self.tableView reloadData];
}

- (void)reloadDataSource
{
    if(self.reloadRequestFactory)
    {
        [self startHUD];
        [self.reloadRequest clearDelegatesAndCancel];
        [self setReloadRequest:[self performSelector:self.reloadRequestFactory]];
        [self.reloadRequest startAsynchronous];
    }
}

- (BOOL)isReloading
{
    return self.HUD != nil;
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    
    return [self.repositoryItems count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	RepositoryItemCellWrapper *cellWrapper = nil;
    cellWrapper = [self.repositoryItems objectAtIndex:indexPath.row];
    
    return [cellWrapper createCellInTableView:tableView];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	RepositoryItemCellWrapper *cellWrapper = nil;
    cellWrapper = [self.repositoryItems objectAtIndex:indexPath.row];
    
    return cellWrapper.uploadInfo == nil || cellWrapper.uploadInfo.uploadStatus == UploadInfoStatusUploaded;
}

#pragma mark - ASIHTTPRequest Delegate Methods
- (void)repositoryNodeRequestFinished:(id)request
{
    _GTMDevLog(@"Repository Node request finished");
    [self setNodeChildren:[request children]];
    [self initRepositoryWrappersWithRepositoryItems:[request children]];
    [self setRepositoryNode:[request item]];
    [self.tableView reloadData];
    [self stopHUD];
    
    [self.delegate dataSourceFinishedLoadingWithSuccess:YES];
}

- (void)repositoryNodeRequestFailed:(id)request
{
    _GTMDevLog(@"Repository Node request failed with error: %@", [request error]);
    [self setNodeChildren:[NSArray array]];
    [self setRepositoryItems:[NSMutableArray array]];
    [self setRepositoryNode:nil];
    [self.tableView reloadData];
    [self stopHUD];
    
    [self.delegate dataSourceFinishedLoadingWithSuccess:NO];
}

- (void)initRepositoryWrappersWithRepositoryItems:(NSArray *)repositoryItems
{
    NSMutableArray *allItems = [NSMutableArray arrayWithCapacity:[repositoryItems count]];
    for(RepositoryItem *child in repositoryItems)
    {
        RepositoryItemCellWrapper *cellWrapper = [[RepositoryItemCellWrapper alloc] initWithRepositoryItem:child];
        [cellWrapper setItemTitle:child.title];
        [allItems addObject:cellWrapper];
        [cellWrapper release];
    }
    
    [self setRepositoryItems:allItems];
    NSArray *activeUploads = [[UploadsManager sharedManager] uploadsInUplinkRelation:[self.repositoryNode identLink]];
    [self addUploadsToRepositoryItems:activeUploads insertCells:NO];
}

- (void)addUploadsToRepositoryItems:(NSArray *)uploads insertCells:(BOOL)insertCells
{
    @synchronized(self.repositoryItems)
    {
        for(UploadInfo *uploadInfo in uploads)
        {
            RepositoryItemCellWrapper *cellWrapper = [[RepositoryItemCellWrapper alloc] initWithUploadInfo:uploadInfo];
            [cellWrapper setItemTitle:[uploadInfo completeFileName]];
            
            NSComparator comparator = ^(RepositoryItemCellWrapper *obj1, RepositoryItemCellWrapper *obj2) {
                
                return (NSComparisonResult)[obj1.itemTitle caseInsensitiveCompare:obj2.itemTitle];
            };
            
            NSMutableArray *repositoryItems = [self repositoryItems];
            NSUInteger newIndex = [repositoryItems indexOfObject:cellWrapper
                                                   inSortedRange:(NSRange){0, [repositoryItems count]}
                                                         options:NSBinarySearchingInsertionIndex
                                                 usingComparator:comparator];
            [repositoryItems insertObject:cellWrapper atIndex:newIndex];
            [cellWrapper release];
        }
        
        if(insertCells)
        {
            NSMutableArray *newIndexPaths = [NSMutableArray arrayWithCapacity:[uploads count]];
            // We get the final index of all of the inserted uploads
            for(UploadInfo *uploadInfo in uploads)
            {
                NSUInteger index = [self.repositoryItems indexOfObjectPassingTest:^BOOL(RepositoryItemCellWrapper *obj, NSUInteger idx, BOOL *stop) {
                    if([obj.uploadInfo isEqual:uploadInfo])
                    {
                        *stop = YES;
                        return YES;
                    }
                    
                    return NO;
                }];
                [newIndexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
            }
            //[self.tableView reloadData];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView insertRowsAtIndexPaths:newIndexPaths withRowAnimation:kRepositoryNodeDataSourceAnimation];
                [self.tableView scrollToRowAtIndexPath:[newIndexPaths lastObject] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
            });
        }
    }
}


#pragma mark - NSNotificationCenter methods
- (void)uploadQueueChanged:(NSNotification *) notification
{
    @synchronized(self.repositoryItems)
    {
        // Something in the queue changed, we are interested if a current upload (ghost cell) was cleared
        NSMutableArray *indexPaths = [NSMutableArray array];
        NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
        NSMutableArray *repositoryItems = [self repositoryItems];
        for (NSUInteger index = 0; index < [repositoryItems count]; index++)
        {
            RepositoryItemCellWrapper *cellWrapper = [repositoryItems objectAtIndex:index];
            // We keep the cells for finished uploads and failed uploads
            if (cellWrapper.uploadInfo && [cellWrapper.uploadInfo uploadStatus] != UploadInfoStatusUploaded && ![[UploadsManager sharedManager] isManagedUpload:cellWrapper.uploadInfo.uuid])
            {
                _GTMDevLog(@"We are displaying an upload that is not currently managed");
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
                [indexPaths addObject:indexPath];
                [indexSet addIndex:index];
            }
        }
        
        if ([indexPaths count] > 0)
        {
            [repositoryItems removeObjectsAtIndexes:indexSet];
            [self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:kRepositoryNodeDataSourceAnimation];
        }
    }
}

#pragma mark - HUD Delegate
- (void)startHUD
{
    if(!self.HUD)
    {
        [self setHUD:createAndShowProgressHUDForView(self.tableView)];
    }
}

- (void)stopHUD
{
    if(self.HUD)
    {
        stopProgressHUD(self.HUD);
        [self setHUD:nil];
    }
}
@end