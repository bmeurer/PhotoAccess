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

#include <sys/types.h>
#include <sys/socket.h>

#include <arpa/inet.h>
#include <net/if.h>
#include <netinet/in.h>

#include <ifaddrs.h>
#include <string.h>

#import <BMKit/BMKit.h>

#import "PANetworkController.h"


@interface PANetworkController ()

- (void)PA_reload;
- (void)PA_reloadWithNetworkReachabilityFlags:(SCNetworkReachabilityFlags)flags;

@end


static BOOL PANetworkIsReachableViaWiFi(SCNetworkReachabilityFlags flags)
{
    // Target host is reachable
    if ((flags & kSCNetworkFlagsReachable) != 0) {
        if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {
            // Target host is reachable and no connection is required
            return YES;
        }
        
        if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0)
             || (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)
            && (flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {
            // Connection is on-demand/on-traffic and no user intervention is needed
            return YES;
        }
    }
    return NO;
}


static void PANetworkReachabilityControllerCallBack(SCNetworkReachabilityRef   target,
                                                    SCNetworkReachabilityFlags flags,
                                                    void                       *info)
{
    PANetworkController *networkController = info;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [networkController PA_reloadWithNetworkReachabilityFlags:flags];
    [pool release];
}


@implementation PANetworkController

@synthesize address = _address;


#pragma mark -
#pragma mark Singleton


static id PANetworkControllerSingleton = nil;


+ (PANetworkController *)networkController
{
    @synchronized(self) {
        if (!PANetworkControllerSingleton) {
            PANetworkControllerSingleton = [[self alloc] init];
        }
    }
    return PANetworkControllerSingleton;
}


+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (!PANetworkControllerSingleton) {
            PANetworkControllerSingleton = [super allocWithZone:zone];
            return PANetworkControllerSingleton;
        }
    }
    return nil;
}


- (id)retain
{
    return self;
}


- (NSUInteger)retainCount
{
    return NSUIntegerMax;
}


- (void)release
{
    
}


- (id)autorelease
{
    return self;
}


- (id)init
{
    self = [super init];
    if (self) {
        struct sockaddr_in sin;
        bzero(&sin, sizeof(sin));
        sin.sin_family = AF_INET;
        sin.sin_len = sizeof(sin);
        
        SCNetworkReachabilityRef networkReachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault,
                                                                                              (const struct sockaddr *)&sin);
        if (!networkReachability) {
            [self release];
            return nil;
        }
        
        SCNetworkReachabilityContext context = {
            .version = 0,
            .info = self,
            .retain = BMObjectRetain,
            .release = BMObjectRelease,
            .copyDescription = BMObjectCopyDescription
        };
        if (!SCNetworkReachabilitySetCallback(networkReachability,
                                              PANetworkReachabilityControllerCallBack,
                                              &context)) {
            CFRelease(networkReachability);
            [self release];
            return nil;
        }
        
        if (!SCNetworkReachabilityScheduleWithRunLoop(networkReachability,
                                                      CFRunLoopGetMain(),
                                                      kCFRunLoopCommonModes)) {
            CFRelease(networkReachability);
            [self release];
            return nil;
        }
        
        _networkReachability = networkReachability;
        
        [self performBlockOnMainThread:^(id self) {
            [self PA_reload];
        } waitUntilDone:NO];
        
        // Ensure to reload the status whenever we are about to enter foreground
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(PA_reload)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
    return self;
}


#pragma mark -
#pragma mark Key-Value Observing


+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    BOOL automaticallyNotifiesObservers;
    if ([key isEqualToString:@"address"]) {
        automaticallyNotifiesObservers = NO;
    }
    else {
        automaticallyNotifiesObservers = [super automaticallyNotifiesObserversForKey:key];
    }
    return automaticallyNotifiesObservers;
}


#pragma mark -
#pragma mark Private


- (void)PA_reload
{
    SCNetworkReachabilityFlags flags;
    if (!SCNetworkReachabilityGetFlags(_networkReachability, &flags)) {
        flags = 0;
    }
    [self PA_reloadWithNetworkReachabilityFlags:flags];
}


- (void)PA_reloadWithNetworkReachabilityFlags:(SCNetworkReachabilityFlags)flags
{
    NSString *address = nil;
    if (PANetworkIsReachableViaWiFi(flags)) {
        struct ifaddrs *ifaddrs = NULL;
        if (getifaddrs(&ifaddrs) == 0) {
            for (struct ifaddrs *ifa = ifaddrs; ifa; ifa = ifa->ifa_next) {
                if (ifa->ifa_addr->sa_family != AF_INET) {
                    // Skip non-inet ifa entries
                    continue;
                }
                if ((ifa->ifa_flags & (IFF_RUNNING | IFF_UP)) != (IFF_RUNNING | IFF_UP)) {
                    // Skip non-running/-up ifa entries
                    continue;
                }
                if ((ifa->ifa_flags & (IFF_LOOPBACK | IFF_POINTOPOINT)) != 0) {
                    // Skip loopback/p2p ifa entries
                    continue;
                }
                if (strcmp(ifa->ifa_name, "en0") == 0) {
                    // We assume that "en0" is the WiFi interface
                    char buffer[128];
                    const struct sockaddr_in *sin = (const struct sockaddr_in *)ifa->ifa_addr;
                    if (inet_ntop(sin->sin_family, &sin->sin_addr, buffer, sizeof(buffer))) {
                        address = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
                    }
                    break;
                }
            }
            freeifaddrs(ifaddrs);
        }
    }
    if (_address != address) {
        [self willChangeValueForKey:@"address"];
        [_address release], _address = [address copy];
        [self didChangeValueForKey:@"address"];
    }
}


@end
