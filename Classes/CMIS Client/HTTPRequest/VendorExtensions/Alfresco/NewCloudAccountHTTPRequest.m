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
//  NewCloudAccountHTTPRequest.m
//

#import "NewCloudAccountHTTPRequest.h"
#import "AccountManager.h"

@implementation NewCloudAccountHTTPRequest
@synthesize signupSuccess = _signupSuccess;
@synthesize signupAccount = _signupAccount;
@synthesize blockedEmail = _invalidEmail;

- (void)dealloc
{
    [_signupAccount release];
    [super dealloc];
}

- (void)requestFinishedWithSuccessResponse
{
    AlfrescoLogTrace(@"Successful cloud signup response: %@", self.responseString);

    NSDictionary *responseJson = [self dictionaryFromJSONResponse];
    NSMutableDictionary *registrationJson = [responseJson objectForKey:@"registration"];
    NSString *cloudId = [registrationJson objectForKey:@"id"];
    NSString *cloudKey = [registrationJson objectForKey:@"key"];
    
    if ([cloudId isNotEmpty] && [cloudKey isNotEmpty])
    {
        [self setSignupAccount:[[AccountManager sharedManager] accountInfoForUUID:[self.signupAccount uuid]]];
        [self.signupAccount setCloudId:cloudId];
        [self.signupAccount setCloudKey:cloudKey];
        [[AccountManager sharedManager] saveAccountInfo:self.signupAccount];
        [self setSignupSuccess:YES];
    }
    else
    {
        [self setSignupSuccess:NO];
    }
}

- (void)failWithError:(NSError *)theError
{
    AlfrescoLogTrace(@"\n\n***\nRequestFailure\t%@: StatusCode:%d StatusMessage:%@\n\t%@\nURL:%@\n***\n\n",
          self.class, [self responseStatusCode], [self responseStatusMessage], theError, self.url);

    NSDictionary *responseJson = [self dictionaryFromJSONResponse];
    NSString *message = [responseJson objectForKey:@"message"];
    if ([message rangeOfString:@"Invalid Email Address"].location != NSNotFound)
    {
        [self setBlockedEmail:YES];
    }
    [self setSignupSuccess:NO];
    
    [super failWithError:theError];

}

+ (NewCloudAccountHTTPRequest *)cloudSignupRequestWithAccount:(AccountInfo *)accountInfo
{
    NewCloudAccountHTTPRequest *request = [NewCloudAccountHTTPRequest requestForServerAPI:kServerAPICloudSignup accountUUID:[accountInfo uuid] tenantID:nil infoDictionary:nil useAuthentication:NO];
    [request setSignupAccount:accountInfo];
    NSMutableDictionary *accountDict = [NSMutableDictionary dictionaryWithCapacity:5];
    [accountDict setObject:[accountInfo username] forKey:@"email"];
    [accountDict setObject:[accountInfo firstName] forKey:@"firstName"];
    [accountDict setObject:[accountInfo lastName] forKey:@"lastName"];
    [accountDict setObject:[accountInfo password] forKey:@"password"];
    [accountDict setObject:@"mobile" forKey:@"source"];
    
    [request setPostBody:[request mutableDataFromJSONObject:accountDict]];
    [request setContentLength:[request.postBody length]];
    [request setBlockedEmail:NO];
    
    return request;
}

@end
