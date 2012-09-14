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
//  FavoriteManager.h
//

#import <Foundation/Foundation.h>
#import "FavoritesHttpRequest.h"
#import "ASINetworkQueue.h"
#import "CMISServiceManager.h"
@class FavoriteManager;
@class RepositoryItem;

extern NSString * const kFavoriteManagerErrorDomain;
extern NSString * const kSavedFavoritesFile;
extern NSString * const kDidAskToSync;

extern NSString * const kDocumentsUnfavoritedOnServerWithLocalChanges;
extern NSString * const kDocumentsDeletedOnServerWithLocalChanges;

@protocol FavoriteManagerDelegate <NSObject>

@optional
- (void)favoriteManager:(FavoriteManager *)favoriteManager requestFinished:(NSArray *)favorites;
- (void)favoriteManagerRequestFailed:(FavoriteManager *)favoriteManager;
- (void) favoriteUnfavoriteSuccessfull;
- (void) favoriteUnfavoriteUnsuccessfull;

@end

typedef enum 
{
    IsLive,
    IsLocal,
} FavoriteListType;

typedef enum
{
    IsBackgroundSync,
    IsManualSync,
} SyncType;

@interface FavoriteManager : NSObject <CMISServiceManagerListener>
{
    ASINetworkQueue *favoritesQueue;
    NSError *error;
    id<FavoriteManagerDelegate> delegate;
    
    id<FavoriteManagerDelegate> favoriteUnfavoriteDelegate;

    NSInteger requestCount;
    NSInteger requestsFailed;
    NSInteger requestsFinished;

    BOOL showOfflineAlert;
    BOOL loadedRepositoryInfos;
    
}

@property (nonatomic, retain) ASINetworkQueue *favoritesQueue;
@property (nonatomic, retain) NSError *error;
@property (nonatomic, assign) id<FavoriteManagerDelegate> delegate;

@property (nonatomic, retain) NSTimer * syncTimer;

@property (nonatomic, assign) id<FavoriteManagerDelegate> favoriteUnfavoriteDelegate;

@property (nonatomic, retain) NSString * favoriteUnfavoriteAccountUUID;
@property (nonatomic, retain) NSString * favoriteUnfavoriteTenantID;
@property (nonatomic, retain) NSString * favoriteUnfavoriteNode;
@property (nonatomic, assign) NSInteger favoriteOrUnfavorite;

@property (nonatomic, assign) FavoriteListType listType;
@property (nonatomic, assign) SyncType syncType;
@property (nonatomic, retain) NSMutableDictionary * syncObstacles;
/**
 * This method will queue and start the favorites request for all the configured 
 * accounts.
 */
-(void) startFavoritesRequest:(SyncType)requestedSyncType;

-(void) favoriteUnfavoriteNode:(NSString *) node withAccountUUID:(NSString *) accountUUID andTenantID:(NSString *) tenantID favoriteAction:(NSInteger)action;

-(BOOL) updateDocument:(NSURL *)url objectId:(NSString *)objectId accountUUID:(NSString *)accountUUID;

-(void) uploadRepositoryItem: (RepositoryItem*) repositoryItem toAccount:(NSString *) accountUUID withTenantID:(NSString *) tenantID;

-(NSDictionary *) downloadInfoForDocumentWithID:(NSString *) objectID;

-(NSArray *) getFavoritesFromLocalIfAvailable;
-(NSArray *) getLiveListIfAvailableElseLocal;

-(BOOL) didEncounterObstaclesDuringSync;
-(void) saveDeletedFavoriteFileBeforeRemovingFromSync:(NSString *) fileName;
-(void) syncUnfavoriteFileBeforeRemovingFromSync:(NSString *) fileName syncToServer:(BOOL) sync;

/* Utilities */

-(BOOL) isNodeFavorite:(NSString *) nodeRef inAccount:(NSString *) accountUUID;
-(BOOL) isFirstUse;
-(BOOL) isSyncEnabled;
-(void) enableSync:(BOOL)enable;
-(void) showSyncPreferenceAlert;

/**
 * Returns the shared singleton
 */
+ (FavoriteManager *)sharedManager;

@end

