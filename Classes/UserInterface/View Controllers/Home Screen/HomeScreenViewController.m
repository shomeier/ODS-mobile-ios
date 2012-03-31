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
//  HomeScreenViewController.m
//

#import <QuartzCore/QuartzCore.h>
#import "HomeScreenViewController.h"
#import "ImageTextButton.h"
#import "NewCloudAccountViewController.h"
#import "AlfrescoAppDelegate.h"
#import "NSNotificationCenter+CustomNotification.h"
#import "UIColor+Theme.h"

static inline UIColor * kHighlightColor() {
    return [UIColor grayColor];
}

static inline UIColor * kBackgroundColor() {
    return [UIColor blackColor];
}

@interface HomeScreenViewController ()

@end

@implementation HomeScreenViewController
@synthesize cloudSignupButton = _cloudSignupButton;
@synthesize addAccountButton = _addAccountButton;
@synthesize scrollView = _scrollView;
@synthesize attributedFooterLabel = _attributedFooterLabel;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [_cloudSignupButton release];
    [_addAccountButton release];
    [_scrollView release];
    [_attributedFooterLabel release];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if(self.scrollView)
    {
        [self.scrollView setContentSize:CGSizeMake(320, 600)];
    }
    
    NSString *footerText = @"If you want to learn more about Alfresco Mobile take a look at our Guides in the Downloads area";
    [self.attributedFooterLabel setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin];
    [self.attributedFooterLabel setFont:[UIFont systemFontOfSize:15.0f]];
    [self.attributedFooterLabel setBackgroundColor:[UIColor clearColor]];
    UIColor *textColor = [UIColor colorWIthHexRed:201 green:204 blue:204 alphaTransparency:1];
    [self.attributedFooterLabel setTextColor:textColor];
    [self.attributedFooterLabel setDelegate:self];
    [self.attributedFooterLabel setTextAlignment:UITextAlignmentCenter];
    [self.attributedFooterLabel setVerticalAlignment:TTTAttributedLabelVerticalAlignmentTop];
    [self.attributedFooterLabel setLineBreakMode:UILineBreakModeWordWrap];
    [self.attributedFooterLabel setUserInteractionEnabled:YES];
    [self.attributedFooterLabel setNumberOfLines:0];
    [self.attributedFooterLabel setText:footerText];
    
    NSRange guideRange = [footerText rangeOfString:@"Guides"];
    if(guideRange.length > 0 && guideRange.location != NSNotFound)
    {
        UIColor *linkColor = [UIColor colorWIthHexRed:0 green:153 blue:255 alphaTransparency:1];
        NSMutableDictionary *mutableLinkAttributes = [NSMutableDictionary dictionary];
        [mutableLinkAttributes setValue:(id)[linkColor CGColor] forKey:(NSString*)kCTForegroundColorAttributeName];
        [self.attributedFooterLabel addLinkWithTextCheckingResult:[NSTextCheckingResult linkCheckingResultWithRange:guideRange URL:[NSURL URLWithString:nil]] attributes:mutableLinkAttributes];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppEntersBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

#pragma mark - Highllighting the custom Button
- (void)highlightButton:(UIButton *)button
{
    button.layer.backgroundColor = [kHighlightColor() CGColor];
    [self performSelector:@selector(resetHighlight:) withObject:button afterDelay:0.2];
}

- (void)resetHighlight:(UIButton *)button
{
    button.layer.backgroundColor = [kBackgroundColor() CGColor];
}

#pragma mark - UIButton actions
- (IBAction)cloudSignupButtonAction:(id)sender
{
    [self highlightButton:sender];
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"NewCloudAccountConfiguration" ofType:@"plist"];
    NewCloudAccountViewController *viewController = [NewCloudAccountViewController genericTableViewWithPlistPath:plistPath andTableViewStyle:UITableViewStyleGrouped];
    [viewController setDelegate:self];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
    [navController setModalPresentationStyle:UIModalPresentationFormSheet];
    [navController setModalTransitionStyle:UIModalTransitionStyleCoverVertical];
    [self presentModalViewController:navController animated:YES];
    [navController release];
}

- (IBAction)addAccountButtonAction:(id)sender
{
    [self highlightButton:sender];
    AccountTypeViewController *newAccountController = [[AccountTypeViewController alloc] initWithStyle:UITableViewStyleGrouped];
    [newAccountController setDelegate:self];
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:newAccountController];
    
    [navController setModalTransitionStyle:UIModalTransitionStyleCoverVertical];
    [navController setModalPresentationStyle:UIModalPresentationFormSheet];
    [self presentModalViewController:navController animated:YES];
    
    [navController release];
    [newAccountController release];
}

#pragma mark - AccountViewControllerDelegate methods
- (void)accountControllerDidCancel:(AccountViewController *)accountViewController
{
    // We will dismiss the current modal view controller, at this point is the Alfresco signup/Add account view Controllers
    [self dismissModalViewControllerAnimated:YES];
}

- (void)accountControllerDidFinishSaving:(AccountViewController *)accountViewController
{
    //TODO: Go to the account details
    AlfrescoAppDelegate *appDelegate = (AlfrescoAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate dismissHomeScreenController];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"ShowHomescreen"];
    [[NSNotificationCenter defaultCenter] postLastAccountDetailsNotification:nil];
}

#pragma mark - TTTAttributedLabelDelegate methods
- (void)attributedLabel:(TTTAttributedLabel *)label didSelectLinkWithURL:(NSURL *)url
{
    AlfrescoAppDelegate *appDelegate = (AlfrescoAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate dismissHomeScreenController];
    //The "navigationController" is actually the navigation controller of the downloads tab, we may want to change this to be
    //more descriptive
    [appDelegate.tabBarController setSelectedViewController:appDelegate.navigationController];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"ShowHomescreen"];
}

// We need to dismiss the homescreen if we enter the background to avoid a weird bug
// were the more tab is blank after dismissing the homescreen
- (void)handleAppEntersBackground:(NSNotification *)notification
{
    AlfrescoAppDelegate *appDelegate = (AlfrescoAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate dismissHomeScreenController];
}

@end
