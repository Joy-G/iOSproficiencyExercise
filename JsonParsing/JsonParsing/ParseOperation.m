//
//  ParseOperation.m
//  JsonParsing
//
//  Created by Joy on 01/05/16.
//  Copyright © 2016 Joy. All rights reserved.
//

#import "ParseOperation.h"
#import "Record.h"

// keys found in the json feed
static NSString *kDescription     = @"description";
static NSString *kImageURL   = @"imageHref";
static NSString *kTitle  = @"title";
static NSString *kRows = @"rows";



@interface ParseOperation ()

// Redeclare recordList & feedTitle so we can modify it within this class
@property (nonatomic, strong) NSArray *recordList;
@property (nonatomic, strong) NSString *feedTitle;
@property (nonatomic, strong) NSData *dataToParse;
@property (nonatomic, strong) NSMutableArray *workingArray;
@property (nonatomic, strong) Record *workingEntry;  // the current records is being parsed

@end


@implementation ParseOperation

//	initWithData:
- (instancetype)initWithData:(NSData *)data
{
    self = [super init];
    if (self != nil)
    {
        _dataToParse = data;
    }
    return self;
}

- (void)main {
    
     _workingArray = [NSMutableArray array];
    
    NSError *parseError = nil;
    
    NSString *strData = [[NSString alloc] initWithData:_dataToParse encoding:NSISOLatin1StringEncoding];
    
    NSData *dataWithUtf8 = [strData dataUsingEncoding:NSUTF8StringEncoding];
    
    NSDictionary *jsonResponse = [NSJSONSerialization
                                    JSONObjectWithData:dataWithUtf8 options:NSJSONReadingMutableContainers error:&parseError];
    
    if (parseError == nil) {
        
            if ([jsonResponse objectForKey:kTitle]) {
                _feedTitle = [jsonResponse objectForKey:kTitle];
            }
            // Populating the resultset
            if ([jsonResponse objectForKey:kRows]) {
                
                NSArray *arrRecords = [jsonResponse objectForKey:kRows];
                
                for (NSDictionary *dict in arrRecords) {
                    _workingEntry = [[Record alloc] init];
                    if ([[dict objectForKey:kTitle] isKindOfClass:[NSNull class]] && [[dict objectForKey:kDescription] isKindOfClass:[NSNull class]]) {
                        _workingEntry.recordTitle = @"No Title available";
                        _workingEntry.recordDescription = @"No Description available";
                    }
                    else {
                        _workingEntry.recordTitle = [dict objectForKey:kTitle];
                        _workingEntry.recordDescription = [dict objectForKey:kDescription];
                    }
                    
                    _workingEntry.recordImage = nil;
                    _workingEntry.recordImageURLString = [dict objectForKey:kImageURL];
                    [self.workingArray addObject:_workingEntry];
                    
                    NSLog(@"Record Title: %@\n Record Description: %@", _workingEntry.recordTitle, _workingEntry.recordDescription);
                }
            }
 
    }
    else {
        if (self.errorHandler)
        {
            self.errorHandler(parseError);
        }
    }
    
    if (![self isCancelled])
    {
        // Set appRecordList to the result of our parsing
        self.recordList = [NSArray arrayWithArray:self.workingArray];
    }
    
    self.workingArray = nil;
    self.dataToParse = nil;
}
@end
