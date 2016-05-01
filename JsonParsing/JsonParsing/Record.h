//
//  Record.h
//  JsonParsing
//
//  Created by Joy on 01/05/16.
//  Copyright © 2016 Joy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface Record : NSObject
@property (nonatomic, strong) NSString *recordTitle;
@property (nonatomic, strong) UIImage *recordImage;
@property (nonatomic, strong) NSString *recordDescription;
@property (nonatomic, strong) NSString *recordImageURLString;

@end
