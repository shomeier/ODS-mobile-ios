//
//  SelectTenantViewController.h
//  FreshDocs
//
//  Created by Tijs Rademakers on 28/08/2012.
//  Copyright (c) 2012 U001b. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AccountInfo.h"

@interface SelectTenantViewController : UITableViewController

- (id)initWithStyle:(UITableViewStyle)style account:(NSString *)uuid;

@end
