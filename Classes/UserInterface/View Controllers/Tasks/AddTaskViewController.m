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
//  AddTaskViewController.m
//

#import "AddTaskViewController.h"
#import "Theme.h"
#import "DocumentPickerViewController.h"
#import "DocumentPickerSelection.h"
#import "DatePickerViewController.h"
#import "PeoplePickerViewController.h"
#import "TaskManager.h"
#import "TaskAttachmentsViewController.h"
#import "TaskAssigneesViewController.h"
#import "ASIHTTPRequest.h"
#import "MBProgressHUD.h"
#import "Utility.h"
#import "RepositoryItem.h"
#import "DocumentItem.h"
#import "Kal.h"

@interface AddTaskViewController () <ASIHTTPRequestDelegate, DocumentPickerViewControllerDelegate, DatePickerDelegate, PeoplePickerDelegate, MBProgressHUDDelegate>

@property (nonatomic, retain) NSDate *dueDate;
@property (nonatomic, retain) NSMutableArray *assignees;
@property (nonatomic, retain) NSMutableArray *attachments;
@property (nonatomic, retain) NSString *accountUuid;
@property (nonatomic, retain) NSString *tenantID;
@property (nonatomic) AlfrescoTaskType taskType;

@property (nonatomic, retain) DocumentPickerViewController *documentPickerViewController;

// View
@property (nonatomic, retain) MBProgressHUD *progressHud;
@property (nonatomic, retain) UITextField *titleField;
@property (nonatomic, retain) UISegmentedControl *priorityControl;
@property (nonatomic, retain) UISwitch *emailSwitch;

@property (nonatomic, retain) UIPopoverController *datePopoverController;
@property (nonatomic, retain) KalViewController *kal;

@end

@implementation AddTaskViewController

@synthesize documentPickerViewController = _documentPickerViewController;
@synthesize dueDate = _dueDate;
@synthesize assignees = _assignees;
@synthesize attachments = _attachments;

@synthesize accountUuid = _accountUuid;
@synthesize tenantID = _tenantID;
@synthesize taskType = _taskType;
@synthesize progressHud = _progressHud;
@synthesize priorityControl = _priorityControl;
@synthesize emailSwitch = _emailSwitch;
@synthesize titleField = _titleField;

@synthesize datePopoverController = _datePopoverController;
@synthesize kal = _kal;

- (void)dealloc
{
    [_documentPickerViewController release];
    [_dueDate release];
    [_assignees release];
    [_attachments release];
    [_accountUuid release];
    [_tenantID release];
    [_progressHud release];
    [_priorityControl release];
    [_emailSwitch release];
    [_titleField release];
    
    [super dealloc];
}

- (id)initWithStyle:(UITableViewStyle)style account:(NSString *)uuid tenantID:(NSString *)tenantID 
           taskType:(AlfrescoTaskType)taskType attachment:(RepositoryItem *)attachment
{
    self = [self initWithStyle:style account:uuid tenantID:tenantID taskType:taskType];
    if (self)
    {
        self.attachments = [NSMutableArray arrayWithObject:attachment];
    }
    return self;
}

- (id)initWithStyle:(UITableViewStyle)style account:(NSString *)uuid tenantID:(NSString *)tenantID taskType:(AlfrescoTaskType)taskType
{
    self = [super initWithStyle:style];
    if (self) 
    {
        self.accountUuid = uuid;
        self.tenantID = tenantID;
        self.taskType = taskType;
    }
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    [Theme setThemeForUITableViewController:self];
    self.navigationItem.title = NSLocalizedString(@"task.create.title", nil);
    
    [self.navigationItem setLeftBarButtonItem:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                             target:self
                                                                                             action:@selector(cancelButtonTapped:)] autorelease]];
    
    UIBarButtonItem *createButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                   target:self
                                                                                   action:@selector(createTaskButtonTapped:)] autorelease];
    [createButton setTitle:NSLocalizedString(@"task.create.button", nil)];
    [self.navigationItem setRightBarButtonItem:createButton];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // When navigation controller is popped to this controller, reload the data to reflect any changes
    [self.tableView reloadData];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (void)createTaskButtonTapped:(id)sender
{
    if (self.titleField.text.length < 1)
    {
        UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"task.create.notitle.title", nil)
                                                             message:NSLocalizedString(@"task.create.notitle.message", nil) 
                                                            delegate:nil cancelButtonTitle:@"OK"otherButtonTitles:nil] autorelease];
        [alertView show];
        return;
    }
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeIndeterminate;
    hud.labelText = NSLocalizedString(@"task.create.creating", nil);
    self.progressHud = hud;
    [self.view resignFirstResponder];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, (unsigned long) NULL), ^(void)
    {
        TaskItem *task = [[[TaskItem alloc] init] autorelease];
        task.title = self.titleField.text;
        task.taskType = self.taskType;
        task.dueDate = self.dueDate;
        task.priorityInt = self.priorityControl.selectedSegmentIndex + 1;
        task.emailNotification = self.emailSwitch.isOn;
        
        if (self.attachments)
        {
            NSMutableArray *documentItems = [NSMutableArray arrayWithCapacity:self.attachments.count];
            for (RepositoryItem *repositoryItem in self.attachments)
            {
                DocumentItem *documentItem = [[DocumentItem alloc] initWithRepositoryItem:repositoryItem];
                [documentItems addObject:documentItem];
                [documentItem release];
            }
            task.documentItems = documentItems;
        }

        NSArray *assigneeArray = [NSArray arrayWithArray:self.assignees];
        
        [[TaskManager sharedManager] startTaskCreateRequestForTask:task assignees:assigneeArray 
                                                       accountUUID:self.accountUuid tenantID:self.tenantID delegate:self];
    });
}

- (void)cancelButtonTapped:(id)sender
{
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark ASIHttpRequest delegate

- (void)requestFinished:(ASIHTTPRequest *)request
{
    self.progressHud.labelText = NSLocalizedString(@"task.create.created", nil);
    self.progressHud.delegate = self;
    [self.progressHud hide:YES afterDelay:0.5];
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    stopProgressHUD(self.progressHud);
    UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"task.create.error", nil)
                      message:request.error.localizedDescription delegate:nil cancelButtonTitle:@"OK"otherButtonTitles:nil] autorelease];
    [alertView show];
}

#pragma mark MBprogressHud delegate

- (void)hudWasHidden:(MBProgressHUD *)hud
{
    [self dismissModalViewControllerAnimated:YES];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 6;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil)
    {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
    }
    
    if (indexPath.row == 0)
    {
        cell.textLabel.text = NSLocalizedString(@"task.create.taskTitle", nil);
        if (!self.titleField)
        {
            UITextField *titleField = [[UITextField alloc] init];
            if (IS_IPAD)
            {
                titleField.frame = CGRectMake(150, 12, 300, 30);
            }
            else
            {
                titleField.frame = CGRectMake(100, 12, 205, 30);
            }
            titleField.placeholder = NSLocalizedString(@"task.create.taskTitle.placeholder", nil);
            titleField.autocorrectionType = UITextAutocorrectionTypeNo;
            titleField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
            titleField.adjustsFontSizeToFitWidth = YES;
            titleField.tag = 101;

            self.titleField = titleField;
            [titleField release];
        }
        [cell addSubview:self.titleField];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    else if (indexPath.row == 1)
    {
        cell.textLabel.text = NSLocalizedString(@"task.create.duedate", nil);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if (self.dueDate)
        {
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            df.dateStyle = NSDateFormatterMediumStyle;
            cell.detailTextLabel.text = [df stringFromDate:self.dueDate];
            [df release];
        }
        else
        {
            cell.detailTextLabel.text = NSLocalizedString(@"task.create.duedate.placeholder", nil);
        }
    }
    else if (indexPath.row == 2)
    {
        if (self.taskType == TASK_TYPE_TODO)
        {
            cell.textLabel.text = NSLocalizedString(@"task.create.assignee", nil);
        }
        else 
        {
            cell.textLabel.text = NSLocalizedString(@"task.create.assignees", nil);
        }
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if (self.assignees != nil && self.assignees.count > 0)
        {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%d %@", self.assignees.count,
                                         (self.assignees.count > 1) ? [NSLocalizedString(@"task.create.assignees", nil) lowercaseString]
                                                                  : [NSLocalizedString(@"task.create.assignee", nil) lowercaseString]];
        }
        else
        {
            cell.detailTextLabel.text = NSLocalizedString(@"task.create.assignee.placeholder", nil);
        }
    }
    else if (indexPath.row == 3)
    {
        cell.textLabel.text = NSLocalizedString(@"task.create.attachments", nil);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if (self.attachments != nil && self.attachments.count > 0)
        {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%d %@", self.attachments.count,
                      (self.attachments.count > 1) ? [NSLocalizedString(@"task.create.attachments", nil) lowercaseString]
                                                   : [NSLocalizedString(@"task.create.attachment", nil) lowercaseString]];
        }
        else
        {
            cell.detailTextLabel.text = NSLocalizedString(@"task.create.attachments.placeholder", nil);
        }
    }
    else if (indexPath.row == 4)
    {
        cell.textLabel.text = NSLocalizedString(@"task.create.priority", nil);
        NSArray *itemArray = [NSArray arrayWithObjects:NSLocalizedString(@"task.create.priority.high", nil),
                                                       NSLocalizedString(@"task.create.priority.medium", nil),
                                                       NSLocalizedString(@"task.create.priority.low", nil), nil];
        if (!self.priorityControl)
        {
            UISegmentedControl *priorityControl = [[UISegmentedControl alloc] initWithItems:itemArray];
            if (IS_IPAD)
            {
                priorityControl.frame = CGRectMake(248, 7, 250, 30);
            }
            else
            {
                priorityControl.frame = CGRectMake(100, 6, 205, 30);
                [priorityControl setWidth:85.0 forSegmentAtIndex:1];
            }
            priorityControl.segmentedControlStyle = UISegmentedControlStylePlain;
            priorityControl.selectedSegmentIndex = 1;

            self.priorityControl = priorityControl;
            [priorityControl release];
        }
        [cell addSubview:self.priorityControl];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    else if (indexPath.row == 5)
    {
        cell.textLabel.text = NSLocalizedString(@"task.create.emailnotification", nil);
        
        if (!self.emailSwitch)
        {
            UISwitch *emailSwitch = [[UISwitch alloc] init];
            if (IS_IPAD)
            {
                emailSwitch.frame = CGRectMake(420, 7, 40, 30);
            }
            else
            {
                emailSwitch.frame = CGRectMake(227, 6, 40, 30);
            }
            
            self.emailSwitch = emailSwitch;
            [emailSwitch release];
        }
        [cell addSubview:self.emailSwitch];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 1)
    {
        /*DatePickerViewController *datePicker = [[DatePickerViewController alloc] initWithNSDate:self.dueDate];
        datePicker.delegate = self;
        datePicker.title = NSLocalizedString(@"task.create.date.picker.title", nil);
        [self.navigationController pushViewController:datePicker animated:YES];
        [datePicker release];*/
        [self showDatePicker:[self.tableView cellForRowAtIndexPath:indexPath]];
    }
    else if (indexPath.row == 2)
    {
        if (self.assignees && self.assignees.count > 0)
        {
            TaskAssigneesViewController *taskAssigneesViewController = [[TaskAssigneesViewController alloc] initWithAccount:self.accountUuid tenantID:self.tenantID];
            taskAssigneesViewController.assignees = self.assignees;
            if (self.taskType == TASK_TYPE_TODO)
            {
                taskAssigneesViewController.isMultipleSelection = NO;
            }
            else 
            {
                taskAssigneesViewController.isMultipleSelection = YES;
            }
            [self.navigationController pushViewController:taskAssigneesViewController animated:YES];
            [taskAssigneesViewController release];
        }
        else 
        {
            PeoplePickerViewController *peoplePicker = [[PeoplePickerViewController alloc] initWithAccount:self.accountUuid tenantID:self.tenantID];
            peoplePicker.delegate = self;
            if (self.taskType == TASK_TYPE_TODO)
            {
                peoplePicker.isMultipleSelection = NO;
            }
            else 
            {
                peoplePicker.isMultipleSelection = YES;
            }
            [self.navigationController pushViewController:peoplePicker animated:YES];
            [peoplePicker release];
        }
    }
    else if (indexPath.row == 3)
    {
        // Instantiate document picker if it doesn't exist yet.
        if (!self.documentPickerViewController)
        {
            DocumentPickerViewController *documentPicker = [DocumentPickerViewController documentPickerForAccount:self.accountUuid tenantId:self.tenantID];
            documentPicker.selection.selectiontextPrefix = NSLocalizedString(@"document.picker.selection.button.attach", nil);
            documentPicker.delegate = self;

            self.documentPickerViewController = documentPicker;
        }
        else
        {
            // We need to make sure that the picker also shows already selected items as being selected.
            // But in the meantime, some could have been deleted and the selection is out of sync.
            // So here we clear it first, and add all the current attachments.
            [self.documentPickerViewController.selection clearAll];
            [self.documentPickerViewController.selection addDocuments:self.attachments];
        }

        // Show document picker directly if no attachment are already chosen
        if (self.attachments == nil || self.attachments.count == 0)
        {
            [self.documentPickerViewController reopenAtLastLocationWithNavigationController:self.navigationController];
        }
        else // Show the attachment overview controller otherwise
        {
            TaskAttachmentsViewController *taskAttachmentsViewController = [[TaskAttachmentsViewController alloc] init];
            taskAttachmentsViewController.attachments = self.attachments;
            taskAttachmentsViewController.documentPickerViewController = self.documentPickerViewController;
            [self.navigationController pushViewController:taskAttachmentsViewController animated:YES];
            [taskAttachmentsViewController release];
        }
    }
}


-(void)showDatePicker:(UITableViewCell *)cell
{
    if (self.dueDate)
    {
        self.kal = [[KalViewController alloc] initWithSelectedDate:self.dueDate];
    }
    else 
    {
        self.kal = [[KalViewController alloc] init];
    }
    self.kal.title = NSLocalizedString(@"date.picker.title", nil);
    self.kal.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"date.picker.today", nil) 
                                                                              style:UIBarButtonItemStyleBordered 
                                                                             target:self 
                                                                             action:@selector(showAndSelectToday)] autorelease];
    
    self.kal.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
                                                                                              target:self action:@selector(pickerDone:)];
    
    if (IS_IPAD)
    {
    
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self.kal];
        
        UIView* popoverView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 310)];
        popoverView.backgroundColor = [UIColor whiteColor];
        
        //resize the popover view shown
        //in the current view to the view's size
        self.kal.contentSizeForViewInPopover = CGSizeMake(320, 310);
        
        //create a popover controller
        self.datePopoverController = [[UIPopoverController alloc] initWithContentViewController:navController];
        CGRect popoverRect = [self.view convertRect:[cell frame] 
                                           fromView:self.tableView];
        
        popoverRect.size.width = MIN(popoverRect.size.width, 100) ; 
        popoverRect.origin.x  = popoverRect.origin.x; 
        
        [self.datePopoverController 
         presentPopoverFromRect:popoverRect
         inView:self.view 
         permittedArrowDirections:UIPopoverArrowDirectionUp
         animated:YES];
        
        
        //release the popover content
        [popoverView release];
    }
    else 
    {
        [self.navigationController pushViewController:self.kal animated:YES];
    }
}

- (void)showAndSelectToday
{
    [self.kal showAndSelectDate:[NSDate date]];
}

- (void)pickerDone:(id)sender
{
    if (self.kal != nil)
    {
        self.dueDate = self.kal.selectedDate;
        self.kal = nil;
        [self.tableView reloadData];
        
        if (!IS_IPAD)
        {
            [self.navigationController popViewControllerAnimated:YES];
        }
    }
    
    if (self.datePopoverController) {
        [self.datePopoverController dismissPopoverAnimated:YES];
        self.datePopoverController = nil;
    }  
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    if (self.datePopoverController) {
        [self.datePopoverController dismissPopoverAnimated:YES];
        self.datePopoverController = nil;
    }
}

#pragma mark - DatePicker delegate

- (void)datePicked:(NSDate *)date
{
    self.dueDate = date;
}

#pragma mark - PeoplePicker delegate

- (void)personsPicked:(NSArray *)persons
{
    self.assignees = [NSMutableArray arrayWithArray:persons];
}

#pragma mark - Document picker delegate

- (void)pickingFinished:(DocumentPickerSelection *)selection
{
    if (selection.selectedDocuments.count > 0)
    {
        if (!self.attachments)
        {
            self.attachments = [NSMutableArray arrayWithCapacity:selection.selectedDocuments.count];
        }

        // Selection object will always contain ALL the selected documents, not just the one who were newly picked
        [self.attachments removeAllObjects];
        [self.attachments addObjectsFromArray:selection.selectedDocuments];
    }
}

@end
