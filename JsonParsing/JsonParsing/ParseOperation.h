//
//  ParseOperation.h
//  JsonParsing
//
//  Created by Joy on 01/05/16.
//  Copyright © 2016 Joy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ParseOperation : NSOperation

// A block to call when an error is encountered during parsing.
@property (nonatomic, copy) void (^errorHandler)(NSError *error);

// NSArray containing Record instances for each entry parsed
@property (nonatomic, strong, readonly) NSArray *recordList;
@property (nonatomic, strong, readonly) NSString *feedTitle;

// The initializer for this NSOperation subclass.
- (instancetype)initWithData:(NSData *)data;
@end
