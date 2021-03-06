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
//  SystemNotice.m
//

#import <QuartzCore/QuartzCore.h>

#import "SystemNotice.h"
#import "SystemNoticeManager.h"
#import "SystemNoticeGradientView.h"

@interface SystemNotice ()
@property (nonatomic, assign, readwrite) SystemNoticeStyle noticeStyle;
@property (nonatomic, retain) UIView *view;
@property (nonatomic, strong) UIView *noticeView;
@property (nonatomic, assign) SystemNoticeGradientColor gradientColor;
@property (nonatomic, strong) NSString *icon;
@property (nonatomic, strong) UIColor *labelColor;
@property (nonatomic, strong) UIColor *shadowColor;
@property (nonatomic, strong) NSString *defaultTitle;
@property (nonatomic, retain) UILabel *titleLabel;
@property (nonatomic, retain) UILabel *messageLabel;
@property (nonatomic, assign) CGFloat offsetY;
@end

@implementation SystemNotice

CGFloat hiddenYOrigin;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_noticeView release];
    [_icon release];
    [_labelColor release];
    [_shadowColor release];
    [_defaultTitle release];
    [_titleLabel release];
    [_messageLabel release];
    
    [_view release];
    [_message release];
    [_title release];
    
    [super dealloc];
}

#pragma mark - Public API

- (id)initWithStyle:(SystemNoticeStyle)style inView:(UIView *)view
{
    if (self = [super init])
    {
        self.noticeStyle = style;
        self.view = view;
        
        switch (style)
        {
            case SystemNoticeStyleInformation:
                self.gradientColor = SystemNoticeGradientColorBlue;
                self.icon = @"system_notice_info";
                self.labelColor = [UIColor whiteColor];
                self.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.2];
                self.displayTime = 1.5f;
                break;
                
            case SystemNoticeStyleError:
                self.gradientColor = SystemNoticeGradientColorRed;
                self.icon = @"system_notice_error";
                self.labelColor = [UIColor whiteColor];
                self.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.2];
                self.defaultTitle = NSLocalizedString(@"An Error Occurred", @"Default title for error notification");
                self.displayTime = 8.0f;
                break;
            
            case SystemNoticeStyleWarning:
                self.gradientColor = SystemNoticeGradientColorYellow;
                self.icon = @"system_notice_warning";
                self.labelColor = [UIColor blackColor];
                self.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.2];
                self.displayTime = 3.0f;
                break;

            default:
                return nil;
        }
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if ([object class] == [SystemNotice class])
    {
        SystemNotice *test = (SystemNotice *)object;
        if (test.noticeStyle == self.noticeStyle &&
            [test.title isEqualToString:self.title] &&
            [test.message isEqualToString:self.message])
        {
            return YES;
        }
    }
    return NO;
}

- (void)show
{
    [self createNotice];
    [[SystemNoticeManager sharedManager] queueSystemNotice:self];
}

#pragma mark - Internal Create & View methods

- (void)canDisplay
{
    [self displayNotice];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)createNotice
{
    // Get the view width, allowing for rotations
    CGRect rotatedView = CGRectApplyAffineTransform(self.view.frame, self.view.transform);
    CGFloat viewWidth = rotatedView.size.width;
    
    // Check the notice won't disappear behind the status bar
    CGRect appFrame = [[UIScreen mainScreen] applicationFrame];
    CGRect rotatedAppFrame = CGRectApplyAffineTransform(appFrame, self.view.transform);
    CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
    CGRect rotatedStatusBarFrame = CGRectApplyAffineTransform(statusBarFrame, self.view.transform);

    if (rotatedView.size.height > rotatedAppFrame.size.height)
    {
        self.offsetY += rotatedStatusBarFrame.size.height;
    }
    
    CGFloat messageLineHeight = 15.0;
    CGFloat originY = (self.message) ? 10.0 : 18.0;
    
    self.titleLabel = [[[UILabel alloc] initWithFrame:CGRectMake(55.0, originY, viewWidth - 70.0, 16.0)] autorelease];
    self.titleLabel.textColor = self.labelColor;
    self.titleLabel.shadowOffset = CGSizeMake(0.0, -1.0);
    self.titleLabel.shadowColor = self.shadowColor;
    self.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.titleLabel.text = (self.title != nil) ? self.title : self.defaultTitle;
    
    // Message label
    if (self.message)
    {
        self.messageLabel = [[[UILabel alloc] initWithFrame:CGRectMake(55.0, 10.0 + 10.0, viewWidth - 70.0, messageLineHeight)] autorelease];
        self.messageLabel.font = [UIFont systemFontOfSize:13.0];
        self.messageLabel.textColor = self.labelColor;
        self.messageLabel.shadowOffset = CGSizeMake(0.0, -1.0);
        self.messageLabel.shadowColor = self.shadowColor;
        self.messageLabel.backgroundColor = [UIColor clearColor];
        self.messageLabel.text = self.message;
        self.messageLabel.numberOfLines = 0;
        self.messageLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        CGRect rect = self.messageLabel.frame;
        rect.origin.y = self.titleLabel.frame.origin.y + self.titleLabel.frame.size.height;
        
        // Prevent UILabel centering the text in the middle
        [self.messageLabel sizeToFit];
        
        // Determine the height of the message
        messageLineHeight = 5.0 + self.messageLabel.frame.size.height;
        rect.size.height = self.messageLabel.frame.size.height;
        rect.size.width = viewWidth - 70.0;
        self.messageLabel.frame = rect;
    }
    
    // Calculate the notice view height
    float noticeViewHeight = 25.0 + messageLineHeight;
    
    // Allow for shadow when hiding
    hiddenYOrigin = 0.0 - noticeViewHeight - 20.0;
    
    // Gradient view dependant on notice type
    CGRect gradientRect = CGRectMake(0.0, hiddenYOrigin, viewWidth, noticeViewHeight + 10.0);
    self.noticeView = [[[SystemNoticeGradientView alloc] initGradientViewColor:self.gradientColor frame:gradientRect] autorelease];
    self.noticeView.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.noticeView.contentMode = UIViewContentModeCenter;
    [self.noticeView setHidden:YES];   //to fix sometime the notice view always show on the view, we can see it when present video view.
    [self.view addSubview:self.noticeView];
    
    // Icon view
    UIImageView *iconView = [[[UIImageView alloc] initWithFrame:CGRectMake(15.0, 10.0, 20.0, 30.0)] autorelease];
    iconView.image = [UIImage imageNamed:self.icon];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.alpha = 0.9;
    [self.noticeView addSubview:iconView];
    
    // Title label
    [self.noticeView addSubview:self.titleLabel];
    
    // Message label
    [self.noticeView addSubview:self.messageLabel];
    
    // Drop shadow
    CALayer *noticeLayer = self.noticeView.layer;
    noticeLayer.shadowColor = [[UIColor blackColor] CGColor];
    noticeLayer.shadowOffset = CGSizeMake(0.0, 3);
    noticeLayer.shadowOpacity = 0.50;
    noticeLayer.masksToBounds = NO;
    
    // Invisible button to manually dismiss the notice
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0.0, 0.0, self.noticeView.frame.size.width, self.noticeView.frame.size.height);
    [button addTarget:self action:@selector(dismissNotice) forControlEvents:UIControlEventTouchUpInside];
    [self.noticeView addSubview:button];
}

- (void)displayNotice
{
    [self.noticeView setHidden:NO];
    [UIView animateWithDuration:0.5f delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        CGRect newFrame = self.noticeView.frame;
        newFrame.origin.y = self.offsetY;
        self.noticeView.frame = newFrame;
    } completion:^(BOOL finished){
        [self performSelector:@selector(dismissNotice) withObject:nil afterDelay:self.displayTime];
    }];
}

- (void)dismissNotice
{
    [self dismissNoticeAnimated:YES];
}

- (void)dismissNoticeAnimated:(BOOL)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.5f delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            CGRect newFrame = self.noticeView.frame;
            newFrame.origin.y = hiddenYOrigin;
            self.noticeView.frame = newFrame;
        } completion:^(BOOL finished){
            [self.noticeView removeFromSuperview];
            [[SystemNoticeManager sharedManager] systemNoticeDidDisappear:self];
        }];
    }
    else
    {
        [self.noticeView removeFromSuperview];
        [[SystemNoticeManager sharedManager] systemNoticeDidDisappear:self];
    }
}

#pragma mark - Device Orientation Notification

- (void)orientationChanged:(NSNotification *)notification
{
    if (IS_IPAD && UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation))
    {
        [self dismissNotice];
    }
}

#pragma mark - Class Methods

+ (SystemNotice *)showInformationNoticeInView:(UIView *)view message:(NSString *)message
{
    // We use the title for a simple information message type
    SystemNotice *notice = [SystemNotice systemNoticeWithStyle:SystemNoticeStyleInformation inView:view message:nil title:message];
    [notice show];
    return notice;
}

+ (SystemNotice *)showInformationNoticeInView:(UIView *)view message:(NSString *)message title:(NSString *)title
{
    SystemNotice *notice =  [SystemNotice systemNoticeWithStyle:SystemNoticeStyleInformation inView:view message:message title:title];
    [notice show];
    return notice;
}

+ (SystemNotice *)showErrorNoticeInView:(UIView *)view message:(NSString *)message
{
    // An error type without specified title will be given a generic "An Error Occurred" title
    SystemNotice *notice =  [SystemNotice systemNoticeWithStyle:SystemNoticeStyleError inView:view message:message title:nil];
    [notice show];
    return notice;
}

+ (SystemNotice *)showErrorNoticeInView:(UIView *)view message:(NSString *)message title:(NSString *)title
{
    SystemNotice *notice =  [SystemNotice systemNoticeWithStyle:SystemNoticeStyleError inView:view message:message title:title];
    [notice show];
    return notice;
}

+ (SystemNotice *)showWarningNoticeInView:(UIView *)view message:(NSString *)message title:(NSString *)title
{
    SystemNotice *notice =  [SystemNotice systemNoticeWithStyle:SystemNoticeStyleWarning inView:view message:message title:title];
    [notice show];
    return notice;
}

+ (SystemNotice *)systemNoticeWithStyle:(SystemNoticeStyle)style inView:(UIView *)view message:(NSString *)message title:(NSString *)title
{
    SystemNotice *notice =  [[[SystemNotice alloc] initWithStyle:style inView:view] autorelease];
    notice.message = message;
    notice.title = title;
    return notice;
}

@end
