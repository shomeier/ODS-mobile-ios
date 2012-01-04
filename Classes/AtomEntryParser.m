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
//  AtomEntryParser.m
//

#import "AtomEntryParser.h"
#import "CmisProperty.h"


@interface AtomEntryParser ()
- (void)startStoringCharacters;
- (void)stopStoringCharacters;
@end


@implementation AtomEntryParser
@synthesize currentEntry;
@synthesize currentString;

#pragma mark -
#pragma Memory Management

- (void)dealloc
{
    [currentEntry release];
    [currentString release];
    
    [super dealloc];
}


#pragma Initializers

- (id)initWithEntry:(Entry *)entry
{
    NSAssert(entry != nil, @"entry object cannot be nil", nil);
    self = [super init];
    if (self) {
        
        [self setCurrentEntry:entry];
        [self setCurrentString:[NSMutableString string]];
    }
    
    return self;
}


#pragma mark -
#pragma mark NSXMLParserDelegate Methods

static NSString *kCMISCore_Namespace = @"http://docs.oasis-open.org/ns/cmis/core/200908";
static NSString *kCMISRestAtom_Namespace = @"http://docs.oasis-open.org/ns/cmis/restatom/200908";
static NSString *kAtom_Namespace = @"http://www.w3.org/2005/Atom";
static NSString *kAtomPub_Namespace = @"http://www.w3.org/2007/app";

static NSString *kEntry_Element = @"entry";
static NSString *kId_Element = @"id";
static NSString *kTitle_Element = @"title";
static NSString *kLink_Element = @"link";
static NSString *kRel_Item = @"rel";
static NSString *kHref_Item = @"href";
static NSString *kType_Item = @"type";
static NSString *kProperties_Element = @"properties";
static NSUInteger kPropertyLength = 8;
static NSString *kProperty_ElementPrefix = @"property";
static NSString *kContent_Element = @"content";
static NSString *kSrc_Item = @"src";


- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    if ([namespaceURI hasPrefix:kAtom_Namespace]) {
        if ([elementName isEqualToString:kId_Element] || [elementName isEqualToString:kTitle_Element]) {
            [self startStoringCharacters];
        }
        else if ([elementName isEqualToString:kLink_Element]) {
            [[currentEntry linkRelations] addObject:attributeDict];
        }
        else if ([elementName isEqualToString:kContent_Element]) {
            [currentEntry setContentURL:[NSURL URLWithString:[attributeDict objectForKey:kSrc_Item]]];
            [currentEntry setContentType:[attributeDict objectForKey:kType_Item]];
        }
    }
    else if ([namespaceURI hasPrefix:kCMISCore_Namespace]) {
        
        if ([elementName isEqualToString:kProperties_Element]) {
            parsingCmisObjectProperties = YES;
        }
        else if (parsingCmisObjectProperties && [elementName hasPrefix:kProperty_ElementPrefix]) {
            NSString *type = [elementName substringFromIndex:kPropertyLength];
            CmisProperty *cmisProp = [[CmisProperty alloc] initWithType:type usingXmlAttributeDictionary:attributeDict];
            [[currentEntry cmisProperties] addObject:cmisProp];
            [cmisProp release];
            
            [self startStoringCharacters];
        }
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([namespaceURI hasPrefix:kAtom_Namespace]) {
        
        if ([elementName isEqualToString:kId_Element]) {
            NSString *value = [[NSString alloc] initWithString:currentString];
            [currentEntry setAtomId:value];
            [value release];
        }
        if ([elementName isEqualToString:kTitle_Element]) {
            NSString *value = [[NSString alloc] initWithString:currentString];
            [currentEntry setAtomTitle:value];
            [value release];
        }
    }
    else if ([namespaceURI hasPrefix:kCMISCore_Namespace]) {
        
        if ([elementName isEqualToString:kProperties_Element]) {
            parsingCmisObjectProperties = NO;
        }
        else if (parsingCmisObjectProperties && [elementName hasPrefix:kProperty_ElementPrefix]) {
            CmisProperty *cmisProp = [[currentEntry cmisProperties] lastObject];
            [cmisProp setCmisValue:[currentString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        }
    }
    
    [self stopStoringCharacters];
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    if (storingCharacters) [currentString appendString:string];
}


#pragma mark -
#pragma mark Helper methods

- (void)startStoringCharacters 
{
    [currentString setString:@""];
    storingCharacters = YES;
}

- (void)stopStoringCharacters 
{
    storingCharacters = NO;
}


@end
