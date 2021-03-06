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
//  AddCommentViewController.m
//

#import "AddCommentViewController.h"
#import "Utility.h"
#import "FileDownloadManager.h"
#import "AccountManager.h"
#import "MBProgressHUD.h"

@interface AddCommentViewController(private)
- (void) startHUD;
- (void) stopHUD;
@end

@implementation AddCommentViewController
@synthesize textArea;
@synthesize commentText;
@synthesize placeholder;
@synthesize delegate;
@synthesize nodeRef;
@synthesize commentsRequest;
@synthesize downloadMetadata;
@synthesize selectedAccountUUID;
@synthesize HUD;
@synthesize tenantID;

#pragma mark -
#pragma mark Memory Management
- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:nil];
    [commentsRequest clearDelegatesAndCancel];
	
	[textArea release];
    [commentText release];
	[placeholder release];
    [nodeRef release];
    [commentsRequest release];
    [downloadMetadata release];
    [selectedAccountUUID release];
    [HUD release];
    [tenantID release];
	
    [super dealloc];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

#pragma mark Initialization
- (id)initWithNodeRef:(NodeRef *)aNodeRef
{
    self = [super init];
    if (self) {
        [self setNodeRef:aNodeRef];
    }
    return self;
}

- (id)initWithDownloadMetadata:(DownloadMetadata *)metadata
{
    self = [super init];
    if (self) {
        [self setDownloadMetadata:metadata];
    }
    return self;
}


#pragma mark -
#pragma mark View Life Cycle

- (void)viewDidUnload {
    [super viewDidUnload];
	
	self.textArea = nil;
    self.placeholder = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)loadView
{
	UIView *theView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	[theView setAutoresizesSubviews:YES];
	[theView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight)];
	[self setView:theView];
	[theView release];
}

- (void)viewDidLoad {
	CGRect textViewRect = self.view.frame;
	TextViewWithPlaceholder *textView = [[TextViewWithPlaceholder alloc] initWithFrame:textViewRect];
	[textView setAutoresizesSubviews:YES];
	[textView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight)];
	[textView setUserInteractionEnabled:YES];
	[textView setEditable:YES];
	[textView setDelegate:self];
	[textView setEnablesReturnKeyAutomatically:YES];
	[textView setAutocapitalizationType:UITextAutocapitalizationTypeSentences];
	[textView setAutocorrectionType:UITextAutocorrectionTypeDefault];
	[textView setKeyboardType:UIKeyboardTypeDefault];
	[textView setReturnKeyType:UIReturnKeyDefault];
	[textView setPlaceholder:placeholder];
	[self setTextArea:textView];
	[[self view] addSubview:textView];
	[textView release];
    
    if (self.commentText) {
        [self.textArea setText:self.commentText];
    }
		
	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                    target:self action:@selector(cancelButtonPressed)];
	[[self navigationItem] setLeftBarButtonItem:cancelButton];
	[cancelButton release];
	    
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
																  target:self  action:@selector(saveCommentButtonPressed)];
    styleButtonAsDefaultAction(saveButton);
    [saveButton setEnabled:NO];

	[[self navigationItem] setRightBarButtonItem:saveButton];
	[saveButton release];
	
	[self registerForKeyboardNotifications];
	
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[textArea becomeFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

#pragma mark -
#pragma mark Keyboard Event Handling
- (void)registerForKeyboardNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)keyboardWillShow:(NSNotification *)notification
{
	NSDictionary *userInfo = [notification userInfo];
	
	CGRect keyboardFrame;
	CGRect kbEndFrame;
	[[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&kbEndFrame];
	keyboardFrame = [self.view convertRect:kbEndFrame toView:nil];
	
    CGRect newFrame = [self.view frame];
	newFrame.size.height -= keyboardFrame.size.height;
	
    // Get the duration of the animation.
    NSValue *animationDurationValue = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval animationDuration;
    [animationDurationValue getValue:&animationDuration];
    
    // Animate the resize of the text view's frame in sync with the keyboard's appearance.
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:animationDuration];
	
	[self.textArea setFrame:newFrame];
    
    [UIView commitAnimations];
}

- (void)keyboardWillHide:(NSNotification *)notification
{	
    NSDictionary* userInfo = [notification userInfo];
    
    NSValue *animationDurationValue = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval animationDuration;
    [animationDurationValue getValue:&animationDuration];
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:animationDuration];
    
    [self.textArea setFrame:[self.view frame]];
    
    [UIView commitAnimations];
}

#pragma mark Action Selectors
- (void)cancelButtonPressed
{
    AlfrescoLogDebug(@"Comment Cancel Button Pressed");
    if (delegate && [delegate respondsToSelector:@selector(didCancelComment:)])
        [delegate didCancelComment];
	[self.navigationController popViewControllerAnimated:YES];
}

- (void)saveCommentButtonPressed
{
    AlfrescoLogDebug(@"Save button pressed");
    
    // Disable the Save button to prevent multiple save button clicks.
    [[[self navigationItem] rightBarButtonItem] setEnabled:NO];
    [[[self navigationItem] leftBarButtonItem] setEnabled:NO];
    [textArea resignFirstResponder];
    
    NSString *userInput = [textArea text];
    [self startHUD];
    
    if(self.nodeRef) {
        //Remote comments
        self.commentsRequest = [CommentsHttpRequest CommentsHttpPostRequestForNodeRef:self.nodeRef comment:userInput accountUUID:selectedAccountUUID tenantID:self.tenantID];
        [self.commentsRequest setDelegate:self];
        [self.commentsRequest startAsynchronous];
    } else if(self.downloadMetadata) {
        //Local comments
        NSMutableArray *localComments = [NSMutableArray arrayWithArray:downloadMetadata.localComments];
        NSMutableDictionary *newLocalComment = [NSMutableDictionary dictionary];
        [newLocalComment setObject:userInput forKey:@"content"];
        
        NSDateFormatter *destinationFormatter = [[NSDateFormatter alloc] init];
        [destinationFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
        [destinationFormatter setDateFormat:@"MMM dd yyyy HH:mm:ss ZZZZ"];
        NSString *formattedDate = [destinationFormatter stringFromDate:[NSDate date]];
        AccountInfo *accountInfo = [[AccountManager sharedManager] accountInfoForUUID:selectedAccountUUID];
        
        [destinationFormatter release];
        [newLocalComment setObject:formattedDate forKey:@"modifiedOn"];
        [newLocalComment setObject:[accountInfo username] forKey:@"author.firstName"];
        [newLocalComment setObject:[NSString stringWithFormat:@"%d", [localComments count]] forKey:@"id"];
        
        [localComments addObject:newLocalComment];
        downloadMetadata.localComments = localComments;
        NSString *insetedKey = [[FileDownloadManager sharedInstance] setDownload:downloadMetadata.downloadInfo forKey:downloadMetadata.key];
        if(insetedKey) {
            [self saveAndExit];
        } else {
            [self requestFailed:nil];
        }
        
        [self stopHUD];
    }
}

- (void)saveAndExit
{
	NSString *userInput = ([textArea hasText] ? [textArea text] : nil);
    if (delegate && [delegate respondsToSelector:@selector(didSubmitComment:)])
        [delegate didSubmitComment:userInput];
	[self.navigationController popViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark ASIHttpRequestDelegate
-(void)requestFailed:(CommentsHttpRequest *)request
{
    AlfrescoLogDebug(@"failed to post comment request failed");
    if ( [NSThread isMainThread] )
    {
        displayErrorMessageWithTitle(NSLocalizedString(@"add.comment.failure.message", @"Failed to add new comment, please try again"), NSLocalizedString(@"add.comment.failure.title", @""));

        // Request failed and we weren't popped out of the view, reenable for test
        [[[self navigationItem] rightBarButtonItem] setEnabled:YES];
        [[[self navigationItem] leftBarButtonItem] setEnabled:YES];
        [self stopHUD];
    }
    else
    {
        [self performSelectorOnMainThread:@selector(requestFailed:) withObject:request waitUntilDone:NO];
    }
}

- (void)requestFinished:(CommentsHttpRequest *)request
{
    AlfrescoLogDebug(@"comment post request finished");
    [self performSelectorOnMainThread:@selector(saveAndExit) withObject:nil waitUntilDone:NO];
    [self stopHUD];
}

- (void)cancelActiveConnection:(NSNotification *) notification {
    AlfrescoLogDebug(@"applicationWillResignActive in AddCommentViewController");
    [commentsRequest clearDelegatesAndCancel];
    
    [[[self navigationItem] rightBarButtonItem] setEnabled:YES];
    [[[self navigationItem] leftBarButtonItem] setEnabled:YES];
    [self stopHUD];
}


#pragma mark -
- (void)textViewDidChange:(UITextView *)textView
{
    [[[self navigationItem] rightBarButtonItem] setEnabled:([[textView text] length] > 0)];
}

#pragma mark - MBProgressHUD Helper Methods
- (void)startHUD
{
	if (!self.HUD)
    {
        self.HUD = createAndShowProgressHUDForView(self.navigationController.view);
	}
}

- (void)stopHUD
{
	if (self.HUD)
    {
        stopProgressHUD(self.HUD);
		self.HUD = nil;
	}
}

@end
