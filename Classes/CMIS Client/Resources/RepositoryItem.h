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
//  RepositoryItem.h
//

#import <Foundation/Foundation.h>

// TODO: Rename this class to a more appropriate class?  CMISAtomEntry? CMISAtomObject?
// TODO: Refactor me so that I better represent the Atom Entry/Feed that I am being populated into

@interface RepositoryItem : NSObject {
@private
	NSString *identLink; // children feed // TODO: DEPRECATE ME USE linkRelations Array with Predicates
	NSString *title;
	NSString *guid;
	NSString *fileType;
	NSString *lastModifiedBy;
	NSString *lastModifiedDate;
	NSString *contentLocation;
	NSString *contentStreamLengthString;
    NSString *versionSeriesId;
	BOOL      canCreateDocument; // REFACTOR: into allowable actions?
	BOOL      canCreateFolder;
    BOOL      canDeleteObject;
	NSMutableDictionary *metadata;
	NSString *describedByURL; // TODO: implement using linkRelations Array with Predicates
	NSString *selfURL; // TODO: implement using linkRelations Array with Predicates
	NSMutableArray *linkRelations;
	
	NSString *node; // !!!: Legacy purposes....
}

@property (nonatomic, retain) NSString *identLink; //__attribute__ ((deprecated));
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *guid;
@property (nonatomic, retain) NSString *fileType;
@property (nonatomic, retain) NSString *lastModifiedBy;
@property (nonatomic, retain) NSString *lastModifiedDate;
@property (nonatomic, retain) NSString *contentLocation;
@property (nonatomic, retain) NSString *contentStreamLengthString;
@property (nonatomic, retain) NSString *versionSeriesId;
@property (nonatomic) BOOL canCreateDocument;
@property (nonatomic) BOOL canCreateFolder;
@property (nonatomic) BOOL canDeleteObject;
@property (nonatomic, retain) NSMutableDictionary *metadata;
@property (nonatomic, retain) NSString *describedByURL; //REFACTOR & DEPRECATE __attribute__ ((deprecated));
@property (nonatomic, retain) NSString *selfURL; //REFACTOR & DEPRECATE__attribute__ ((deprecated));
@property (nonatomic, retain) NSMutableArray *linkRelations;
@property (nonatomic, retain) NSString *node;
@property (nonatomic, readonly) NSString *contentStreamMimeType;

- (BOOL) isFolder;
- (NSComparisonResult) compareTitles:(id) other;
- (NSNumber*) contentStreamLength;
@end
