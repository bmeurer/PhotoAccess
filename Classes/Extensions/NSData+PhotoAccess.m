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

#include <CommonCrypto/CommonDigest.h>

#import "NSData+PhotoAccess.h"


static const char NSDataBase64Table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";


@implementation NSData (PhotoAccess)


- (NSString *)base64Encoding;
{
    NSString *base64Encoding = nil;
	NSUInteger dataLength = [self length];
    const unsigned char *data = [self bytes];
    if (dataLength) {
        char *buffer = (char *)malloc(((dataLength + 2) / 3) * 4);
        char *bufptr = buffer;
        if (buffer) {
            while (dataLength > 2) { // keep going until we have less than 24 bits
                *bufptr++ = NSDataBase64Table[data[0] >> 2];
                *bufptr++ = NSDataBase64Table[((data[0] & 0x03) << 4) | (data[1] >> 4)];
                *bufptr++ = NSDataBase64Table[((data[1] & 0x0f) << 2) | (data[2] >> 6)];
                *bufptr++ = NSDataBase64Table[data[2] & 0x3f];
                data += 3;
                dataLength -= 3; 
            }
            if (dataLength) {
                *bufptr++ = NSDataBase64Table[data[0] >> 2];
                if (dataLength > 1) {
                    *bufptr++ = NSDataBase64Table[((data[0] & 0x03) << 4) | (data[1] >> 4)];
                    *bufptr++ = NSDataBase64Table[(data[1] & 0x0f) << 2];
                    *bufptr++ = '=';
                }
                else {
                    *bufptr++ = NSDataBase64Table[(data[0] & 0x03) << 4];
                    *bufptr++ = '=';
                    *bufptr++ = '=';
                }
            }
            *bufptr = '\0';
            base64Encoding = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
            free(buffer);
        }
    }
    else {
        base64Encoding = @"";
    }
    return base64Encoding;
}


- (NSData *)MD5Digest
{
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    return [NSData dataWithBytes:(CC_MD5([self bytes],
                                         [self length],
                                         digest))
                          length:CC_MD5_DIGEST_LENGTH];
}


@end
