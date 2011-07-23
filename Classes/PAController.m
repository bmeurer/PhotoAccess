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

#import <BMKit/BMKit.h>

#import "DDTTYLogger.h"
#import "PAConnection.h"
#import "PAController.h"


@interface PAController ()

@property (nonatomic, readonly, retain) HTTPServer *httpServer;

@end


@implementation PAController

@synthesize error = _error;
@synthesize photoInfo = _photoInfo;
@synthesize photoSerial = _photoSerial;
@synthesize state = _state;
@synthesize window = _window;


#pragma mark -
#pragma mark PAController singleton


static id PAControllerSingleton = nil;


+ (PAController *)controller
{
    @synchronized(self) {
        if (!PAControllerSingleton) {
            PAControllerSingleton = [[self alloc] init];
        }
    }
    return PAControllerSingleton;
}


+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (!PAControllerSingleton) {
            PAControllerSingleton = [super allocWithZone:zone];
            return PAControllerSingleton;
        }
    }
    return nil;
}


- (id)init
{
    self = [super init];
    if (self) {
        _networkController = [[PANetworkController alloc] init];
        if (!_networkController) {
            [self release];
            return nil;
        }
        [_networkController addObserver:self
                             forKeyPath:@"address"
                                options:(NSKeyValueObservingOptionNew
                                         | NSKeyValueObservingOptionOld)
                                context:NULL];
        if (!_networkController.address) {
            _state = PAControllerStateNoNetwork;
        }
    }
    return self;
}


- (void)dealloc
{
    [_networkController removeObserver:self forKeyPath:@"address"], [_networkController release], _networkController = nil;
    [super dealloc];
}


- (id)retain
{
    return self;
}


- (NSUInteger)retainCount
{
    return NSUIntegerMax;
}


- (oneway void)release
{
}


- (id)autorelease
{
    return self;
}


#pragma mark -
#pragma mark Key-Value Observing


+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    BOOL automaticallyNotifiesObservers;
    if ([key isEqualToString:@"photoInfo"] || [key isEqualToString:@"serverURL"] || [key isEqualToString:@"state"]) {
        automaticallyNotifiesObservers = NO;
    }
    else {
        automaticallyNotifiesObservers = [super automaticallyNotifiesObserversForKey:key];
    }
    return automaticallyNotifiesObservers;
}


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (object == _networkController && [keyPath isEqualToString:@"address"]) {
        NSString *address = [_networkController address];
        if (_state == PAControllerStateNoNetwork && address && _photoInfo) {
            [self willChangeValueForKey:@"state"];
            [_error release], _error = nil;
            if ([self.httpServer start:&_error]) {
                _state = PAControllerStateServing;
            }
            else {
                _state = PAControllerStateError;
            }
            [self didChangeValueForKey:@"state"];
        }
        else if (_state == PAControllerStateNoNetwork && address && !_photoInfo) {
            [self willChangeValueForKey:@"state"];
            _state = PAControllerStateIdle;
            [self didChangeValueForKey:@"state"];
        }
        else if (_state != PAControllerStateNoNetwork && !address) {
            [self willChangeValueForKey:@"state"];
            [_error release], _error = nil;
            [self.httpServer stop];
            _state = PAControllerStateNoNetwork;
            [self didChangeValueForKey:@"state"];
        }

        // Trigger a change notification on the serverURL
        [self performBlockOnMainThread:^(id self) {
            [self willChangeValueForKey:@"serverURL"];
            [self didChangeValueForKey:@"serverURL"];
        } waitUntilDone:NO];
    }
}


#pragma mark -
#pragma mark Properties


- (HTTPServer *)httpServer
{
    @synchronized(self) {
        if (!_httpServer) {
            // Allocate the HTTPServer
            _httpServer = [[HTTPServer alloc] init];
            [_httpServer setConnectionClass:[PAConnection class]];
            [_httpServer setDocumentRoot:[[NSBundle mainBundle] pathForResource:@"Web" ofType:nil]];
            [_httpServer setPort:8080];
            [_httpServer setType:@"_http._tcp."];
        }
        return [[_httpServer retain] autorelease];
    }
}


- (PAPhotoInfo *)photoInfo
{
    __block PAPhotoInfo *photoInfo = nil;
    [self performBlockOnMainThread:^(id aTarget) {
        photoInfo = [_photoInfo retain];
    } waitUntilDone:YES];
    return [photoInfo autorelease];
}


- (void)setPhotoInfo:(PAPhotoInfo *)photoInfo
{
    [self performBlockOnMainThread:^(id aTarget) {
        if (_photoInfo != photoInfo) {
            // Increment photoSerial
            _photoSerial++;
            
            [self willChangeValueForKey:@"photoInfo"];
            [_photoInfo release], _photoInfo = [photoInfo retain];
            [self didChangeValueForKey:@"photoInfo"];
            
            if (_state != PAControllerStateIdle && _state != PAControllerStateNoNetwork && !_photoInfo) {
                [self willChangeValueForKey:@"state"];
                [_error release], _error = nil;
                [self.httpServer stop:NO];
                _state = PAControllerStateIdle;
                [self didChangeValueForKey:@"state"];
            }
            else if (_state != PAControllerStateServing && _state != PAControllerStateNoNetwork && _photoInfo) {
                [self willChangeValueForKey:@"state"];
                [_error release], _error = nil;
                if ([self.httpServer start:&_error]) {
                    _state = PAControllerStateServing;
                    
                    // Trigger a change notification on the serverURL (web server was started)
                    [self performBlockOnMainThread:^(id self) {
                        [self willChangeValueForKey:@"serverURL"];
                        [self didChangeValueForKey:@"serverURL"];
                    } waitUntilDone:NO];
                }
                else {
                    _state = PAControllerStateError;
                }
                [self didChangeValueForKey:@"state"];
            }
        }
    } waitUntilDone:YES];
}


- (NSString *)serverURL
{
    NSString *serverURL = nil;
    NSString *host = [_networkController address];
    unsigned port = [_httpServer listeningPort];
    if (host && port) {
        serverURL = [NSString stringWithFormat:@"http://%@:%d", host, port];
    }
    return serverURL;
}


#pragma mark -
#pragma mark UIApplicationDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Configure the CocoaLumberjack logging framework.
    // For now, just log everything to the Xcode console.
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    
    [self.window makeKeyAndVisible];
    return YES;
}


@end

