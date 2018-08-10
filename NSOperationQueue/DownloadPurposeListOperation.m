//
//  DownloadPurposeListOperation.m
//  NSOperationQueue
//
//  Created by Raphael-Alexander Berendes on 8/10/18.
//  Copyright © 2018 Raphael-Alexander Berendes. All rights reserved.
//

#import "DownloadPurposeListOperation.h"

#import "DownloadVendorListOperation.h"

@interface DownloadPurposeListOperation()
// 'executing' and 'finished' exist in NSOperation, but are readonly
@property (atomic, assign) BOOL _executing;
@property (atomic, assign) BOOL _finished;
@property NSUInteger vendorListVersion;
@property NSURL* URL;
@end

@implementation DownloadPurposeListOperation

- (void) start;
{
    if ([self isCancelled])
    {
        // Move the operation to the finished state if it is canceled.
        [self willChangeValueForKey:@"isFinished"];
        self._finished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }
    
    // If the operation is not canceled, begin executing the task.
    [self willChangeValueForKey:@"isExecuting"];
    [NSThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil];
    self._executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
}

- (void) main;
{
    if ([self isCancelled]) {
        return;
    }
    DownloadVendorListOperation* downloadVendorList;
    for (NSOperation* operation in self.dependencies) {
        if ([operation isKindOfClass:[DownloadVendorListOperation class]]) {
            downloadVendorList = (DownloadVendorListOperation*)operation;
        }
    }
    self.vendorListVersion = downloadVendorList.vendorListVersion;
    if (!self.vendorListVersion || [[[NSLocale currentLocale] languageCode] isEqualToString:@"en"]) {
        [self cancel];
        return;
    }
    [self updateURL];
    [self download];
}

- (void)updateURL
{
    NSString* languageCode = [[NSLocale currentLocale] languageCode];
    self.URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://vendorlist.consensu.org/v-%lu/purposes-%@.json", self.vendorListVersion, languageCode]];
}

- (void)download
{
    NSURLRequest* req = [NSURLRequest requestWithURL:self.URL];
    NSURLSession* dlSession = NSURLSession.sharedSession;
    NSURLSessionTask* task = [dlSession dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error){
        
        if (error) {
            return;
        }
        NSError* serializationError;
        NSDictionary* purposeList = [NSJSONSerialization JSONObjectWithData:data
                                                                   options:NSJSONReadingMutableContainers
                                                                     error:&serializationError];
        if (!purposeList) {
            return;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DidDownloadPurposeList" object:nil userInfo:@{@"purposeList" : purposeList}];
        [self completeOperation];
    }];
    
    [task resume];
}

- (BOOL) isAsynchronous;
{
    return YES;
}

- (BOOL)isExecuting {
    return self._executing;
}

- (BOOL)isFinished {
    return self._finished;
}

- (void)completeOperation {
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    
    self._executing = NO;
    self._finished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

@end