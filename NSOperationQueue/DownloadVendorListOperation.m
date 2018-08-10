//
//  DownloadVendorListOperation.m
//  NSOperationQueue
//
//  Created by Raphael-Alexander Berendes on 8/10/18.
//  Copyright © 2018 Raphael-Alexander Berendes. All rights reserved.
//

#import "DownloadVendorListOperation.h"

@interface DownloadVendorListOperation()
// 'executing' and 'finished' exist in NSOperation, but are readonly
@property (atomic, assign) BOOL _executing;
@property (atomic, assign) BOOL _finished;
@end

@implementation DownloadVendorListOperation

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
    [self download];
}

- (void)download
{
    NSURL* URL = [NSURL URLWithString:@"https://vendorlist.consensu.org/vendorlist.json"];
    NSURLRequest* req = [NSURLRequest requestWithURL:URL];
    NSURLSession* dlSession = NSURLSession.sharedSession;
    NSURLSessionTask* task = [dlSession dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error){
        
        if (error) {
            return;
        }
        NSError* serializationError;
        NSDictionary* vendorList = [NSJSONSerialization JSONObjectWithData:data
                                                                   options:NSJSONReadingMutableContainers
                                                                     error:&serializationError];
        if (!vendorList) {
            return;
        }
        
        self.vendorListVersion = [self vendorListVersion:vendorList];
        [self completeOperation];
    }];
    
    [task resume];
}

- (NSUInteger)vendorListVersion:(nonnull NSDictionary*)vendorList
{
    NSUInteger vendorListVersion = [[vendorList objectForKey:@"vendorListVersion"] intValue];
    return vendorListVersion;
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