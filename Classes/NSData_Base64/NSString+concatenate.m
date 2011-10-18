//
//  NSString+concatenate.m
//  FreshDocs
//
//  Created by Michael Muller on 5/11/10.
//  Copyright 2010 Michael J Muller. All rights reserved.
//  Copyright 2011 Zia Consulting, Inc.. All rights reserved.
//

#import "NSString+concatenate.h"

@implementation NSString (concatenate)

+ (NSString *)stringByAppendingString:(NSString *)string toString:(NSString *)otherString 
{
	if (!string) {
		return otherString;
	}
	else if (!otherString) {
		return string;
	}
	else {
		return [otherString stringByAppendingString:string];
	}
}

@end
