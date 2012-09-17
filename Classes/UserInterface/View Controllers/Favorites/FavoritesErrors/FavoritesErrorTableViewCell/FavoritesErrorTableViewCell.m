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
//  FavoritesErrorTableViewCell.m
//

#import "FavoritesErrorTableViewCell.h"

@implementation FavoritesErrorTableViewCell

@synthesize fileNameTextLabel;
@synthesize syncButton;
@synthesize saveButton;
@synthesize delegate;
@synthesize imageView;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)dealloc
{
    [self.fileNameTextLabel release];
    [self.syncButton release];
    [self.saveButton release];
    [self.imageView release];
    [super dealloc];
}

#pragma mark - Class Functions

- (IBAction)pressedSyncButton:(id)sender;
{
    [self.delegate didPressSyncButton:(UIButton *)sender];
}

- (IBAction)pressedSaveToDownloads:(id)sender
{
    [self.delegate didPressSaveToDownloadsButton:(UIButton *)sender];
}

@end
