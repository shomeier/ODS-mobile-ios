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
 *
 * ***** END LICENSE BLOCK ***** */
//
//  DownloadObjectRequest.h
//

#import "BaseHTTPRequest.h"
@class DownloadInfo;

@interface CMISDownloadFileHTTPRequest : BaseHTTPRequest

@property (nonatomic, retain) DownloadInfo *downloadInfo;

+(CMISDownloadFileHTTPRequest *)cmisDownloadRequestWithDownloadInfo:(DownloadInfo *)downloadInfo;

@end
