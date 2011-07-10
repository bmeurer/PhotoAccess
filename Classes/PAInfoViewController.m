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

#import "PANetworkController.h"
#import "PAInfoViewController.h"


@implementation PAInfoViewController

@synthesize delegate = _delegate;
@synthesize doneButtonItem = _doneButtonItem;
@synthesize addressLabel = _addressLabel;


- (void)dealloc
{
    self.doneButtonItem = nil;
    self.addressLabel = nil;
    [_networkController removeObserver:self forKeyPath:@"address"];
    [_networkController release];
    [super dealloc];
}


#pragma mark -
#pragma mark Key-Value Observing


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (object == _networkController && [keyPath isEqualToString:@"address"]) {
        NSString *address = [_networkController address] ?: @"111.222.333.123";
        self.addressLabel.text = [NSString stringWithFormat:@"http://%@:8080", address];
    }
}


#pragma mark -
#pragma mark Actions


- (IBAction)doneButtonItemDidActivate:(UIBarButtonItem *)doneButtonItem
{
    [self.delegate infoViewControllerDidFinish:self];
}


#pragma mark -
#pragma mark UIViewController


- (void)viewDidLoad
{
    [super viewDidLoad];

    _networkController = [[PANetworkController networkController] retain];
    [_networkController addObserver:self
                         forKeyPath:@"address"
                            options:NSKeyValueObservingOptionNew
                            context:NULL];
    [self observeValueForKeyPath:@"address"
                        ofObject:_networkController
                          change:nil
                         context:NULL];
}


- (void)viewDidUnload
{
    [super viewDidUnload];
    self.doneButtonItem = nil;
    self.addressLabel = nil;
    [_networkController removeObserver:self forKeyPath:@"address"];
    [_networkController release];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return UIInterfaceOrientationIsPortrait(interfaceOrientation);
}


@end
