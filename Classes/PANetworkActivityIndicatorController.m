/*-
 * Copyright (c) 2011, Benedikt Meurer <benedikt.meurer@googlemail.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#import <UIKit/UIKit.h>

#import "PANetworkActivityIndicatorController.h"


@implementation PANetworkActivityIndicatorController


static id PANetworkActivityIndicatorControllerSingleton = nil;
static NSUInteger PANetworkActivityIndicatorControllerReferences = 0;
static dispatch_queue_t PANetworkActivityIndicatorControllerQueue = NULL;


+ (void)load
{
    if (self == [PANetworkActivityIndicatorController class]) {
        PANetworkActivityIndicatorControllerQueue = dispatch_queue_create("de.benediktmeurer.PANetworkActivityIndicatorController", NULL);
    }
}


+ (PANetworkActivityIndicatorController *)networkActivityIndicatorController
{
    @synchronized(self) {
        if (!PANetworkActivityIndicatorControllerSingleton) {
            PANetworkActivityIndicatorControllerSingleton = [[self alloc] init];
        }
    }
    return PANetworkActivityIndicatorControllerSingleton;
}


+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (!PANetworkActivityIndicatorControllerSingleton) {
            PANetworkActivityIndicatorControllerSingleton = [super allocWithZone:zone];
            return PANetworkActivityIndicatorControllerSingleton;
        }
    }
    return nil;
}


- (id)retain
{
    dispatch_async(PANetworkActivityIndicatorControllerQueue, ^(void) {
        if (++PANetworkActivityIndicatorControllerReferences == 1) {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            });
        }
    });
    return self;
}


- (NSUInteger)retainCount
{
    return NSUIntegerMax;
}


- (oneway void)release
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0f * NSEC_PER_SEC), PANetworkActivityIndicatorControllerQueue, ^(void) {
        if (--PANetworkActivityIndicatorControllerReferences == 0) {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
            });
        }
    });
}


- (id)autorelease
{
    [self release];
    return self;
}


@end
