//
//  FolderTableViewDataSource.m
//  FreshDocs
//
//  Created by Gi Hyun Lee on 11/9/10.
//  Copyright 2010 Zia Consulting. All rights reserved.
//

#import "FolderTableViewDataSource.h"
#import "Utility.h"
#import "SavedDocument.h"

@interface FolderTableViewDataSource ()
@property (nonatomic, readwrite, retain) NSURL *folderURL;
@property (nonatomic, readwrite, retain) NSString *folderTitle;
@property (nonatomic, readwrite, retain) NSMutableArray *children;
@end



@implementation FolderTableViewDataSource
@synthesize folderURL;
@synthesize folderTitle;
@synthesize children;

#pragma mark Memory Management
- (void)dealloc
{
	[folderURL release];
	[folderTitle release];
	[children release];
	[super dealloc];
}

#pragma mark Initialization
- (id)initWithURL:(NSURL *)url
{
	if ((self = [super init])) {
		[self setFolderURL:url];
		[self setChildren:[NSMutableArray array]];
		[self refreshData];	
		
		// TODO: Check to make sure provided URL exists if local file system
	}
	return self;
}

#pragma mark -
#pragma mark UITableViewDataSource
/*
 – sectionIndexTitlesForTableView:
 – tableView:sectionForSectionIndexTitle:atIndex:
 – tableView:titleForHeaderInSection:
 – tableView:titleForFooterInSection:
 */

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"folderChildTableCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (nil == cell) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
		[[cell textLabel] setFont:[UIFont boldSystemFontOfSize:17.0f]];
		[[cell detailTextLabel] setFont:[UIFont italicSystemFontOfSize:14.0f]];
	}
	
	NSString *title = @"";
	NSString *details = @"";
	UIImage *iconImage = nil;
	
	if ([[self folderURL] isFileURL]) {
		NSError *error;
		NSString *fileURLString = [(NSURL *)[self.children objectAtIndex:indexPath.row] path];
		NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fileURLString error:&error];
		long fileSize = [[fileAttributes objectForKey:NSFileSize] longValue];
		
		// !!!: Check if we got an error and handle gracefully
		
		title = [fileURLString lastPathComponent];
		details = [SavedDocument stringForLongFileSize:fileSize];
		iconImage = imageForFilename(title);
		
		[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	}
	else {
		// FIXME: implement when going over the network
	}
	
	[[cell textLabel] setText:title];
	[[cell detailTextLabel] setText:details];
    
    if (iconImage)
        [[cell imageView] setImage:iconImage];
	
	return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [children count]; /// TODO: Dont forget me if sectioned
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1; // TODO: more sections?
}


#pragma mark -
#pragma mark Instance Methods
- (void)refreshData
{
	[[self children] removeAllObjects];
	
	if ([[self folderURL] isFileURL]) {
		
		[self setFolderTitle:[[self.folderURL path] lastPathComponent]];
		
		// !!!: Need to program defensively and check for an error ...
		NSArray *folderContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[self folderURL] path] 
																					  error:NULL];
		
		for (NSString* fileName in [folderContents objectEnumerator])
		{
			NSString *filePath = [[self.folderURL path] stringByAppendingPathComponent:fileName];
			NSURL *fileURL = [NSURL fileURLWithPath:filePath];
			
			BOOL isDirectory;
			[[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory];
			
			// only add files, no directories nor the Inbox
			if (!(isDirectory && [fileName isEqualToString: @"Inbox"]))
				[self.children addObject:fileURL];
		}	
	}
	else {
		//	FIXME: implement me
	}
}

- (id)cellDataObjectForIndexPath:(NSIndexPath *)indexPath
{
	return [[self children] objectAtIndex:[indexPath row]];
}

@end
