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

#import "NSObject+PhotoAccess.h"
#import "UIImage+Resize.h"

#import "DDTTYLogger.h"
#import "PAConnection.h"
#import "PAController.h"


@interface PAController ()

@property (readonly, retain) HTTPServer *httpServer;

@end


@implementation PAController

@synthesize error = _error;
@synthesize image = _image;
@synthesize photoData = _photoData;
@synthesize photoThumbnailData = _photoThumbnailData;
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


#pragma mark -
#pragma mark Key-Value Observing


+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    BOOL automaticallyNotifiesObservers;
    if ([key isEqualToString:@"image"] || [key isEqualToString:@"state"]) {
        automaticallyNotifiesObservers = NO;
    }
    else {
        automaticallyNotifiesObservers = [super automaticallyNotifiesObserversForKey:key];
    }
    return automaticallyNotifiesObservers;
}


#pragma mark -
#pragma mark Properties


- (HTTPServer *)httpServer
{
    @synchronized(self) {
        if (!_httpServer) {
            _httpServer = [[HTTPServer alloc] init];
            [_httpServer setConnectionClass:[PAConnection class]];
            [_httpServer setDocumentRoot:[[NSBundle mainBundle] pathForResource:@"Web" ofType:nil]];
            [_httpServer setPort:8080];
            [_httpServer setType:@"_http._tcp."];
        }
        return [[_httpServer retain] autorelease];
    }
}


- (void)setImage:(UIImage *)image
{
    if (_image != image) {
        [_photoData release], _photoData = nil;
        [_photoThumbnailData release], _photoThumbnailData = nil;
        
        [self willChangeValueForKey:@"image"];
        [_image release], _image = [image retain];
        [self didChangeValueForKey:@"image"];
        
        if (_state != PAControllerStateIdle && !_image) {
            [self willChangeValueForKey:@"state"];
            [_error release], _error = nil;
            [self.httpServer stop:NO];
            _state = PAControllerStateIdle;
            [self didChangeValueForKey:@"state"];
        }
        else if (_state != PAControllerStateServing && _image) {
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
    }
}


- (NSData *)photoData
{
    __block NSData *photoData = nil;
    [self performBlockOnMainThread:^() {
        if (!_photoData && _image) {
            _photoData = [UIImageJPEGRepresentation(_image, (CGFloat)1.0f) copy];
        }
        photoData = [_photoData copy];
    } waitUntilDone:YES];
    return [photoData autorelease];
}


- (NSData *)photoThumbnailData
{
    __block NSData *photoThumbnailData = nil;
    [self performBlockOnMainThread:^() {
        if (!_photoThumbnailData && _image) {
            UIImage *imageThumbnail = [_image thumbnailImage:260
                                           transparentBorder:0
                                                cornerRadius:0
                                        interpolationQuality:kCGInterpolationHigh];
            _photoThumbnailData = [UIImageJPEGRepresentation(imageThumbnail, (CGFloat)1.0f) copy];
        }
        photoThumbnailData = [_photoThumbnailData copy];
    } waitUntilDone:YES];
    return [photoThumbnailData autorelease];
}


- (NSURL *)serverURL
{
    NSURL *serverURL = nil;
    if (self.state == PAControllerStateServing) {
        // TODO
        NSString *host = [self.httpServer publishedName];
        if (host) {
            unsigned port = [self.httpServer listeningPort];
            if (port) {
                serverURL = [[[NSURL alloc] initWithString:[NSString stringWithFormat:@"http://%@:%d", host, port]] autorelease];
            }
        }
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


- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    // Free the JPEG photo data, will be regenerated on-demand
    [_photoData release], _photoData = nil;
    [_photoThumbnailData release], _photoThumbnailData = nil;
}


@end

