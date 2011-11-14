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
//  Utility.h
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

//
//  !!!: Lets deprecated this and break it out into different classes
//	!!!: User Preference Profiles? so on can quickly switch locations
//

#define IS_IPAD ([[UIDevice currentDevice] respondsToSelector:@selector(userInterfaceIdiom)] && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

UIImage* imageForFilename(NSString* filename);
NSString* mimeTypeForFilename(NSString* filename);

BOOL isVideoExtension(NSString *extension);
BOOL isMimeTypeVideo(NSString *mimeType);

void startSpinner(void);
void stopSpinner(void);

NSString* userPrefUsername(void);
NSString* userPrefPassword(void);
NSString* userPrefHostname(void);
NSString* userPrefPort(void);
NSString* serviceDocumentURIString(void);
BOOL userPrefShowHiddenFiles(void);
BOOL userPrefShowCompanyHome(void);
NSString* userPrefProtocol(void);
BOOL userPrefFullTextSearch(void);
BOOL isIPad(void);
BOOL isPrintingAvailable(void);

//Date Functions
NSDate* dateFromIso(NSString *isoDate);
NSString* formatDateTime(NSString *isoDate);
NSString* formatDateTimeFromDate(NSDate *dateObj);
NSString* relativeDate(NSString *isoDate);
NSString* relativeDateFromDate(NSDate *dateObj);

// Are "useRelativeDate" Setting aware
NSString* formatDocumentDate(NSString *isoDate);
NSString* formatDocumentDateFromDate(NSDate *dateObj);
NSString* changeStringDateToFormat(NSString *stringDate, NSString *currentFormat, NSString *destinationFormat);

NSString* replaceStringWithNamedParameters(NSString *stringTemplate, NSDictionary *namedParameters);

