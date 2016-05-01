//
//  ImageDownloader.m
//  JsonParsing
//
//  Created by Joy on 01/05/16.
//  Copyright © 2016 Joy. All rights reserved.
//

#import "ImageDownloader.h"
#define kAppIconSize 48

@interface ImageDownloader ()

@property (nonatomic, strong) NSURLSessionDataTask *sessionTask;

@end


@implementation ImageDownloader

//	startDownload

- (void)startDownload
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:self.record.recordImageURLString]];
    
    // create an session data task to obtain and download the image for record
    _sessionTask = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                   completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                       
                                                       if (error != nil)
                                                       {
                                                           if ([error code] == NSURLErrorAppTransportSecurityRequiresSecureConnection)
                                                           {
                                                               NSLog(@"App Transport Security Error");
                                                           }
                                                       }
                                                       
                                                       [[NSOperationQueue mainQueue] addOperationWithBlock: ^{
                                                           
                                                           // Set appIcon and clear temporary data/image
                                                           UIImage *image = [[UIImage alloc] initWithData:data];
                                                           if (image.size.width != kAppIconSize || image.size.height != kAppIconSize)
                                                           {
                                                               CGSize itemSize = CGSizeMake(kAppIconSize, kAppIconSize);
                                                               UIGraphicsBeginImageContextWithOptions(itemSize, NO, 0.0f);
                                                               CGRect imageRect = CGRectMake(0.0, 0.0, itemSize.width, itemSize.height);
                                                               [image drawInRect:imageRect];
                                                               self.record.recordImage = UIGraphicsGetImageFromCurrentImageContext();
                                                               UIGraphicsEndImageContext();
                                                           }
                                                           else
                                                           {
                                                               self.record.recordImage = image;
                                                           }
                                                                                                                     
                                                           // call our completion handler to tell our client that our icon is ready for display
                                                           if (self.completionHandler != nil)
                                                           {
                                                               self.completionHandler();
                                                           }
                                                       }];
                                                   }];
    
    [self.sessionTask resume];
}

//	cancelDownload
- (void)cancelDownload
{
    [self.sessionTask cancel];
    _sessionTask = nil;
}


@end
