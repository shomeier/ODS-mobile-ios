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
//  TaskCreateHTTPRequest.m
//

#import "TaskCreateHTTPRequest.h"
#import "DocumentItem.h"
#import "ISO8601DateFormatter.h"

@implementation TaskCreateHTTPRequest

- (void)requestFinishedWithSuccessResponse
{
}

+ (TaskCreateHTTPRequest *)taskCreateRequestForTask:(TaskItem *)task assigneeNodeRefs:(NSArray *)assigneeNodeRefs
                                        accountUUID:(NSString *)uuid tenantID:(NSString *)tenantID
{
    NSString *workflowName;
    if (task.workflowType == AlfrescoWorkflowTypeTodo)
    {
        workflowName = task.createTaskUsingActivitiWorkflowEngine ? @"activiti$activitiAdhoc" : @"jbpm$wf:adhoc";
    }
    else 
    {
        workflowName = task.createTaskUsingActivitiWorkflowEngine ? @"activiti$activitiParallelReview" : @"jbpm$wf:parallelreview";
    }

    NSDictionary *infoDictionary = [NSDictionary dictionaryWithObject:workflowName forKey:@"WORKFLOWNAME"];

    TaskCreateHTTPRequest *request = [TaskCreateHTTPRequest requestForServerAPI:kServerAPITaskCreate accountUUID:uuid tenantID:tenantID infoDictionary:infoDictionary];
    request.accountUUID = uuid;
    request.tenantID = tenantID;
    
    NSMutableDictionary *postDict = [NSMutableDictionary dictionary];
    [postDict setValue:task.title forKey:@"prop_bpm_workflowDescription"];
    
    if (assigneeNodeRefs && assigneeNodeRefs.count > 0)
    {
        NSString *assigneesAdded = nil;
        for (NSString *assignee in assigneeNodeRefs) {
            if (!assigneesAdded || assigneesAdded.length == 0)
            {
                assigneesAdded = [NSString stringWithString:assignee];
            }
            else 
            {
                assigneesAdded = [NSString stringWithFormat:@"%@,%@", assigneesAdded, assignee];
            }
        }
        
        if (task.workflowType == AlfrescoWorkflowTypeTodo)
        {
            [postDict setValue:assigneesAdded forKey:@"assoc_bpm_assignee_added"];
        }
        else 
        {
            [postDict setValue:assigneesAdded forKey:@"assoc_bpm_assignees_added"];
        }
    }
    
    [postDict setValue:[NSNumber numberWithInt:task.priorityInt] forKey:@"prop_bpm_workflowPriority"];
    if (task.emailNotification == YES)
    {
        [postDict setValue:@"true" forKey:@"prop_bpm_sendEMailNotifications"];
    }
    
    if (task.workflowType == AlfrescoWorkflowTypeReview)
    {
        [postDict setValue:[NSNumber numberWithInt:task.approvalPercentage] forKey:@"prop_wf_requiredApprovePercent"];
    }
    
    if (task.dueDate)
    {
        ISO8601DateFormatter *isoFormatter = [[ISO8601DateFormatter alloc] init];
        isoFormatter.includeTime = YES;
        NSString *dueDateString = [isoFormatter stringFromDate:task.dueDate timeZone:[NSTimeZone defaultTimeZone]];
        [isoFormatter release];
        
        // GMT gets a "Z" suffix instead of a time offset
        if (![dueDateString hasSuffix:@"Z"])
        {
            // hack to get timezone as +02:00 instead of +0200
            dueDateString = [NSString stringWithFormat:@"%@:%@", [dueDateString substringToIndex:dueDateString.length -2], 
                             [dueDateString substringFromIndex:dueDateString.length - 2]];
        }
        [postDict setValue:dueDateString forKey:@"prop_bpm_workflowDueDate"];
    }
    
    if (task.documentItems && task.documentItems.count > 0)
    {
        NSString *documentsAdded = nil;
        for (DocumentItem *document in task.documentItems) {
            if (!documentsAdded || documentsAdded.length == 0)
            {
                documentsAdded = [NSString stringWithString:document.nodeRef];
            }
            else 
            {
                documentsAdded = [NSString stringWithFormat:@"%@,%@", documentsAdded, document.nodeRef];
            }
        }
        [postDict setValue:documentsAdded forKey:@"assoc_packageItems_added"];
    }
    
    [request setPostBody:[request mutableDataFromJSONObject:postDict]];
    [request setContentLength:[request.postBody length]];
    [request setRequestMethod:@"POST"];
    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    
    return request;
}

@end
