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

#import "NSData+PhotoAccess.h"

#import "PAPhotoResponse.h"


@implementation PAPhotoResponse


- (id)initWithData:(NSData *)data
{
    self = [super init];
    if (self) {
        _data = [data copy];
        if (!_data) {
            [self release];
            return nil;
        }
        _offset = 0;
    }
    return self;
}


- (void)dealloc
{
    [_data release];
    [super dealloc];
}


#pragma mark -
#pragma mark HTTPResponse


- (UInt64)contentLength
{
    return [_data length];
}


- (UInt64)offset
{
    return _offset;
}


- (void)setOffset:(UInt64)offset
{
    _offset = offset;
}


- (NSData *)readDataOfLength:(NSUInteger)length
{
    NSRange range = NSMakeRange(_offset, length);
    if (range.location + range.length > [_data length]) {
        range.length = [_data length] - range.location;
    }
    _offset += range.length;
    return [_data subdataWithRange:range];
}


- (BOOL)isDone
{
    return ([self offset] >= [self contentLength]);
}


- (NSDictionary *)httpHeaders
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"no-cache", @"Cache-Control",
            @"image/jpeg", @"Content-Type",
            [[_data MD5Digest] base64Encoding], @"Content-MD5",
            @"no-cache", @"Pragma",
            nil];
}


@end
