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
//  AbstractUploadsManager.m
//

#import "AbstractUploadsManager.h"


@interface AbstractUploadsManager ()
@property (nonatomic, retain, readwrite) ASINetworkQueue *uploadsQueue;

@end


@implementation AbstractUploadsManager
@synthesize uploadsQueue = _uploadsQueue;
@synthesize configFile = _configFile;
@synthesize allUploadsDictionary = _allUploadsDictionary;
@synthesize taggingQueue = _taggingQueue;
@synthesize nodeDocumentListings = _nodeDocumentListings;
@synthesize addUploadQueue = _addUploadQueue;

- (void)dealloc
{
    [_allUploadsDictionary release];
    [_uploadsQueue release];
    [_configFile release];
    [_taggingQueue release];
    [_nodeDocumentListings release];
    dispatch_release(_addUploadQueue);
    [super dealloc];
}

- (id)initWithConfigFile:(NSString *)file andUploadQueue:(NSString *) queue
{
    self = [super init];
    if(self)
    {
        self.configFile = file;
        [self setAddUploadQueue:dispatch_queue_create([queue cStringUsingEncoding:NSASCIIStringEncoding], NULL)];
        [self setNodeDocumentListings:[NSMutableDictionary dictionary]];
        //We need to restore the uploads data source
        NSString *uploadsStorePath = [FileUtils pathToConfigFile:self.configFile];
        NSData *serializedUploadsData = [NSData dataWithContentsOfFile:uploadsStorePath];
        
        if (serializedUploadsData) 
        {
            //Complete protection for uploads metadata only if it already has data in it
            [[FileProtectionManager sharedInstance] completeProtectionForFileAtPath:uploadsStorePath];
            NSMutableDictionary *deserializedDict = [NSKeyedUnarchiver unarchiveObjectWithData:serializedUploadsData];
            [self setAllUploadsDictionary:deserializedDict];
        }
        if (self.allUploadsDictionary == nil)
        {
            [self setAllUploadsDictionary:[NSMutableDictionary dictionary]];
        }
        
        [self setUploadsQueue:[ASINetworkQueue queue]];
        [self.uploadsQueue setMaxConcurrentOperationCount:2];
        [self.uploadsQueue setDelegate:self];
        [self.uploadsQueue setShowAccurateProgress:YES];
        [self.uploadsQueue setShouldCancelAllRequestsOnFailure:NO];
        [self.uploadsQueue setRequestDidFailSelector:@selector(requestFailed:)];
        [self.uploadsQueue setRequestDidFinishSelector:@selector(requestFinished:)];
        [self.uploadsQueue setRequestDidStartSelector:@selector(requestStarted:)];
        [self.uploadsQueue setQueueDidFinishSelector:@selector(queueFinished:)];
        
        [self setTaggingQueue:[ASINetworkQueue queue]];
        [self.taggingQueue setMaxConcurrentOperationCount:2];
        [self.taggingQueue setDelegate:self];
        [self.taggingQueue setShowAccurateProgress:YES];
        [self.taggingQueue setShouldCancelAllRequestsOnFailure:NO];
        [self.taggingQueue setRequestDidFailSelector:@selector(requestFailed:)];
        [self.taggingQueue setRequestDidFinishSelector:@selector(requestFinished:)];
        [self.taggingQueue setQueueDidFinishSelector:@selector(queueFinished:)];
        [self initQueue];
    }
    return self;
}

- (NSArray *)allUploads
{
    return [self.allUploadsDictionary allValues];
}

- (NSArray *)filterUploadsWithPredicate:(NSPredicate *)predicate
{
    NSArray *allUploads = [self allUploads];
    return [allUploads filteredArrayUsingPredicate:predicate];
}

- (NSArray *)activeUploads
{
    NSPredicate *activePredicate = [NSPredicate predicateWithFormat:@"uploadStatus == %@ OR uploadStatus == %@", [NSNumber numberWithInt:UploadInfoStatusActive], [NSNumber numberWithInt:UploadInfoStatusUploading]];
    return [self filterUploadsWithPredicate:activePredicate];
}

- (NSArray *)uploadsInUplinkRelation:(NSString *)upLinkRelation
{
    NSArray *activeUploads = [self allUploads];
    NSPredicate *uplinkPredicate = [NSPredicate predicateWithFormat:@"upLinkRelation == %@", upLinkRelation];
    NSArray *uploadsInSameUplink = [activeUploads filteredArrayUsingPredicate:uplinkPredicate];
    
    return uploadsInSameUplink;
}

- (NSArray *)failedUploads
{
    NSPredicate *failedPredicate = [NSPredicate predicateWithFormat:@"uploadStatus == %@", [NSNumber numberWithInt:UploadInfoStatusFailed]];
    return [self filterUploadsWithPredicate:failedPredicate];
}

- (BOOL)isManagedUpload:(NSString *)uuid
{
    return [self.allUploadsDictionary objectForKey:uuid] != nil;
}

- (void)addUploadToManaged:(UploadInfo *)uploadInfo httpMethod:(NSString *) method
{
    [self.allUploadsDictionary setObject:uploadInfo forKey:uploadInfo.uuid];
    
    CMISUploadFileHTTPRequest *request = [CMISUploadFileHTTPRequest cmisUploadRequestWithUploadInfo:uploadInfo];
    [request setRequestMethod:method];
    [request setCancelledPromptPasswordSelector:@selector(cancelledPasswordPrompt:)];
    [request setPromptPasswordDelegate:self];
    //[ASIHTTPRequest throttleBandwidthForWWANUsingLimit:14];
    [uploadInfo setUploadStatus:UploadInfoStatusActive];
    [uploadInfo setUploadRequest:request];
    [self.uploadsQueue addOperation:request];
}

- (void)queueUpload:(UploadInfo *)uploadInfo
{
        [self addUploadToManaged:uploadInfo httpMethod:@"POST"];
        
        [self saveUploadsData];
        // We call go to the queue to start it, if the queue has already started it will not have any effect in the queue.
        [self.uploadsQueue go];
        _GTMDevLog(@"Starting the upload for file %@ with uuid %@", [uploadInfo completeFileName], [uploadInfo uuid]);
        
     
}

- (void)queueUploadArray:(NSArray *)uploads
{
        [self.uploadsQueue setSuspended:YES];
        for(UploadInfo *uploadInfo in uploads)
        {
            [self addUploadToManaged:uploadInfo httpMethod:@"POST"];
        }
        
        [self saveUploadsData];
        // We call go to the queue to start it, if the queue has already started it will not have any effect in the queue.
        [self.uploadsQueue go];
        _GTMDevLog(@"Starting the upload of %d items", [uploads count]);
         
}

-(void) queueUpdateUpload:(UploadInfo *)uploadInfo
{
    [self addUploadToManaged:uploadInfo httpMethod:@"PUT"];
    
    [self saveUploadsData];
    // We call go to the queue to start it, if the queue has already started it will not have any effect in the queue.
    [self.uploadsQueue go];
    _GTMDevLog(@"Starting the upload for file %@ with uuid %@", [uploadInfo completeFileName], [uploadInfo uuid]);
    
}

- (void)clearUpload:(NSString *)uploadUUID
{
    UploadInfo *uploadInfo = [self.allUploadsDictionary objectForKey:uploadUUID];
    [self.allUploadsDictionary removeObjectForKey:uploadUUID];
    
    if(uploadInfo.uploadRequest)
    {
        [uploadInfo.uploadRequest clearDelegatesAndCancel];
        CGFloat remainingBytes = [uploadInfo.uploadRequest postLength] - [uploadInfo.uploadRequest totalBytesSent];
        [self.uploadsQueue setTotalBytesToUpload:[self.uploadsQueue totalBytesToUpload]-remainingBytes ];
    }
    
    
    [self saveUploadsData];
    
}

- (void)clearUploads:(NSArray *)uploads
{
    if([[uploads lastObject] isKindOfClass:[NSString class]])
    {
        [self.allUploadsDictionary removeObjectsForKeys:uploads];
        [self saveUploadsData];        
    }
}

- (void)cancelActiveUploads
{
    NSArray *activeUploads = [self activeUploads];
    for(UploadInfo *activeUpload in activeUploads)
    {
        [self.allUploadsDictionary removeObjectForKey:activeUpload.uuid];
    }
    [self saveUploadsData];
    
    [self.uploadsQueue cancelAllOperations];
}

- (void)cancelActiveUploadsForAccountUUID:(NSString *)accountUUID
{
    [self.uploadsQueue setSuspended:YES];
    NSArray *activeUploads = [self activeUploads];
    for (UploadInfo *activeUpload in activeUploads)
    {
        if ([activeUpload.selectedAccountUUID isEqualToString:accountUUID])
        {
            [activeUpload.uploadRequest cancel];
            [self.allUploadsDictionary removeObjectForKey:activeUpload.uuid];
        }
    }
    
    [self.uploadsQueue setSuspended:NO];
}

- (BOOL)retryUpload:(NSString *)uploadUUID
{
    UploadInfo *uploadInfo = [self.allUploadsDictionary objectForKey:uploadUUID];
    
    NSString *uploadPath = [uploadInfo.uploadFileURL path];
    if(!uploadInfo || ![[NSFileManager defaultManager] fileExistsAtPath:uploadPath])
    {
        // We clear the upload since there's no reason to keep the upload visible
        if(uploadInfo)
        {
            [self clearUpload:uploadUUID];
        }
        UIAlertView *noFileAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"uploads.cancelAll.title", @"Uploads") message:@"The selected upload has been deleted from the temp folder, please try again from the Upload menu in the + button above" delegate:nil cancelButtonTitle:NSLocalizedString(@"Close", @"Close") otherButtonTitles:nil];
        [noFileAlert show];
        [noFileAlert release];
        return NO;
    }
    [self queueUpload:uploadInfo];
    
    return YES;
}

- (void)setQueueProgressDelegate:(id<ASIProgressDelegate>)progressDelegate
{
    [self.uploadsQueue setUploadProgressDelegate:progressDelegate];
}

- (void)setExistingDocuments:(NSArray *)documentNames forUpLinkRelation:(NSString *)upLinkRelation;
{
    [self.nodeDocumentListings setObject:documentNames forKey:upLinkRelation];
}

- (NSArray *)existingDocumentsForUplinkRelation:(NSString *)upLinkRelation
{
    NSArray *existingDocuments = [self.nodeDocumentListings objectForKey:upLinkRelation];    
    
    NSPredicate *uplinkPredicate = [NSPredicate predicateWithFormat:@"upLinkRelation == %@", upLinkRelation];
    NSArray *uploadsInSameUplink = [[self allUploads] filteredArrayUsingPredicate:uplinkPredicate];
    NSMutableSet *managedUploadNames = [NSMutableSet setWithArray:existingDocuments];
    
    for(UploadInfo *uploadInfo in uploadsInSameUplink)
    {
        NSString *filename = [uploadInfo completeFileName];
        if([filename isNotEmpty])
        {
            [managedUploadNames addObject:filename];
        }
    }
    
    return [NSArray arrayWithArray:[managedUploadNames allObjects]];
}

#pragma mark - ASINetworkQueueDelegateMethod
- (void)requestStarted:(CMISUploadFileHTTPRequest *)request
{
    UploadInfo *uploadInfo = request.uploadInfo;
    [uploadInfo setUploadStatus:UploadInfoStatusUploading];
    [self saveUploadsData];
    
}

- (void)requestFinished:(BaseHTTPRequest *)request 
{
    if([request isKindOfClass:[CMISUploadFileHTTPRequest class]])
    {
        UploadInfo *uploadInfo = [(CMISUploadFileHTTPRequest *)request uploadInfo];
        _GTMDevLog(@"Successful upload for file %@ and uuid %@", [uploadInfo completeFileName], [uploadInfo uuid]);
        RepositoryItemParser *itemParser = [[RepositoryItemParser alloc] initWithData:request.responseData];
        RepositoryItem *repositoryItem = [itemParser parse];
        [itemParser release];
        [uploadInfo setCmisObjectId:repositoryItem.guid];
        [uploadInfo setRepositoryItem:repositoryItem];
        [uploadInfo setUploadRequest:nil];
        [self saveUploadsData];
        
        if([uploadInfo.tags count] > 0)
        {
            _GTMDevLog(@"Starting the tagging request for file %@ and tags %@", [uploadInfo completeFileName], [uploadInfo tags]);
            [self startTaggingRequestWithUploadInfo:uploadInfo];
        }
        else 
        {
            // If no tags were selected, we procceed to mark the upload as success
            [self successUpload:uploadInfo];
        }
        
        _GTMDevLog(@"Starting the Action Service extract-metadata request for file %@", [uploadInfo completeFileName]);
        [self startActionServiceRequestWithUploadInfo:uploadInfo];
    }
    else if([request isKindOfClass:[TaggingHttpRequest class]])
    {
        NSString *uploadUUID = [(TaggingHttpRequest *)request uploadUUID];
        UploadInfo *uploadInfo = [self.allUploadsDictionary objectForKey:uploadUUID];
        // Mark the upload as success after a successful tagging request
        [self successUpload:uploadInfo];
    }
    else if([request isKindOfClass:[ActionServiceHTTPRequest class]])
    {
        _GTMDevLog(@"The Action Service extract-metadata request was successful for request %@", [request responseString]);
    }
}

- (void)requestFailed:(BaseHTTPRequest *)request 
{
    // Only if the file upload failed we mark it as a failed upload
    if([request isKindOfClass:[CMISUploadFileHTTPRequest class]])
    {
        // Do something different with the error if there's no connection available?
        if(([request.error code] == ASIConnectionFailureErrorType || [request.error code] == ASIRequestTimedOutErrorType))
        {
        }
        
        UploadInfo *uploadInfo = [(CMISUploadFileHTTPRequest *)request uploadInfo];
        [uploadInfo setUploadRequest:nil];
        [self failedUpload:uploadInfo withError:request.error];
    }
    else if([request isKindOfClass:[TaggingHttpRequest class]]) 
    {
        //We want to ignore the tagging fails, might change in the future
        NSString *uploadUUID = [(TaggingHttpRequest *)request uploadUUID];
        UploadInfo *uploadInfo = [self.allUploadsDictionary objectForKey:uploadUUID];
        [uploadInfo setUploadRequest:nil];
        // Mark the upload as success after a failed tagging request
        [self successUpload:uploadInfo];
    }
    else if([request isKindOfClass:[ActionServiceHTTPRequest class]])
    {
        NSLog(@"The Action Service extract-metadata request failed for request %@ and error: %@", [request postBody], [request error]);
    }
}

- (void)queueFinished:(ASINetworkQueue *)queue 
{
    [queue cancelAllOperations];
}

#pragma mark - private methods
- (void)initQueue
{
    CMISUploadFileHTTPRequest *request = nil;
    BOOL pendingUploads = NO;
    
    for(UploadInfo *uploadInfo in [self.allUploadsDictionary allValues])
    {
        // Only Active uploads should be initialized, included the Inactive ones just to be sure
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[uploadInfo.uploadFileURL absoluteString]];
        BOOL accountExists = [[AccountManager sharedManager] accountInfoForUUID:uploadInfo.selectedAccountUUID] != nil;
        
        if((uploadInfo.uploadStatus == UploadInfoStatusActive || uploadInfo.uploadStatus == UploadInfoStatusInactive) && fileExists && accountExists)
        {
            [uploadInfo setUploadStatus:UploadInfoStatusActive];
            
            if(uploadInfo.cmisObjectId)
            {
                // Means that the upload was complete but the tagging request was never finished
                [self startTaggingRequestWithUploadInfo:uploadInfo];
            }
            else {
                request = [CMISUploadFileHTTPRequest cmisUploadRequestWithUploadInfo:uploadInfo];
                [self.uploadsQueue addOperation:request];
            }
            
            pendingUploads = YES;
        }
        else if(uploadInfo.uploadStatus != UploadInfoStatusFailed)
        {
            [self.allUploadsDictionary removeObjectForKey:uploadInfo.uuid];
        }
    }
    
    [self saveUploadsData];
    
    if(pendingUploads)
    {
        [self.uploadsQueue go];
    }
}

- (void)saveUploadsData
{
    NSString *uploadsStorePath = [FileUtils pathToConfigFile:self.configFile];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.allUploadsDictionary];
    [data writeToFile:uploadsStorePath atomically:YES];
    //Complete protection for uploads metadata
    [[FileProtectionManager sharedInstance] completeProtectionForFileAtPath:uploadsStorePath];
}

- (void)startTaggingRequestWithUploadInfo:(UploadInfo *)uploadInfo
{
    TaggingHttpRequest *request = [TaggingHttpRequest httpRequestAddTags:uploadInfo.tags
                                                                  toNode:[NodeRef nodeRefFromCmisObjectId:uploadInfo.cmisObjectId]
                                                             accountUUID:uploadInfo.selectedAccountUUID 
                                                                tenantID:uploadInfo.tenantID];
    [request setUploadUUID:uploadInfo.uuid];
    [self.taggingQueue addOperation:request];
    [self.taggingQueue go];
}

- (void)startActionServiceRequestWithUploadInfo:(UploadInfo *)uploadInfo
{
    ActionServiceHTTPRequest *request = [ActionServiceHTTPRequest requestWithDefinitionName:ActionDefinitionExtractMetadata withNode:uploadInfo.cmisObjectId accountUUID:uploadInfo.selectedAccountUUID  tenantID:uploadInfo.tenantID];
    [self.taggingQueue addOperation:request];
    [self.taggingQueue go];
}

- (void)successUpload:(UploadInfo *)uploadInfo
{
        [uploadInfo setUploadStatus:UploadInfoStatusUploaded];
        
        //We don't manage successfull uploads
        [self.allUploadsDictionary removeObjectForKey:uploadInfo.uuid];
        [self saveUploadsData];
    
}
- (void)failedUpload:(UploadInfo *)uploadInfo withError:(NSError *)error
{
        _GTMDevLog(@"Upload Failed for file %@ and uuid %@ with error: %@", [uploadInfo completeFileName], [uploadInfo uuid], error);
        [uploadInfo setUploadStatus:UploadInfoStatusFailed];
        [uploadInfo setError:error];
        [self saveUploadsData];
        
}

#pragma mark - PasswordPromptQueue callbacks

- (void)cancelledPasswordPrompt:(CMISUploadFileHTTPRequest *)request
{
    [self cancelActiveUploadsForAccountUUID:request.accountUUID];
}

@end