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

#import "PAPhotoInfo.h"


static dispatch_queue_t PAPhotoInfoJPEGQueue = NULL;


@implementation PAPhotoInfo

@synthesize JPEGData = _JPEGData;
@synthesize JPEGThumbnailData = _JPEGThumbnailData;
@synthesize normalizedImage = _normalizedImage;
@synthesize previewImage = _previewImage;


+ (void)initialize
{
    if (self == [PAPhotoInfo class]) {
        // Setup the queue used to serialize the generation of JPEG data
        PAPhotoInfoJPEGQueue = dispatch_queue_create("de.benediktmeurer.PhotoAccess.PAPhotoInfoJPEGQueue", NULL);
    }
}


- (id)init
{
    return [self initWithNormalizedImage:NULL
                            previewImage:NULL];
}


- (id)initWithNormalizedImage:(CGImageRef)normalizedImage
                 previewImage:(CGImageRef)previewImage
{
    self = [super init];
    if (self) {
        // Setup the normalized and preview images
        _normalizedImage = CGImageRetain(normalizedImage);
        _previewImage = CGImageRetain(previewImage);
        if (!_normalizedImage || !_previewImage) {
            [self release];
            return nil;
        }
    }
    return self;
}


- (void)dealloc
{
    [_JPEGData release], _JPEGData = nil;
    [_JPEGThumbnailData release], _JPEGThumbnailData = nil;
    CGImageRelease(_normalizedImage), _normalizedImage = NULL;
    CGImageRelease(_previewImage), _previewImage = NULL;
    [super dealloc];
}


#pragma mark -
#pragma mark Properties


- (NSData *)JPEGData
{
    __block NSData *JPEGData = nil;
    dispatch_sync(PAPhotoInfoJPEGQueue, ^(void) {
        if (!_JPEGData) {
            // Generate the JPEG data for the normalized image
            _JPEGData = (NSData *)BMImageCopyJPEGData(_normalizedImage,
                                                      BMImageOrientationUp,
                                                      0.95f);
        }
        JPEGData = [_JPEGData copy];
    });
    return [JPEGData autorelease];
}


- (NSData *)JPEGThumbnailData
{
    __block NSData *JPEGThumbnailData = nil;
    dispatch_sync(PAPhotoInfoJPEGQueue, ^(void) {
        if (!_JPEGThumbnailData) {
            // Generate the thumbnail image to display on the web interface
            CGImageRef thumbnailImage = BMImageCreateWithImageScaledDownToAspectFill(_normalizedImage,
                                                                                     CGSizeMake((CGFloat)300.0f,
                                                                                                (CGFloat)300.0f),
                                                                                     kCGInterpolationDefault);
            
            // Generate the JPEG data for the thumbnail image
            _JPEGThumbnailData = (NSData *)BMImageCopyJPEGData(thumbnailImage,
                                                               BMImageOrientationUp,
                                                               0.85f);
            
            // Cleanup
            CGImageRelease(thumbnailImage);
        }
        JPEGThumbnailData = [_JPEGThumbnailData copy];
    });
    return [JPEGThumbnailData autorelease];
}


@end
