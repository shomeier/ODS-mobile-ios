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
//  IFLocationCellController.h
//

#import <UIKit/UIKit.h>

#import "IFCellController.h"
#import "IFCellModel.h"
#import "LocationViewController.h"

@interface IFLocationCellController : NSObject <IFCellController> {
	NSString *label;
	id<IFCellModel> model;
	NSString *key;
	
	UIColor *backgroundColor;
	UIColor *viewBackgroundColor;
	UITableViewCellSelectionStyle selectionStyle;
	
	NSInteger indentationLevel;
	
	UITableViewController *tableViewController;
	NSIndexPath *cellIndexPath;
}

@property (nonatomic, retain) UIColor *backgroundColor;
@property (nonatomic, retain) UIColor *viewBackgroundColor;
@property (nonatomic, assign) UITableViewCellSelectionStyle selectionStyle;
@property (nonatomic, assign) NSInteger indentationLevel;
@property (nonatomic, retain) UITableViewController *tableViewController;
@property (nonatomic, retain) NSIndexPath *cellIndexPath;

- (id)initWithLabel:(NSString *)newLabel atKey:(NSString *)newKey inModel:(id<IFCellModel>)newModel;

@end
