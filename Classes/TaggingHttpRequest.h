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
 * Portions created by the Initial Developer are Copyright (C) 2011
 * the Initial Developer. All Rights Reserved.
 *
 *
 * ***** END LICENSE BLOCK ***** */
//
//  TaggingHttpRequest.h
//

#import <Foundation/Foundation.h>
#import "ASIHTTPRequest+Utils.h"
#import "ASIHttpRequest+Alfresco.h"
#import "JSON.h"
#import "SBJSON.h"
#import "Utility.h"
#import "NodeRef.h"

extern NSString * const kListAllTags;
extern NSString * const kGetNodeTags;
extern NSString * const kAddTagsToNode;
extern NSString * const kCreateTag;

@interface TaggingHttpRequest : ASIHTTPRequest {
@private
    NodeRef *nodeRef;
    NSString *apiMethod;
    NSMutableDictionary *userDictionary;
}

@property (nonatomic, retain) NSString *apiMethod;
@property (nonatomic, readonly) NSDictionary *userDictionary;

- (void)addUserProvidedObject:(id)object forKey:(NSString *)userKey;

//
// GET /alfresco/service/api/node/{store_type}/{store_id}/{id}/tags
// GET /alfresco/service/api/path/{store_type}/{store_id}/{id}/tags
+ (id)httpRequestListAllTags;

//
// POST /alfresco/service/api/tag/{store_type}/{store_id}
+ (id)httpRequestCreateNewTag:(NSString *)tag;

//
// GET /alfresco/service/api/node/{store_type}/{store_id}/{id}/tags
// GET /alfresco/service/api/path/{store_type}/{store_id}/{id}/tags
+ (id)httpRequestGetNodeTagsForNode:(NodeRef *)nodeRef;

//
// POST /alfresco/service/api/node/{store_type}/{store_id}/{id}/tags
// POST /alfresco/service/api/path/{store_type}/{store_id}/{id}/tags
+ (id)httpRequestAddTags:(NSArray *)tags toNode:(NodeRef *)nodeRef;


// Helper Method
+ (NSArray *)tagsArrayWithResponseString:(NSString *)responseString;

@end
