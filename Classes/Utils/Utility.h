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
//  Utility.h
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "MBProgressHUD.h"
#import "SystemNotice.h"

@class ASIHTTPRequest;

//
//  !!!: Lets deprecated this and break it out into different classes
//	!!!: User Preference Profiles? so on can quickly switch locations
//

UIImage *imageForFilename(NSString* filename);
NSString *mimeTypeForFilename(NSString* filename);
NSString *mimeTypeForFilenameWithDefault(NSString* filename, NSString *defaultMimeType);
NSString *createStringByEscapingAmpersandsInsideTagsOfString(NSString *input, NSString *startTag, NSString *endTag);

BOOL isVideoExtension(NSString *extension);
BOOL isAudioExtension(NSString *extension);
BOOL isPhotoExtension(NSString *extension);
BOOL isIWorkExtension(NSString *extension);
BOOL isMimeTypeVideo(NSString *mimeType);

void startSpinner(void);
void stopSpinner(void);

BOOL userPrefShowHiddenFiles(void);
BOOL userPrefShowCompanyHome(void);
BOOL userPrefFullTextSearch(void);
BOOL userPrefValidateSSLCertificate(void);

//Date Functions
NSDate *dateFromIso(NSString *isoDate);
NSString *formatDateTime(NSString *isoDate);
NSString *formatDateTimeFromDate(NSDate *dateObj);
NSString *relativeDate(NSString *isoDate);
NSString *relativeDateFromDate(NSDate *dateObj);
NSString *relativeIntervalFromSeconds(NSTimeInterval seconds);

// Are "useRelativeDate" Setting aware
NSString *formatDocumentDate(NSString *isoDate);
NSString *formatDocumentDateFromDate(NSDate *dateObj);
NSString *changeStringDateToFormat(NSString *stringDate, NSString *currentFormat, NSString *destinationFormat);

NSString *replaceStringWithNamedParameters(NSString *stringTemplate, NSDictionary *namedParameters);
BOOL stringToBoolWithNumericDefault(NSString *string, NSNumber *defaultValue);
BOOL stringToBoolWithDefault(NSString *string, BOOL defaultValue);
NSString *defaultString(NSString *string, NSString *defaultValue);
BOOL addSkipBackupAttributeToItemAtURL(NSURL *URL);

void showConnectionErrorMessage(ASIHTTPRequest *request);
void showConnectionErrorMessageWithError(ASIHTTPRequest *request, NSError *error);
void styleButtonAsDefaultAction(UIBarButtonItem *button);
void styleButtonAsDestructiveAction(UIBarButtonItem *button);

// MBProgressHUD
MBProgressHUD *createProgressHUDForView(UIView *view);
MBProgressHUD *createAndShowProgressHUDForView(UIView *view);
void stopProgressHUD(MBProgressHUD *hud);

/* External API keys */
typedef NS_ENUM(NSUInteger, APIKey)
{
    APIKeyFlurry = 0,
    APIKeyQuickoffice,
    APIKeyAlfrescoCloud,
};

NSString *externalAPIKey(APIKey apiKey);

/* System Notices */
SystemNotice *displayErrorMessage(NSString *message);
SystemNotice *displayErrorMessageWithTitle(NSString *message, NSString *title);
SystemNotice *displayWarningMessageWithTitle(NSString *message, NSString *title);
SystemNotice *displayInformationMessage(NSString *message);
SystemNotice *displayInformationMessageWithTitle(NSString *message, NSString *title);
UIView *activeView(void);
