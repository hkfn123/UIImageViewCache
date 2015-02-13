//
//  UIImageView+HPMCZZ.h
//  JiuTao
//
//  Created by zhan zhi on 2/12/15.
//  Copyright (c) 2015 weiyouren. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImageView (HPMCZZ)

- (void)setImageWithURL:(NSString*)imageURLStr withPlaceHolder:(NSString*)placeHolder;

@end


@interface BaseOperation : NSOperation

+ (void)addOperationToQueue:(NSOperation*)operation;

@end

typedef void(^fetchImageFinishedBlock)(NSData*);

@interface FetchImageOperation : BaseOperation

- (void)fetchWithURLStr:(NSString*)imageURStr
 withFetchFinishedBlock:(fetchImageFinishedBlock)block;

@end


@interface Utils : NSObject

+ (NSString*)getCachePath;

long long getCacheFileSize(const char *path);

bool deleteFileAtPath(const char *path);

+ (void)startNetworkActivityIndicator;

+ (void)stopNetworkActivityIndicator;



@end