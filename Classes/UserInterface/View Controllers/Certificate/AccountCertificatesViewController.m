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
//  AccountCertificatesViewController.m
//
//

#import "AccountCertificatesViewController.h"
#import "AccountInfo.h"
#import "TableCellViewController.h"
#import "CertificateManager.h"
#import "CertificateLocationViewController.h"
#import "AccountManager.h"
#import "Utility.h"
#import "IFButtonCellController.h"
#import "FDCertificate.h"

@interface AccountCertificatesViewController ()
@property (nonatomic, retain) AccountInfo *accountInfo;

@end

@implementation AccountCertificatesViewController
@synthesize isNew = _isNew;
@synthesize accountInfo = _accountInfo;

- (void)dealloc
{
    [_accountInfo release];
    [super dealloc];
}

- (id)init
{
    return [self initWithAccountInfo:nil];
}

- (id)initWithAccountInfo:(AccountInfo *)accountInfo
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self)
    {
        _accountInfo = [accountInfo retain];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setTitle:NSLocalizedString(@"certificate-details.title", @"Title for the certificate details view")];
}


- (void)constructTableGroups
{
    NSMutableArray *headers = [NSMutableArray array];
    NSMutableArray *groups = [NSMutableArray array];
    BOOL hasCertificate = NO;
    
    //getting the latest account
    AccountInfo *account = [[AccountManager sharedManager] accountInfoForUUID:self.accountInfo.uuid];
    FDCertificate *certificateWrapper = [account certificateWrapper];
    
    if (certificateWrapper)
    {   
        TableCellViewController *identityCell = [[[TableCellViewController alloc] initWithAction:NULL onTarget:nil] autorelease];
        [identityCell.textLabel setText:certificateWrapper.summary];
        [identityCell.detailTextLabel setText:[NSString stringWithFormat:
                                               NSLocalizedString(@"certificate-details.issuer", @"Issuer message for the Certificate details"), certificateWrapper.issuer]];
        [identityCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        [identityCell setCellHeight:44.0f];
        [identityCell setBackgroundColor:[UIColor whiteColor]];
        [identityCell.textLabel setFont:[UIFont boldSystemFontOfSize:17.0f]];
        [identityCell.imageView setImage:[UIImage imageNamed:@"certificate.png"]];
        
        [headers addObject:NSLocalizedString(@"certificate-details.certificates.header", @"Table header for the certificates group")];
        [groups addObject:[NSMutableArray arrayWithObject:identityCell]];
        hasCertificate = YES;
    }
    
    // Delete button
    if (hasCertificate)
    {
        IFButtonCellController *deleteAccountCell = [[[IFButtonCellController alloc] initWithLabel:NSLocalizedString(@"certificate-details.buttons.delete", @"Delete Certificate")
                                                                                        withAction:@selector(deleteCertificateAction:)
                                                                                          onTarget:self] autorelease];
        [deleteAccountCell setBackgroundColor:[UIColor redColor]];
        [deleteAccountCell setTextColor:[UIColor whiteColor]];
        [headers addObject:@""];
        [groups addObject:[NSMutableArray arrayWithObject:deleteAccountCell]];
    }
    
    // When no certificate is linked, a button to start the import process is displayed
    if (!hasCertificate)
    {
        TableCellViewController *addCertificateCell = [[[TableCellViewController alloc] initWithAction:@selector(addCertificateAction:) onTarget:self] autorelease];
        [addCertificateCell.textLabel setText:
         NSLocalizedString(@"certificate-manage.add-cell.label", @"Certificate Manage - Label for the add certificate cell's label")];
        [addCertificateCell setSelectionStyle:UITableViewCellSelectionStyleBlue];
        [addCertificateCell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [addCertificateCell setCellHeight:44.0f];
        [addCertificateCell setBackgroundColor:[UIColor whiteColor]];
        [addCertificateCell.textLabel setFont:[UIFont boldSystemFontOfSize:17.0f]];
        [addCertificateCell.imageView setImage:[UIImage imageNamed:@"certificate-add.png"]];
        [headers addObject:@""];
        [groups addObject:[NSMutableArray arrayWithObject:addCertificateCell]];
    }
    
    tableHeaders = [headers retain];
    tableGroups = [groups retain];

}

- (void)deleteCertificateAction:(id)sender
{
    UIAlertView *deletePrompt = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"certificate-details.delete.title", @"Title for the delete certificate prompt")
                                                           message:NSLocalizedString(@"certificate-details.delete.message", @"Message for the delete certificate prompt")
                                                          delegate:self
                                                 cancelButtonTitle:NSLocalizedString(@"cancelButton", @"Cancel")
                                                 otherButtonTitles:NSLocalizedString(@"certificate-details.delete.confirm", @"Remove button label for the Remove certificate prompt"), nil] autorelease];
    [deletePrompt show];
}

- (void)addCertificateAction:(id)sender
{
    CertificateLocationViewController *locationController = [[[CertificateLocationViewController alloc] initWithAccountUUID:self.accountInfo.uuid] autorelease];
    [locationController setImportDelegate:self];
    [self.navigationController pushViewController:locationController animated:YES];
}

#pragma mark - UITableViewControllerDelegate/Datasource methods
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    AccountInfo *account = [[AccountManager sharedManager] accountInfoForUUID:self.accountInfo.uuid];
    FDCertificate *certificateWrapper = [account certificateWrapper];
    
    // We can only edit (swipe to delete) the first section of the TV
    // in the case a certificate is linked to the account
    return certificateWrapper && indexPath.section == 0;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self deleteCertificateAction:self];
}

#pragma mark - ImportCertificateDelegate methods
- (void)importCertificateFinished
{
    [self.navigationController popToViewController:self animated:YES];
    [self updateAndReload];
    // Notificate the success in the case the account is not new
    [[AccountManager sharedManager] saveAccountInfo:self.accountInfo withNotification:!self.isNew];
    displayInformationMessage(NSLocalizedString(@"certificate-details.importSuccess", @"Success message for a certificate import"));
}

- (void)importCertificateCancelled
{
    [self.navigationController popToViewController:self animated:YES];
}

#pragma mark - UIAlertViewDelegate methods
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != alertView.cancelButtonIndex)
    {
        [[CertificateManager sharedManager] deleteCertificateForAccountUUID:self.accountInfo.uuid];
        // If the account is not new we should notify the controllers so they are able to update its views
        // If the account is new we should avoid notifications because it will cause a temporal accountInfo to be shown in the Manage Accounts section
        [[AccountManager sharedManager] saveAccountInfo:self.accountInfo withNotification:!self.isNew];
        [self updateAndReload];
    }
}

@end
