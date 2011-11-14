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
//  RepositoryNodeViewController.m
//

#import "CMISTypeDefinitionDownload.h"
#import "RepositoryNodeViewController.h"
#import "DocumentViewController.h"
#import "RepositoryItemTableViewCell.h"
#import "Utility.h"
#import "RepositoryItem.h"
#import "FolderItemsDownload.h"
#import "NSData+Base64.h"
#import "UIImageUtils.h"
#import "Theme.h"
#import "AppProperties.h"
#import "RepositoryServices.h"
#import "LinkRelationService.h"
#import "MetaDataTableViewController.h"
#import "IFTemporaryModel.h"
#import "SavedDocument.h"
#import "IpadSupport.h"
#import "ThemeProperties.h"
#import "TransparentToolbar.h"
#import "DownloadInfo.h"
#import "FileDownloadManager.h"
#import "FolderDescendantsRequest.h"

NSInteger const kDownloadFolderAlert = 1;

@interface RepositoryNodeViewController (PrivateMethods)
- (void) loadRightBar;
- (void) cancelAllHTTPConnections;
- (void) presentModalViewControllerHelper:(UIViewController *)modalViewController;
- (void) startHUD;
- (void) stopHUD;
- (void) downloadAllDocuments;
- (void) downloadAllCheckOverwrite:(NSArray *)allItems;
- (void) prepareDownloadAllDocuments;
- (void) continueDownloadFromAlert: (UIAlertView *) alert clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void) overwritePrompt: (NSString *) filename;
- (void) noFilesToDownloadPrompt;
- (void) fireNotificationAlert: (NSString *) message;
- (void) loadAudioUploadForm;
@end

@implementation RepositoryNodeViewController

@synthesize guid;
@synthesize folderItems;
@synthesize metadataDownloader;
@synthesize downloadProgressBar;
@synthesize downloadQueueProgressBar;
@synthesize postProgressBar;
@synthesize itemDownloader;
@synthesize folderDescendantsRequest;
@synthesize contentStream;
@synthesize popover;
@synthesize alertField;
@synthesize HUD;

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
	[guid release];
	[folderItems release];
    [metadataDownloader release];
	[downloadProgressBar release];
    [downloadQueueProgressBar release];
	[itemDownloader release];
    [folderDescendantsRequest release];
	[contentStream release];
	[popover release];
	[alertField release];
    [selectedIndex release];
    [willSelectIndex release];
    [HUD release];
    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
    
    if(IS_IPAD) {
        [self.tableView selectRowAtIndexPath:selectedIndex animated:NO scrollPosition:UITableViewScrollPositionNone];
    }

    [willSelectIndex release];
    willSelectIndex = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
	replaceData = NO;
    [self loadRightBar];

	[Theme setThemeForUITableViewController:self];
    [self.tableView setRowHeight:60.0f];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
}

- (void) viewDidUnload {
    [super viewDidUnload];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"detailViewControllerChanged" object:nil];
    
    self.tableView = nil;
    self.contentStream = nil;
    [self.popover dismissPopoverAnimated:NO];
    self.popover = nil;
    self.alertField = nil;
    [self stopHUD];
    
    [self cancelAllHTTPConnections];
}

- (void)cancelAllHTTPConnections
{
	[self.itemDownloader cancel];
	[self.folderItems cancel];
    [self.downloadProgressBar cancel];
    [self.folderDescendantsRequest clearDelegatesAndCancel];
    [self stopHUD];
}

- (void) loadRightBar {
    UIBarButtonItem *reloadButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh 
                                                                                   target:self action:@selector(refreshViewData)] autorelease];
    [reloadButton setStyle:UIBarButtonItemStyleBordered];
    
    BOOL showAddButton = [[AppProperties propertyForKey:kBShowAddButton] boolValue];
    BOOL showDownloadFolderButton = [[AppProperties propertyForKey:kBShowDownloadFolderButton] boolValue];
    BOOL showSecondButton = ((showAddButton && nil != [folderItems item] && ([folderItems item].canCreateFolder || [folderItems item].canCreateDocument)) || showDownloadFolderButton);
    
    //We only show the second button if any option is going to be displayed
    if(showSecondButton) {
        // There is no "official" way to know the width of the UIBarButtonItem
        // This is the closest value we got. If we use a bigger width in the 
        // toolbar we take space from the NavigationController title
        CGFloat width = 35;
        
        TransparentToolbar *rightBarToolbar = [[TransparentToolbar alloc] initWithFrame:CGRectMake(0, 0, width*2+10, 44.01)];
        UIBarButtonItem *flexibleSpace = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease];
        
        NSMutableArray *rightBarButtons = [NSMutableArray arrayWithObjects: flexibleSpace,reloadButton, nil];
        
        //Select the appropiate button item
        UIBarButtonItem *actionButton = nil;
        if(showDownloadFolderButton) {
            actionButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(performAction:)] autorelease];
        } else {
            actionButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(performAction:)] autorelease];
        }
        
        actionButton.style = UIBarButtonItemStyleBordered;
        [rightBarButtons addObject:actionButton];
        rightBarToolbar.tintColor = [ThemeProperties toolbarColor];
        rightBarToolbar.items = rightBarButtons;
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:rightBarToolbar] autorelease];
        [rightBarToolbar release];
    }
    else {
        [[self navigationItem] setRightBarButtonItem:reloadButton];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void)performAction:(id)sender {
	if (IS_IPAD) {
		if(nil != popover && [popover isPopoverVisible]) {
			[popover dismissPopoverAnimated:YES];
            [self setPopover:nil];
		}
	} 
    
	UIActionSheet *sheet = [[UIActionSheet alloc]
							initWithTitle:@""
							delegate:self 
							cancelButtonTitle:nil
							destructiveButtonTitle:nil 
							otherButtonTitles: nil];
	BOOL showAddButton = [[AppProperties propertyForKey:kBShowAddButton] boolValue];

	if (showAddButton && folderItems.item.canCreateDocument) {
        NSArray *sourceTypes = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera];
		BOOL hasCamera = [sourceTypes containsObject:(NSString *) kUTTypeImage];
        BOOL canCaptureVideo = [sourceTypes containsObject:(NSString *) kUTTypeMovie];
        
		if (hasCamera) {
			[sheet addButtonWithTitle:NSLocalizedString(@"add.actionsheet.take-photo", @"Take Photo")];
		}
        
        if(canCaptureVideo) {
            [sheet addButtonWithTitle:NSLocalizedString(@"add.actionsheet.capture-video", @"Capture Video")];
        }
        [sheet addButtonWithTitle:@"Record Audio"];
		[sheet addButtonWithTitle:NSLocalizedString(@"add.actionsheet.choose-photo", @"Choose Photo from Library")];
        [sheet addButtonWithTitle:NSLocalizedString(@"add.actionsheet.upload-document", @"Upload Document from Saved Docs")];
	}
    
    if (showAddButton && folderItems.item.canCreateFolder) {
		[sheet addButtonWithTitle:NSLocalizedString(@"add.actionsheet.create-folder", @"Create Folder")];
	}
	
    BOOL showDownloadFolderButton = [[AppProperties propertyForKey:kBShowDownloadFolderButton] boolValue];
    if(showDownloadFolderButton) {
        [sheet addButtonWithTitle:NSLocalizedString(@"add.actionsheet.download-folder", @"Download all documents")];
    }
    
	[sheet setCancelButtonIndex:[sheet addButtonWithTitle:NSLocalizedString(@"add.actionsheet.cancel", @"Cancel")]];
    
    if(IS_IPAD) {
        [sheet setActionSheetStyle:UIActionSheetStyleDefault];
        [sheet showFromBarButtonItem:sender  animated:YES];
    } else {
        [sheet showInView:[[self tabBarController] view]];
    }
	
	[sheet release];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	NSString *buttonLabel = [actionSheet buttonTitleAtIndex:buttonIndex];
    [actionSheet dismissWithClickedButtonIndex:0 animated:YES];
    
	if (![buttonLabel isEqualToString:NSLocalizedString(@"add.actionsheet.cancel", @"Cancel")]) {
        
        // TODO
        // Re-implement using a switch and button indices.  
        //
        
        if ([buttonLabel isEqualToString:@"Upload a Photo"]) {
            UploadFormTableViewController *formController = [[UploadFormTableViewController alloc] init];
            [formController setExistingDocumentNameArray:[folderItems valueForKeyPath:@"children.title"]];
            [formController setUpLinkRelation:[[self.folderItems item] identLink]];
            [formController setUpdateAction:@selector(metaDataChanged)];
            [formController setUpdateTarget:self];
            
           
            [formController setModalPresentationStyle:UIModalPresentationFormSheet];
            formController.delegate = self;
            // We want to present the UploadFormTableViewController modally in ipad
            // and in iphone we want to push it into the current navigation controller
            // IpadSupport helper method provides this logic
            [IpadSupport presentModalViewController:formController withParent:self andNavigation:self.navigationController];
            
            [formController release];
        }
		else if ([buttonLabel isEqualToString:NSLocalizedString(@"add.actionsheet.choose-photo", @"Choose Photo from Library")]) {
			UIImagePickerController *picker = [[UIImagePickerController alloc] init];
			[picker setModalTransitionStyle:UIModalTransitionStyleFlipHorizontal];
			[picker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
			[picker setDelegate:self];
			
			[self presentModalViewControllerHelper:picker];
            
			[picker release];
            
		}
        else if ([buttonLabel isEqualToString:NSLocalizedString(@"add.actionsheet.take-photo", @"Take Photo")]) {
			UIImagePickerController *picker = [[UIImagePickerController alloc] init];
			[picker setModalTransitionStyle:UIModalTransitionStyleFlipHorizontal];
			[picker setSourceType:UIImagePickerControllerSourceTypeCamera];
            [picker setMediaTypes:[NSArray arrayWithObject:(NSString *)kUTTypeImage]];
			[picker setDelegate:self];
			
			[self presentModalViewControllerHelper:picker];
			
			[picker release];
            
		}
        else if ([buttonLabel isEqualToString:NSLocalizedString(@"add.actionsheet.capture-video", @"Capture Video")]) {
			UIImagePickerController *picker = [[UIImagePickerController alloc] init];
			[picker setModalTransitionStyle:UIModalTransitionStyleFlipHorizontal];
			[picker setSourceType:UIImagePickerControllerSourceTypeCamera];
            [picker setMediaTypes:[NSArray arrayWithObject:(NSString *)kUTTypeMovie]];
			[picker setDelegate:self];
			
			[self presentModalViewControllerHelper:picker];
			
			[picker release];
            
		} 
        else if ([buttonLabel isEqualToString:NSLocalizedString(@"add.actionsheet.create-folder", @"Create Folder")]) {
			UIAlertView *alert = [[UIAlertView alloc] 
								  initWithTitle:NSLocalizedString(@"add.create-folder.prompt.title", @"Name: ")
								  message:@" \r\n "
								  delegate:self 
								  cancelButtonTitle:NSLocalizedString(@"closeButtonText", @"Cancel Button Text")
								  otherButtonTitles:NSLocalizedString(@"okayButtonText", @"OK Button Text"), nil];
            
			self.alertField = [[[UITextField alloc] initWithFrame:CGRectMake(12.0, 45.0, 260.0, 25.0)] autorelease];
			[alertField setBackgroundColor:[UIColor whiteColor]];
			[alert addSubview:alertField];
			[alert show];
			[alert release];
		} else if([buttonLabel isEqualToString:NSLocalizedString(@"add.actionsheet.upload-document", @"Upload Document from Saved Docs")]) {
            
            SavedDocumentPickerController *picker = [[SavedDocumentPickerController alloc] init];
			[picker setModalTransitionStyle:UIModalTransitionStyleFlipHorizontal];
			[picker setDelegate:self];
            
            [self presentModalViewControllerHelper:picker];
            [picker release];
        } else if([buttonLabel isEqualToString:@"Record Audio"]) {
            [self loadAudioUploadForm];
        }else if([buttonLabel isEqualToString:NSLocalizedString(@"add.actionsheet.download-folder", @"Download all documents")]) {
            [self prepareDownloadAllDocuments];
        }
	}
}

- (void) presentModalViewControllerHelper:(UIViewController *)modalViewController {
    if (IS_IPAD) {
        UIPopoverController *popoverController = [[UIPopoverController alloc] initWithContentViewController:modalViewController];
        [self setPopover:popoverController];
        [popoverController release];
        
        [popover presentPopoverFromBarButtonItem:self.navigationItem.rightBarButtonItem 
                        permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
    } else  {
        [[self navigationController] presentModalViewController:modalViewController animated:YES];
    }
}

#pragma mark - Download all items in folder methods

- (void)prepareDownloadAllDocuments 
{    
    BOOL downloadFolderTree = [[AppProperties propertyForKey:kBDownloadFolderTree] boolValue];
    if(downloadFolderTree) {
        [self startHUD];
        
        FolderDescendantsRequest *down = [FolderDescendantsRequest folderDescendantsRequestWithItem:[folderItems item]];
        [self setFolderDescendantsRequest:down];
        [down setDelegate:self];
        [down startAsynchronous];
    } else {
        [self downloadAllCheckOverwrite:[folderItems children]];
    }
}

- (void)requestFinished:(ASIHTTPRequest *)request {
    if([request isKindOfClass:[FolderDescendantsRequest class]]) {
        FolderDescendantsRequest *fdr = (FolderDescendantsRequest *)request;
        [self downloadAllCheckOverwrite:[fdr folderDescendants]];
    }
    
    [self stopHUD];
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    [self stopHUD];
}

- (void) downloadAllCheckOverwrite:(NSArray *)allItems {
    RepositoryItem *child;
    [childsToDownload release];
    childsToDownload = [[NSMutableArray array] retain];
    [childsToOverwrite release];
    childsToOverwrite = [[NSMutableArray array] retain];
    
    for(child in allItems) {
        if(![child isFolder]) {
            if([[NSFileManager defaultManager] fileExistsAtPath:[SavedDocument pathToSavedFile:child.title]]) {
                [childsToOverwrite addObject:child];
            } else {
                [childsToDownload addObject:child];
            }
        }
    }
    
    [self downloadAllDocuments];
}

- (void) overwritePrompt: (NSString *) filename { 
    UIAlertView *overwritePrompt = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"documentview.overwrite.download.prompt.title", @"")
                                message:[NSString stringWithFormat:NSLocalizedString(@"documentview.overwrite.filename.prompt.message", @"Yes/No Question"), filename]
                               delegate:self 
                      cancelButtonTitle:NSLocalizedString(@"No", @"No Button Text") 
                      otherButtonTitles:NSLocalizedString(@"Yes", @"Yes BUtton Text"), nil] autorelease];
    [overwritePrompt setTag:kDownloadFolderAlert];
    [overwritePrompt show];
}

- (void) noFilesToDownloadPrompt {
    UIAlertView *noFilesToDownloadPrompt = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"documentview.overwrite.download.prompt.title", @"")
                                                               message:NSLocalizedString(@"documentview.download.noFilesToDownload", @"There are no files to download")
                                                              delegate:nil 
                                                             cancelButtonTitle:NSLocalizedString(@"okayButtonText", @"OK")
                                                     otherButtonTitles:nil] autorelease];
    [noFilesToDownloadPrompt show];
}

- (void) downloadAllDocuments {
    if([childsToOverwrite count] > 0) {
        RepositoryItem *lastChild = [childsToOverwrite lastObject];
        [self overwritePrompt:lastChild.title];
        return;
    }
    
    if([childsToDownload count] <= 0) {
        [self noFilesToDownloadPrompt];
    } else {
        NSLog(@"Begin downloading %d files", [childsToDownload count]);
        //download all childs
        self.downloadQueueProgressBar = [DownloadQueueProgressBar createWithNodes:childsToDownload delegate:self andMessage:NSLocalizedString(@"Downloading Document", @"Downloading Document")];
        [self.downloadQueueProgressBar startDownloads];
    }
}

- (void) continueDownloadFromAlert: (UIAlertView *) alert clickedButtonAtIndex:(NSInteger)buttonIndex {
    RepositoryItem *lastChild = [childsToOverwrite lastObject];
    [childsToOverwrite removeObject:lastChild];
    
    if (buttonIndex != alert.cancelButtonIndex) {
        [childsToDownload addObject:lastChild];
    }
    
    [self downloadAllDocuments];
}

#pragma mark AudioRecorderDialogDelegate methods
- (void) loadAudioUploadForm {
    UploadFormTableViewController *formController = [[UploadFormTableViewController alloc] init];
    [formController setExistingDocumentNameArray:[folderItems valueForKeyPath:@"children.title"]];
    [formController setUpLinkRelation:[[self.folderItems item] identLink]];
    [formController setUpdateAction:@selector(metaDataChanged)];
    [formController setUpdateTarget:self];
    
    IFTemporaryModel *formModel = [[IFTemporaryModel alloc] init];
    [formController setUploadType:UploadFormTypeAudio];
    [formController setModel:formModel];
    [formModel release];
    
    [formController setModalPresentationStyle:UIModalPresentationFormSheet];
    formController.delegate = self;
    // We want to present the UploadFormTableViewController modally in ipad
    // and in iphone we want to push it into the current navigation controller
    // IpadSupport helper method provides this logic
    [IpadSupport presentModalViewController:formController withParent:self andNavigation:self.navigationController];
    
    [formController release];
}

#pragma mark DownloadQueueDelegate

- (void) downloadQueue:(DownloadQueueProgressBar *)down completeDownloads:(NSArray *)downloads {
    //NSLog(@"Download Queue completed!");
    DownloadInfo *download;
    NSInteger successCount = 0;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    for(download in downloads) {
        if([download isCompleted] && [fileManager fileExistsAtPath:download.tempFilePath]) {
            successCount++;
            DownloadMetadata *metadata = download.downloadMetadata;
            [[FileDownloadManager sharedInstance] setDownload:metadata.downloadInfo forKey:metadata.key withFilePath:[download.tempFilePath lastPathComponent]];
        }
    }
    
    NSString *message = nil;
    
    if(successCount == [childsToDownload count]) {
        message = NSLocalizedString(@"browse.downloadFolder.success", @"All documents had been saved to your device");
    } else if(successCount != 0) {
        NSString *plural = successCount == 1 ? @"" : @"s";
        NSString *format = NSLocalizedString(@"browse.downloadFolder.partialSuccess", @"All but x documents had been saved to your device");
        NSInteger documentsMissed = [childsToDownload count] - successCount;
        message = [NSString stringWithFormat:format, documentsMissed, plural];
    } else {
        message = NSLocalizedString(@"browse.downloadFolder.failed", @"Could not download any document to your device");
    }
    
    [self fireNotificationAlert:message];
    self.downloadQueueProgressBar = nil;
    NSLog(@"%d downloads successful", successCount);
}

- (void) downloadQueueWasCancelled:(DownloadQueueProgressBar *)down {
    [self fireNotificationAlert:@"browse.downloadFolder.failed"];
    self.downloadQueueProgressBar = nil;
}

- (void) fireNotificationAlert:(NSString *)message {
    UIAlertView *notificationAlert = [[[UIAlertView alloc] initWithTitle:@""
                                                                       message:message
                                                                      delegate:nil 
                                                             cancelButtonTitle:NSLocalizedString(@"okayButtonText", @"OK")
                                                             otherButtonTitles:nil] autorelease];
    [notificationAlert show];
}

#pragma mark UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info 
{
//	UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
//	image = [image imageByScalingToWidth:1024];
//	if (nil != image) {
//		self.contentStream = [NSData dataWithData:UIImagePNGRepresentation(image)];
//		UIAlertView *alert = [[UIAlertView alloc] 
//							  initWithTitle:@"Enter a Name:"
//							  message:@" "
//							  delegate:self 
//                              cancelButtonTitle:NSLocalizedString(@"closeButtonText", @"Cancel Button Text")
//                              otherButtonTitles:NSLocalizedString(@"okayButtonText", @"OK Button Text"), nil];
//  		
//		self.alertField = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 45.0, 260.0, 25.0)];
//		[alertField setBackgroundColor:[UIColor whiteColor]];
//			[alert addSubview:alertField];
//
//		[alert show];
//		[alert release];
//	}
    
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    NSString *mediaURL = [info objectForKey:UIImagePickerControllerMediaURL];
	image = [image imageByScalingToWidth:1024];
    
    [picker dismissModalViewControllerAnimated:YES];
    if (IS_IPAD) {
		if(nil != popover && [popover isPopoverVisible]) {
			[popover dismissPopoverAnimated:YES];
            [self setPopover:nil];
		}
	}
    
	if (nil != image || nil != mediaURL) 
    {    
        UploadFormTableViewController *formController = [[UploadFormTableViewController alloc] init];
        [formController setExistingDocumentNameArray:[folderItems valueForKeyPath:@"children.title"]];
        [formController setUpLinkRelation:[[self.folderItems item] identLink]];
        [formController setUpdateAction:@selector(metaDataChanged)];
        [formController setUpdateTarget:self];
        
        IFTemporaryModel *formModel = [[IFTemporaryModel alloc] init];
        
        if([mediaType isEqualToString:(NSString *) kUTTypeImage]) {
            [formModel setObject:image forKey:@"media"];
            [formController setUploadType:UploadFormTypePhoto];
        } else {
            [formModel setObject:mediaURL forKey:@"mediaURL"];
            [formController setUploadType:UploadFormTypeVideo];
        }
        [formModel setObject:image forKey:@"mediaType"];
        [formController setModel:formModel];
        [formModel release];
        
        [formController setModalPresentationStyle:UIModalPresentationFormSheet];
        formController.delegate = self;
        // We want to present the UploadFormTableViewController modally in ipad
        // and in iphone we want to push it into the current navigation controller
        // IpadSupport helper method provides this logic
        [IpadSupport presentModalViewController:formController withParent:self andNavigation:self.navigationController];
        
        [formController release];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker 
{
	[picker dismissModalViewControllerAnimated:YES];
    if (IS_IPAD) {
		if(nil != popover && [popover isPopoverVisible]) {
			[popover dismissPopoverAnimated:YES];
            [self setPopover:nil];
		}
	}
}

- (void)didPresentAlertView:(UIAlertView *)alertView {
	[alertField becomeFirstResponder];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if(alertView.tag == kDownloadFolderAlert) {
        [self continueDownloadFromAlert:alertView clickedButtonAtIndex:buttonIndex];
    }
    
    if (IS_IPAD) {
		if(nil != popover && [popover isPopoverVisible]) {
			[popover dismissPopoverAnimated:YES];
            [self setPopover:nil];
		}
	}
    
	NSString *userInput = [alertField text];
	NSString *strippedUserInput = [userInput stringByReplacingOccurrencesOfString:@" " withString:@""];
	self.alertField = nil;
	
	if (1 == buttonIndex && [strippedUserInput length] > 0) {
		if (nil != contentStream) {
			NSString *postBody  = [NSString stringWithFormat:@""
								   "<?xml version=\"1.0\" ?>"
								   "<entry xmlns=\"http://www.w3.org/2005/Atom\" xmlns:app=\"http://www.w3.org/2007/app\" xmlns:cmisra=\"http://docs.oasis-open.org/ns/cmis/restatom/200908/\">"
								   "<cmisra:content>"
								   "<cmisra:mediatype>image/png</cmisra:mediatype>"
								   "<cmisra:base64>%@</cmisra:base64>"
								   "</cmisra:content>"
								   "<cmisra:object xmlns:cmis=\"http://docs.oasis-open.org/ns/cmis/core/200908/\">"
								   "<cmis:properties>"
								   "<cmis:propertyId propertyDefinitionId=\"cmis:objectTypeId\">"
								   "<cmis:value>cmis:document</cmis:value>"
								   "</cmis:propertyId>"
								   "</cmis:properties>"
								   "</cmisra:object><title>%@.png</title></entry>",
								   [contentStream base64EncodedString],
								   userInput
								   ];
			NSLog(@"POSTING DATA: %@", postBody);
			self.contentStream = nil;
			
			RepositoryItem *item = [folderItems item];
			NSString *location   = [item identLink];
			NSLog(@"TO LOCATION: %@", location);
			
			self.postProgressBar = 
			[PostProgressBar createAndStartWithURL:[NSURL URLWithString:location]
									   andPostBody:postBody
										  delegate:self 
										   message:NSLocalizedString(@"postprogressbar.upload.picture", @"Uploading Picture")];
		} else {
			NSString *postBody = [NSString stringWithFormat:@""
								  "<?xml version=\"1.0\" ?>"
								  "<entry xmlns=\"http://www.w3.org/2005/Atom\" xmlns:app=\"http://www.w3.org/2007/app\" xmlns:cmisra=\"http://docs.oasis-open.org/ns/cmis/restatom/200908/\">"
								  "<title type=\"text\">%@</title>"
								  "<cmisra:object xmlns:cmis=\"http://docs.oasis-open.org/ns/cmis/core/200908/\">"
								  "<cmis:properties>"
								  "<cmis:propertyId  propertyDefinitionId=\"cmis:objectTypeId\">"
								  "<cmis:value>cmis:folder</cmis:value>"
								  "</cmis:propertyId>"
								  "</cmis:properties>"
								  "</cmisra:object>"
								  "</entry>", userInput];
			NSLog(@"POSTING DATA: %@", postBody);
			
			RepositoryItem *item = [folderItems item];
			NSString *location   = [item identLink];
			NSLog(@"TO LOCATION: %@", location);
			
			self.postProgressBar = 
				[PostProgressBar createAndStartWithURL:[NSURL URLWithString:location]
								 andPostBody:postBody
								 delegate:self 
								 message:NSLocalizedString(@"postprogressbar.create.folder", @"Creating Folder")];
		}
	}
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[folderItems children] count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
	RepositoryItemTableViewCell *cell = (RepositoryItemTableViewCell *) [tableView dequeueReusableCellWithIdentifier:RepositoryItemCellIdentifier];
    if (cell == nil) {
		NSArray *nibItems = [[NSBundle mainBundle] loadNibNamed:@"RepositoryItemTableViewCell" owner:self options:nil];
		cell = [nibItems objectAtIndex:0];
		NSAssert(nibItems, @"Failed to load object from NIB");
    }
    
	RepositoryItem *child = [[folderItems children] objectAtIndex:[indexPath row]];
    
    NSString *filename = [child.metadata valueForKey:@"cmis:name"];
    if (!filename || ([filename length] == 0)) filename = child.title;
	[cell.filename setText:filename];
    
	if ([child isFolder]) {
        
		UIImage * img = [UIImage imageNamed:@"folder.png"];
		cell.imageView.image  = img;
        cell.details.text = [[[NSString alloc] initWithFormat:@"%@", formatDocumentDate(child.lastModifiedDate)] autorelease]; // TODO: Externalize to a configurable property?        
	}
	else {
//        NSString *contentStreamLengthStr = [child.metadata objectForKey:@"cmis:contentStreamLength"];
        NSString *contentStreamLengthStr = [child contentStreamLengthString];
        cell.details.text = [[[NSString alloc] initWithFormat:@"%@ | %@", formatDocumentDate(child.lastModifiedDate), 
                             [SavedDocument stringForLongFileSize:[contentStreamLengthStr longLongValue]]] autorelease]; // TODO: Externalize to a configurable property?
		cell.imageView.image = imageForFilename(child.title);
	}
    
    BOOL showMetadataDisclosure = [[AppProperties propertyForKey:kBShowMetadataDisclosure] 
                                   boolValue];
    
    if(showMetadataDisclosure && ![[[RepositoryServices shared] currentRepositoryInfo] isPreReleaseCmis]) {
        [cell setAccessoryView:[self makeDetailDisclosureButton]];
    } else {
        [cell setAccessoryType:UITableViewCellAccessoryNone];
    }
    
    return cell;
}

- (UIButton *)makeDetailDisclosureButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeInfoDark];
    [button addTarget:self action:@selector(accessoryButtonTapped:withEvent:) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void) accessoryButtonTapped: (UIControl *) button withEvent: (UIEvent *) event
{
    NSIndexPath * indexPath = [self.tableView indexPathForRowAtPoint:[[[event touchesForView:button] anyObject] locationInView:self.tableView]];
    if ( indexPath == nil )
        return;
    
    [self.tableView.delegate tableView:self.tableView accessoryButtonTappedForRowWithIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

	RepositoryItem *child = [[folderItems children] objectAtIndex:[indexPath row]];
	
	if ([child isFolder]) {
        [self startHUD];
		[self.itemDownloader cancel];
		
		NSDictionary *optionalArguments = [[LinkRelationService shared] 
										   optionalArgumentsForFolderChildrenCollectionWithMaxItems:nil skipCount:nil filter:nil 
										   includeAllowableActions:YES includeRelationships:NO renditionFilter:nil orderBy:nil includePathSegment:NO];
		NSURL *getChildrenURL = [[LinkRelationService shared] getChildrenURLForCMISFolder:child 
																   withOptionalArguments:optionalArguments];
		FolderItemsDownload *down = [[FolderItemsDownload alloc] initWithURL:getChildrenURL delegate:self];
		[self setItemDownloader:down];
		down.item = child;
		down.parentTitle = child.title;
        down.showHUD = NO;
		[down start];
		[down release];
	}
	else {
		if (child.contentLocation) {
			NSString *urlStr  = child.contentLocation;
			NSURL *contentURL = [NSURL URLWithString:urlStr];
			[self setDownloadProgressBar:[DownloadProgressBar createAndStartWithURL:contentURL delegate:self 
                message:NSLocalizedString(@"Downloading Documents", @"Downloading Documents")
                filename:child.title contentLength:[child contentStreamLength]]];
            [[self downloadProgressBar] setCmisObjectId:[child guid]];
            [[self downloadProgressBar] setCmisContentStreamMimeType:[[child metadata] objectForKey:@"cmis:contentStreamMimeType"]];
            [[self downloadProgressBar] setVersionSeriesId:[child versionSeriesId]];
            [[self downloadProgressBar] setRepositoryItem:child];
		}
		else {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"noContentWarningTitle", @"No content")
                                                            message:NSLocalizedString(@"noContentWarningMessage", @"This document has no content.") 
                                                           delegate:nil 
                                                  cancelButtonTitle:NSLocalizedString(@"okayButtonText", @"OK Button Text")
                                                  otherButtonTitles:nil];
			[alert show];
            [alert release];
		}
	}
    
    [willSelectIndex release];
    willSelectIndex = [indexPath retain];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self startHUD];
	RepositoryItem *child = [[folderItems children] objectAtIndex:[indexPath row]];
	
	CMISTypeDefinitionDownload *down = [[CMISTypeDefinitionDownload alloc] initWithURL:[NSURL URLWithString:child.describedByURL] delegate:self];
	down.repositoryItem = child;
    down.showHUD = NO;
	[down start];
	self.metadataDownloader = down;
    [down release];
}


- (void) asyncDownloadDidComplete:(AsynchonousDownload *)async {
	
	if ([async isKindOfClass:[FolderItemsDownload class]] && [async isEqual:itemDownloader]) {
		// if we're reloading then just tell the view to update
		if (replaceData) {
			replaceData = NO;
			[((UITableView *)[self view]) reloadData];
			[[self tableView] reloadData];
		}
		// otherwise we're loading a child which needs to
		// be created and pushed onto the nav stack
		else {
			FolderItemsDownload *fid = (FolderItemsDownload *) async;

			// create a new view controller for the list of repository items (documents and folders)
			RepositoryNodeViewController *vc = [[RepositoryNodeViewController alloc] initWithNibName:nil bundle:nil];

			vc.folderItems = fid;
			vc.title = fid.parentTitle;

			// push that view onto the nav controller's stack
			[self.navigationController pushViewController:vc animated:YES];
			[vc release];
		}
	} 
	else if ([async isKindOfClass:[CMISTypeDefinitionDownload class]]) {
		CMISTypeDefinitionDownload *tdd = (CMISTypeDefinitionDownload *) async;
        MetaDataTableViewController *viewController = [[MetaDataTableViewController alloc] initWithStyle:UITableViewStylePlain 
                                                                                              cmisObject:[tdd repositoryItem]];
        [viewController setCmisObjectId:tdd.repositoryItem.guid];
        [viewController setMetadata:tdd.repositoryItem.metadata];
        [viewController setPropertyInfo:tdd.properties];
        
        [IpadSupport pushDetailController:viewController withNavigation:self.navigationController andSender:self];
        
        [viewController release];
	}
    
    [self stopHUD];
}

#pragma mark -
#pragma mark Instance Methods
-(void)refreshViewData {
    shouldForceReload = YES;
    [self metaDataChanged];
}

- (void)metaDataChanged
{
    // A request is active we should not try to reload
    if(hudCount > 0) {
        return;
    }
    
    [self startHUD];
	replaceData = YES;
	RepositoryItem *currentNode = [folderItems item];
	NSDictionary *optionalArguments = [[LinkRelationService shared] 
									   optionalArgumentsForFolderChildrenCollectionWithMaxItems:nil skipCount:nil filter:nil 
									   includeAllowableActions:YES includeRelationships:NO renditionFilter:nil orderBy:nil includePathSegment:NO];
	NSURL *getChildrenURL = [[LinkRelationService shared] getChildrenURLForCMISFolder:currentNode 
															   withOptionalArguments:optionalArguments];

	FolderItemsDownload *down = [[FolderItemsDownload alloc] initWithURL:getChildrenURL delegate:self];
    [self setItemDownloader:down];
	[down setItem:currentNode];
    down.showHUD = NO;
    if(shouldForceReload) {
        [down.httpRequest setCachePolicy:ASIAskServerIfModifiedCachePolicy];
    }
    
	[down start];
	[self setFolderItems:down];
	[down release];
}

- (void) asyncDownload:(AsynchonousDownload *)async didFailWithError:(NSError *)error {
	[self stopHUD];
}

- (void) download:(DownloadProgressBar *)down completeWithData:(NSData *)data {

	NSString *nibName = @"DocumentViewController";
	DocumentViewController *doc = [[DocumentViewController alloc] initWithNibName:nibName bundle:[NSBundle mainBundle]];
	[doc setCmisObjectId:down.cmisObjectId];
    [doc setFileData:data];
    [doc setContentMimeType:[down cmisContentStreamMimeType]];
    [doc setHidesBottomBarWhenPushed:YES];
    
    DownloadMetadata *fileMetadata = down.downloadMetadata;
    NSString *filename;
    
    if(fileMetadata.key) {
        filename = fileMetadata.key;
    } else {
        filename = down.filename;
    }
    
    [doc setFileName:filename];
    [doc setFileMetadata:fileMetadata];
	
	[IpadSupport pushDetailController:doc withNavigation:self.navigationController andSender:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(detailViewControllerChanged:) name:@"detailViewControllerChanged" object:nil];
    
	[doc release];
    
    [selectedIndex release];
    selectedIndex = willSelectIndex;
    willSelectIndex = nil;
}

- (void) downloadWasCancelled:(DownloadProgressBar *)down {
	[self.tableView deselectRowAtIndexPath:willSelectIndex animated:YES];
    
    // We don't want to reselect the previous row in iPhone
    if(IS_IPAD) {
        [self.tableView selectRowAtIndexPath:selectedIndex animated:YES scrollPosition:UITableViewScrollPositionNone];
    }
}

- (void) post:(PostProgressBar *)bar completeWithData:(NSData *)data {	
	// cause our folderItems object to update
	// we're going to handle this ourselves so
	// we need to know to update ourself rather 
	// than loading a new subview.
	replaceData = YES;
	[self.itemDownloader cancel];
	[folderItems setDelegate:self];
	self.itemDownloader = folderItems;
	[folderItems restart];	
}

#pragma mark - UploadFormDelegate
- (void)dismissUploadViewController:(UploadFormTableViewController *)recipeAddViewController didUploadFile:(BOOL)success {
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark - SavedDocumentPickerDelegate
- (void) savedDocumentPicker:(SavedDocumentPickerController *)picker didPickDocument:(NSString *)document {
    NSLog(@"%@", document);
    
    if (IS_IPAD) {
		if(nil != popover && [popover isPopoverVisible]) {
			[popover dismissPopoverAnimated:YES];
            [self setPopover:nil];
		}
	}
    
	if (nil != document) 
    {    
        UploadFormTableViewController *formController = [[UploadFormTableViewController alloc] init];
        [formController setExistingDocumentNameArray:[folderItems valueForKeyPath:@"children.title"]];
        [formController setUpLinkRelation:[[self.folderItems item] identLink]];
        [formController setUpdateAction:@selector(metaDataChanged)];
        [formController setUpdateTarget:self];
        IFTemporaryModel *formModel = [[IFTemporaryModel alloc] init];
        
        if(isVideoExtension([document pathExtension])) {
            [formController setUploadType:UploadFormTypeVideo];
            [formModel setObject:[NSURL URLWithString:document] forKey:@"mediaURL"];
        } else {
            [formController setUploadType:UploadFormTypeDocument];
            [formModel setObject:document forKey:@"filePath"];
        }
        
        
        
        
        NSString *unencodedURL = [[NSURL URLWithString:document] path];
        [formModel setObject:[[unencodedURL lastPathComponent] stringByDeletingPathExtension] forKey:@"name"];
        [formController setModel:formModel];
        [formModel release];
        
        [formController setModalPresentationStyle:UIModalPresentationFormSheet];
        formController.delegate = self;
        // We want to present the UploadFormTableViewController modally in ipad
        // and in iphone we want to push it into the current navigation controller
        // IpadSupport helper method provides this logic
        [IpadSupport presentModalViewController:formController withParent:self andNavigation:self.navigationController];
        
        [formController release];
    }
}

#pragma mark -
#pragma mark MBProgressHUD Helper Methods
- (void)startHUD
{
    hudCount++;
	if (HUD) {
		return;
	}
    
    [self setHUD:[MBProgressHUD showHUDAddedTo:self.tableView animated:YES]];
    [self.HUD setRemoveFromSuperViewOnHide:YES];
    [self.HUD setTaskInProgress:YES];
    [self.HUD setMode:MBProgressHUDModeIndeterminate];
}

- (void)stopHUD
{
    hudCount--;
    
	if (HUD && hudCount <= 0) {
		[HUD setTaskInProgress:NO];
		[HUD hide:YES];
		[HUD removeFromSuperview];
		[self setHUD:nil];
	}
}

#pragma mark - NotificationCenter methods
- (void) detailViewControllerChanged:(NSNotification *) notification {
    id sender = [notification object];
    
    if(sender && ![sender isEqual:self]) {
        [selectedIndex release];
        selectedIndex = nil;
        
        [self.tableView selectRowAtIndexPath:nil animated:YES scrollPosition:UITableViewScrollPositionNone];
    }
}

- (void) applicationWillResignActive:(NSNotification *) notification {
    NSLog(@"applicationWillResignActive in RepositoryNodeViewController");
    [popover dismissPopoverAnimated:NO];
    self.popover = nil;
    
    [self cancelAllHTTPConnections];
}
@end
