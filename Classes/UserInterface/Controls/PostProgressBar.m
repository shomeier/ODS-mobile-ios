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
//  PostProgressBar.m
//
// this code id based on: http://pessoal.org/blog/2009/02/09/iphone-sdk-formatting-a-numeric-value-with-nsnumberformatter/

#import "PostProgressBar.h"
#import "Utility.h"
#import "FileUtils.h"
#import "CMISMediaTypes.h"
#import "BaseHTTPRequest.h"
#import "FileUtils.h"
#import "Constants.h"
#import "CMISUtils.h"

#define kPostCounterTag 5

@interface PostProgressBar ()
- (void)handleGraceTimer;

@property (retain) NSTimer *graceTimer;
@end

@implementation PostProgressBar

@synthesize fileData;
@synthesize progressAlert;
@synthesize delegate;
@synthesize cmisObjectId;
@synthesize progressView;
@synthesize currentRequest;
@synthesize graceTimer;
@synthesize suppressErrors;

- (void) dealloc 
{
    [currentRequest clearDelegatesAndCancel];
    
	[fileData release];
	[progressAlert release];
    [cmisObjectId release];
    [progressView release];
    [currentRequest release];
    [graceTimer release];
    
	[super dealloc];
}

- (void)displayFailureMessage
{
    if (! [NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(displayFailureMessage) withObject:nil waitUntilDone:NO];
        return;
    }
    
    [[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"postprogressbar.error.uploadfailed.title", @"Upload Failed") 
                                 message:NSLocalizedString(@"postprogressbar.error.uploadfailed.message", @"The upload failed, please try again")
                                delegate:nil 
                       cancelButtonTitle:NSLocalizedString(@"okayButtonText", @"Okay") 
                       otherButtonTitles:nil, nil] autorelease] show];
}

+ (PostProgressBar *)createAndStartWithURL:(NSURL*)url andPostBody:(NSString *)body delegate:(id <PostProgressBarDelegate>)del message:(NSString *)msg accountUUID:(NSString *)uuid
{
    return [PostProgressBar createAndStartWithURL:url andPostBody:body delegate:del message:msg accountUUID:uuid requestMethod:@"POST" supressErrors:NO];
}
    
+ (PostProgressBar *)createAndStartWithURL:(NSURL*)url andPostBody:(NSString *)body delegate:(id <PostProgressBarDelegate>)del message:(NSString *)msg accountUUID:(NSString *)uuid requestMethod:(NSString *)requestMethod supressErrors:(BOOL)suppressErrors
{	
	PostProgressBar *bar = [[[PostProgressBar alloc] init] autorelease];
    bar.suppressErrors = suppressErrors;
	
	// create a modal alert
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:msg 
                                                    message:NSLocalizedString(@"Please wait...", @"Please wait...") 
                                                   delegate:bar 
                                          cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel button text")
                                          otherButtonTitles:nil];
    bar.progressAlert = alert;
    UIProgressView *progress = [[UIProgressView alloc] initWithFrame:CGRectMake(30.0f, 80.0f, 225.0f, 90.0f)];
    bar.progressView = progress;
    [progress setProgressViewStyle:UIProgressViewStyleBar];
	[progress release];
    [bar.progressAlert addSubview:bar.progressView];
    
    alert.message = [NSString stringWithFormat: @"%@%@", alert.message, @"\n\n\n\n"];
	[alert release];
		
	// create a label, and add that to the alert, too
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(90.0f, 90.0f, 225.0f, 20.0f)];
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:12.0f];
    label.text = [NSString stringWithFormat:@"%@ %@",
                  NSLocalizedString(@"Sending", @"Sending 1000 kb"),
                  [FileUtils stringForLongFileSize:[body length]]];
    label.tag = kPostCounterTag;
    [bar.progressAlert addSubview:label];
    [label release];

    // If the grace time is set postpone the dialog
    if (kNetworkProgressDialogGraceTime > 0.0)
    {
        bar.graceTimer = [NSTimer scheduledTimerWithTimeInterval:kNetworkProgressDialogGraceTime
                                                          target:bar
                                                        selector:@selector(handleGraceTimer)
                                                        userInfo:nil
                                                         repeats:NO];
    }
    // ... otherwise show the dialog immediately
    else
    {
        [bar.progressAlert show];
    }
    
	// who should we notify when the download is complete?
	bar.delegate = del;
    
    // determine HTTP method to use, default to POST
    if (requestMethod == nil)
    {
        requestMethod = @"POST";
    }
	
	// start the post    
    bar.currentRequest = [BaseHTTPRequest requestWithURL:url accountUUID:uuid];
    [bar.currentRequest setRequestMethod:requestMethod];
    [bar.currentRequest addRequestHeader:@"Content-Type" value:kAtomEntryMediaType];
    [bar.currentRequest setPostBody:[NSMutableData dataWithData:[body 
            dataUsingEncoding:NSUTF8StringEncoding]]];
    [bar.currentRequest setContentLength:[body length]];
    [bar.currentRequest setDelegate:bar];
    [bar.currentRequest setUploadProgressDelegate:bar];
    [bar.currentRequest setShouldContinueWhenAppEntersBackground:YES];
    [bar.currentRequest setSuppressAllErrors:suppressErrors];
    [bar.currentRequest startAsynchronous];
	return bar;
}

#pragma mark -
#pragma mark ASIHTTPRequestDelegate
-(void)requestFailed:(ASIHTTPRequest *)request
{
    NSLog(@"failed to upload file");
    [self performSelectorOnMainThread:@selector(uploadFailed:) withObject:request waitUntilDone:NO];
}

-(void)requestFinished:(ASIHTTPRequest *)request
{
    NSLog(@"upload file request finished");
    [self performSelectorOnMainThread:@selector(parseResponse:) withObject:request waitUntilDone:NO];
}

- (void)parseResponse:(ASIHTTPRequest *)request 
{
    // create a parser and parse the xml
	NSXMLParser *parser = [[NSXMLParser alloc] initWithData:[request.responseString dataUsingEncoding:NSUTF8StringEncoding]];
	[parser setDelegate:self];
	[parser setShouldProcessNamespaces:YES];
	[parser parse];
	[parser release];
    
	if (self.delegate) 
    {
		[delegate post: self completeWithData:self.fileData];
	}
    
    [progressAlert dismissWithClickedButtonIndex:0 animated:NO];
    [graceTimer invalidate];
}

- (void) uploadFailed: (ASIHTTPRequest *)request 
{
    if (self.delegate) 
    {
		[delegate post: self failedWithData:self.fileData];
	}
    
    [progressAlert dismissWithClickedButtonIndex:0 animated:NO];
    [graceTimer invalidate];
    
    if (!self.suppressErrors)
    {
        [self displayFailureMessage];
    }
}

#pragma mark -
#pragma mark NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI 
 qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    if ([CMISUtils isCmisNamespace:namespaceURI] && [elementName isEqualToString:@"propertyId"] 
        && [@"cmis:objectId" isEqualToString:(NSString *)[attributeDict objectForKey:@"propertyDefinitionId"]]) {
        isCmisObjectIdProperty = YES;
    }
    currentNamespaceUri = [namespaceURI retain];
    currentElementName = [elementName retain];
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    if (isCmisObjectIdProperty && [currentElementName isEqualToString:@"value"]) {
        [self setCmisObjectId:string];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([CMISUtils isCmisNamespace:namespaceURI] && [elementName isEqualToString:@"propertyId"]) {
        isCmisObjectIdProperty = NO;
    }
    [currentNamespaceUri release];
    [currentElementName release];
    currentNamespaceUri = nil;
    currentElementName = nil;
}

#pragma mark -
#pragma mark ASIProgressDelegate

- (void)setProgress:(float)newProgress {
    [self.progressView setProgress:newProgress];
}

- (void)request:(ASIHTTPRequest *)request didSendBytes:(long long)bytes {
    long bytesSent = request.postLength *self.progressView.progress;
    
    UILabel *label = (UILabel *)[self.progressAlert viewWithTag:kPostCounterTag];
    label.text = [NSString stringWithFormat:@"%@ %@ %@", 
     [FileUtils stringForLongFileSize:bytesSent],
     NSLocalizedString(@"of", @"'of' usage: 1 of 3, 2 of 3, 3 of 3"),
     [FileUtils stringForLongFileSize:request.postLength]];
}

#pragma mark -
#pragma mark UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
    [self.currentRequest clearDelegatesAndCancel];
    self.fileData = nil;
}

- (void)cancelActiveConnection:(NSNotification *)notification {
    //
    // Is this ever called?
    //
    NSLog(@"applicationWillResignActive in PostProgressBar");
    [[self currentRequest] clearDelegatesAndCancel];
    [progressAlert dismissWithClickedButtonIndex:0 animated:NO];
    [graceTimer invalidate];
}

#pragma mark -
#pragma mark NSTimer handler
- (void)handleGraceTimer
{
    [graceTimer invalidate];
    [self.progressAlert show];
}

@end