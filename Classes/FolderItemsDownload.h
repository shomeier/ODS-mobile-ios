//
//  ***** BEGIN LICENSE BLOCK *****
//  Version: MPL 1.1
//
//  The contents of this file are subject to the Mozilla Public License Version
//  1.1 (the "License"); you may not use this file except in compliance with
//  the License. You may obtain a copy of the License at
//  http://www.mozilla.org/MPL/
//
//  Software distributed under the License is distributed on an "AS IS" basis,
//  WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
//  for the specific language governing rights and limitations under the
//  License.
//
//  The Original Code is the Alfresco Mobile App.
//  The Initial Developer of the Original Code is Zia Consulting, Inc.
//  Portions created by the Initial Developer are Copyright (C) 2011
//  the Initial Developer. All Rights Reserved.
//
//
//  ***** END LICENSE BLOCK *****
//
//
//  FolderItemsDownload.h
//

#import <Foundation/Foundation.h>
#import "AsynchonousDownload.h"
#import "RepositoryItem.h"

@protocol NSXMLParserDelegate;

@interface FolderItemsDownload : AsynchonousDownload<NSXMLParserDelegate>  {
	RepositoryItem *item;
	NSMutableArray *children;
	NSString *currentCMISName;
	NSString *elementBeingParsed;
	NSString *context;
	NSString *parentTitle;
	NSString *valueBuffer;
    NSString *currentNamespaceURI;
}

@property (nonatomic, retain) RepositoryItem *item;
@property (nonatomic, retain) NSMutableArray *children;
@property (nonatomic, retain) NSString *currentCMISName;
@property (nonatomic, retain) NSString *elementBeingParsed;
@property (nonatomic, retain) NSString *context;
@property (nonatomic, retain) NSString *parentTitle;
@property (nonatomic, retain) NSString *valueBuffer;
@property (nonatomic, retain) NSString *currentNamespaceURI;

// TODO: Remove the 1 deprecated method!!!
- (FolderItemsDownload *) initWithNode:(NSString *)node delegate:(id <AsynchronousDownloadDelegate>)del __attribute__ ((deprecated));

- (FolderItemsDownload *)initWithAtomFeedUrlString:(NSString *)urlString delegate:(id <AsynchronousDownloadDelegate>)theDelegate;
@end
