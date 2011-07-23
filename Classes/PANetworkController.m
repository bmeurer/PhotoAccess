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


@implementation PANetworkController

@synthesize address = _address;


- (id)init
{
    self = [super init];
    if (self) {
        struct sockaddr_in sin;
        bzero(&sin, sizeof(sin));
        sin.sin_family = AF_INET;
        sin.sin_len = sizeof(sin);
        
        _networkReachabilityController = [[BMNetworkReachabilityController alloc] init];
        _networkReachabilityController.delegate = self;
        if (![_networkReachabilityController addReachabilityWithAddress:(const struct sockaddr *)&sin]) {
            [self release];
            return nil;
        }

        // Ensure to reload the status whenever we are about to enter foreground
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(PA_reload)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
    return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_address release], _address = nil;
    [_networkReachabilityController setDelegate:nil], [_networkReachabilityController release], _networkReachabilityController = nil;
    [super dealloc];
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
    [self networkReachabilityController:_networkReachabilityController
                  didChangeReachability:(SCNetworkReachabilityRef)[[_networkReachabilityController reachabilities] lastObject]
                                  flags:[_networkReachabilityController flags]];
}


#pragma mark -
#pragma mark BMNetworkReachabilityControllerDelegate methods


- (void)networkReachabilityController:(BMNetworkReachabilityController *)networkReachabilityController
                didChangeReachability:(SCNetworkReachabilityRef)reachability
                                flags:(SCNetworkReachabilityFlags)flags
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
