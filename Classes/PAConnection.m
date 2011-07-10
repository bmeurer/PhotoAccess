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

#import "HTTPDynamicFileResponse.h"
#import "HTTPMessage.h"

#import "PAConnection.h"
#import "PAController.h"
#import "PAPhotoResponse.h"


@implementation PAConnection


- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)URI
{
    NSObject<HTTPResponse> *response = nil;
    NSString *filePath = [self filePathForURI:URI];
    NSString *documentRoot = [config documentRoot];
    if ([filePath hasPrefix:documentRoot]) {
        PAController *controller = [PAController controller];
        NSString *path = [filePath substringFromIndex:[documentRoot length]];
        if ([path isEqualToString:@"/index.html"]) {
            NSMutableDictionary *replacementDictionary = [NSMutableDictionary dictionary];
            [replacementDictionary setObject:[NSString stringWithFormat:@"%d", [controller photoSerial]] forKey:@"SERIAL"];
            [replacementDictionary setObject:[[UIDevice currentDevice] name] forKey:@"NAME"];
            response = [[HTTPDynamicFileResponse alloc] initWithFilePath:filePath
                                                           forConnection:self
                                                               separator:@"%%"
                                                   replacementDictionary:replacementDictionary];
        }
        else if ([path hasPrefix:@"/photo-thumb-"] && [[path pathExtension] isEqualToString:@"jpg"]) {
            response = [[PAPhotoResponse alloc] initWithData:[[controller photoInfo] JPEGThumbnailData]];
        }
        else if ([path hasPrefix:@"/photo-"] && [[path pathExtension] isEqualToString:@"jpg"]) {
            response = [[PAPhotoResponse alloc] initWithData:[[controller photoInfo] JPEGData]
                                                downloadName:[[self parseGetParams] objectForKey:@"download"]];
        }
        else {
            response = [[super httpResponseForMethod:method URI:URI] retain];
        }
    }
    return [response autorelease];
}


- (NSData *)preprocessResponse:(HTTPMessage *)response
{
    // Add an ETag header with the current photoSerial
    PAController *controller = [PAController controller];
    [response setHeaderField:@"ETag" value:[NSString stringWithFormat:@"%d", [controller photoSerial]]];
    
    // Add a Server header to the response
    UIDevice *device = [UIDevice currentDevice];
    NSString *serverString = [NSString stringWithFormat:@"PhotoAccess/%@ (%@) (%@/%@)",
                              [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey],
                              [device model], [device systemName], [device systemVersion]];
    [response setHeaderField:@"Server" value:serverString];
    
    // Generate the HTTP response data
    return [super preprocessResponse:response];
}


@end

