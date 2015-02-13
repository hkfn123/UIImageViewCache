//
//  UIImageView+HPMCZZ.m
//  JiuTao
//
//  Created by zhan zhi on 2/12/15.
//  Copyright (c) 2015 weiyouren. All rights reserved.
//

#import "UIImageView+HPMCZZ.h"
#import <CommonCrypto/CommonDigest.h>
#import <sys/stat.h>
#import <dirent.h>
#import <string.h>
#import <sys/stat.h>
#import <unistd.h>




@interface UIImageView (){
@private
    NSString *_imageURL;
    NSString *_placeHolder;
}

@end




@implementation UIImageView (HPMCZZ)

- (void)setImageWithURL:(NSString*)imageURLStr withPlaceHolder:(NSString*)placeHolder{
    //1.Check whether the cache is exist
    self.image = [UIImage imageNamed:placeHolder];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *image = [self _checkImageCacheExistedWithImageURL:imageURLStr];
        if (image){
            dispatch_async(dispatch_get_main_queue(), ^{
                self.image = image;
            });
        }
       //2.Request imageData from server
        else{
            FetchImageOperation *operation = [[FetchImageOperation alloc] init];
            [operation fetchWithURLStr:imageURLStr withFetchFinishedBlock:^(NSData *data){
                //3.Cache imageData
                if (data) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.image = [UIImage imageWithData:data];
                    });
                    [self _savaImageDataToDisk:data withImageURLStr:imageURLStr];
                }
            }];
            [BaseOperation addOperationToQueue:operation];

        }
    });
}


- (void)_savaImageDataToDisk:(NSData*)data withImageURLStr:(NSString*)urlStr{
    NSString *path = [self _getCacheDataPath:urlStr];
    [data writeToFile:path atomically:YES];
}

- (UIImage*)_checkImageCacheExistedWithImageURL:(NSString*)imageURLStr{
    //check imageURLStr is valid
    if (imageURLStr == nil || imageURLStr.length == 0)
        return nil;
    
    //return image data
    NSString *path = [self _getCacheDataPath:imageURLStr];
    NSData *imageData = [NSData dataWithContentsOfFile:path];
    return [UIImage imageWithData:imageData];
}


- (NSString*)_getCacheDataPath:(NSString*)urlStr{
    NSString *fileName = [self _md5HexDigest:urlStr];
   
    NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    path = [path stringByAppendingPathComponent:@"HPMCZZCache"];
    
    BOOL isDir = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL existed = [fileManager fileExistsAtPath:path isDirectory:&isDir];
    if (!(isDir == YES && existed == YES))
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    path = [path stringByAppendingPathComponent:fileName];
    return path;
}


- (NSString*)_md5HexDigest:(NSString*)inputStr{
    const char *cStr = [inputStr UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH] = {0};
    CC_MD5(cStr, (unsigned int)strlen(cStr), result);
    NSMutableString *hash = [NSMutableString string];
    for (int i = 0 ; i < CC_MD5_DIGEST_LENGTH; i++) {
        [hash appendFormat:@"%02x",result[i]];
    }
    return [hash lowercaseString];
}



@end



@implementation BaseOperation

+ (void)addOperationToQueue:(NSOperation*)operation{
    static NSOperationQueue *_queue = nil;
    if (_queue == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            _queue = [[NSOperationQueue alloc] init];
            [_queue setMaxConcurrentOperationCount:5];
        });
    }
    [_queue addOperation:operation];
}


@end



@interface FetchImageOperation(){
    @private
    NSString *_imageURLStr;
    NSMutableData *_imageData;
    fetchImageFinishedBlock _block;
    long long _totalLen;
    long long _reciveLen;
}

@end



#define k_TIMEOUT_SEC   60.0f

@implementation FetchImageOperation


- (void)fetchWithURLStr:(NSString*)imageURStr
withFetchFinishedBlock:(fetchImageFinishedBlock)block {
    _imageURLStr = imageURStr;
    _block = block;
}

- (void)main{
    [Utils startNetworkActivityIndicator];
    
    //create the request
    NSURL *imageURL = [NSURL URLWithString:_imageURLStr];
    
    NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:imageURL
                                                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                          timeoutInterval:k_TIMEOUT_SEC];
    
    NSURLConnection *connection = [NSURLConnection connectionWithRequest:theRequest delegate:self];
    [connection start];
    if (connection)
        CFRunLoopRun();
}



#pragma mark - NSURLConnectionDelegate

- (NSURLRequest *)connection:(NSURLConnection *)connection
             willSendRequest:(NSURLRequest *)request
            redirectResponse:(NSURLResponse *)response{
    return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
    _totalLen = httpResponse.expectedContentLength > 0 ? (NSInteger)response.expectedContentLength : 0;
    _reciveLen = 0;
    if (httpResponse.statusCode != 200){
        [connection cancel];
        CFRunLoopStop(CFRunLoopGetCurrent());
        [Utils stopNetworkActivityIndicator];
    }
    return;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    if (!_imageData)
        _imageData = [NSMutableData data];
    _reciveLen += _imageData.length;
    [_imageData appendData:data];
    
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection{
    if (_block)
        _block(_imageData);
    CFRunLoopStop(CFRunLoopGetCurrent());
    [Utils stopNetworkActivityIndicator];
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error{
    _imageData = nil;
    if (_block)
        _block(_imageData);
    CFRunLoopStop(CFRunLoopGetCurrent());
    [Utils stopNetworkActivityIndicator];
}


@end


#define k_file_path_length  1024
static NSString *activityIndicatorLock = @"activityIndicatorLock";
static NSInteger activityIndicatorCount = 0;

@implementation Utils



+ (NSString*)getCachePath{
    NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    path = [path stringByAppendingPathComponent:@"HPMCZZCache"];
    return path;
}

+ (void)startNetworkActivityIndicator{
    @synchronized(activityIndicatorLock) {
        if (activityIndicatorCount == 0) {
            [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
        }
        activityIndicatorCount++;
    }
}

+ (void)stopNetworkActivityIndicator{
    @synchronized(activityIndicatorLock) {
        activityIndicatorCount--;
        if (activityIndicatorCount < 1) {
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
            activityIndicatorCount = 0;
        }
        
    }
}

long long getCacheFileSize(const char *path){
    long long fileSize = 0;
    char filepath[k_file_path_length] = {0};
    struct stat file_stat = {0};
    
    if (stat(path, &file_stat) == -1){
        perror("error:%m");
        return fileSize;
    }
    
    
    else{
        
        if(S_ISDIR(file_stat.st_mode)){
            DIR *dir;
            struct dirent *file;
            
            if (!(dir = opendir(path))) {
                printf("open dir error.\n");
                return fileSize;
            }
            
            while ((file = readdir(dir)) != NULL) {
                memset(filepath, 0, k_file_path_length);
                if (strcmp(file->d_name,".") == 0 ||
                    strcmp(file->d_name,"..") == 0)
                    continue;
                sprintf(filepath,"%s/%s",path,file->d_name);
                fileSize += getCacheFileSize(filepath);
            }
        }
        
        else if (S_ISREG(file_stat.st_mode)){
            fileSize += file_stat.st_size;
        }
    }
    
    return fileSize;
}

bool deleteFileAtPath(const char *path){
    char filepath[k_file_path_length] = {0};
    struct stat file_stat = {0};
    
    if (stat(path, &file_stat) == -1){
        perror("error:%m");
        return false;
    }
    
    
    else{
        
        if(S_ISDIR(file_stat.st_mode)){
            DIR *dir;
            struct dirent *file;
            
            if (!(dir = opendir(path))) {
                printf("open dir error.\n");
                return false;
            }
            
            while ((file = readdir(dir)) != NULL) {
                memset(filepath, 0, k_file_path_length);
                if (strcmp(file->d_name,".") == 0 ||
                    strcmp(file->d_name,"..") == 0)
                    continue;
                sprintf(filepath,"%s/%s",path,file->d_name);
                deleteFileAtPath(filepath);
            }
            rmdir(path);
        }
        
        else if (S_ISREG(file_stat.st_mode)){
            remove(path);
        }
    }
    return true;
}

@end

