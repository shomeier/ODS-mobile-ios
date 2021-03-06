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
//  CertificateLocationViewController.h
//
// Provides a UI to choose the method to import a new certificate
// Only two options implemented: Select it from the documents folder or
// by URL

#import "IFGenericTableViewController.h"
#import "SavedDocumentPickerController.h"
#import "ImportCertificateViewController.h"

@interface CertificateLocationViewController : IFGenericTableViewController <UINavigationControllerDelegate, SavedDocumentPickerDelegate>
// Used to get back to a delegate, it reports back if the import was successful or cancelled
@property (nonatomic, assign) id<ImportCertificateDelegate> importDelegate;

/*
 DI: Inits the CertificateLocationViewController with an accountUUID.
 The accountUUID is used to store the certificate imported
 */
- (id)initWithAccountUUID:(NSString *)accountUUID;

@end
