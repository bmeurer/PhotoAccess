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
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>

#import "PAController.h"
#import "PARootViewController.h"


@implementation PARootViewController

@synthesize controller = _controller;
@synthesize imageContainerView = _imageContainerView;
@synthesize imageView = _imageView;
@synthesize imageActivityIndicatorView = _imageActivityIndicatorView;
@synthesize stateContainerView = _stateContainerView;
@synthesize stateLabel = _stateLabel;
@synthesize photoLibraryButtonItem = _photoLibraryButtonItem;
@synthesize cameraButtonItem = _cameraButtonItem;
@synthesize infoButtonItem = _infoButtonItem;


- (void)dealloc
{
    self.controller = nil;
    self.imageContainerView = nil;
    self.imageView = nil;
    self.imageActivityIndicatorView = nil;
    self.stateContainerView = nil;
    self.stateLabel = nil;
    self.photoLibraryButtonItem = nil;
    self.cameraButtonItem = nil;
    self.infoButtonItem = nil;
    [super dealloc];
}


#pragma mark -
#pragma mark Key-Value Observing


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (object == self.controller && [keyPath isEqualToString:@"photoInfo"]) {
        // Load the new photo info and setup the image view
        PAPhotoInfo *photoInfo = self.controller.photoInfo;
        if (photoInfo.previewImage) {
            self.imageView.image = [UIImage imageWithCGImage:photoInfo.previewImage
                                                       scale:self.imageView.contentScaleFactor
                                                 orientation:UIImageOrientationUp];
        }
        else {
            self.imageView.image = nil;
        }
        // Fade in imageView, fade/zoom out imageActivityIndicatorView
        if ([self.imageView isHidden] && [self.imageActivityIndicatorView isAnimating]) {
            self.imageView.alpha = (CGFloat)0.0f;
            self.imageView.hidden = NO;
            [UIView animateWithDuration:0.5 animations:^(void) {
                self.imageView.alpha = (CGFloat)1.0f;
                self.imageActivityIndicatorView.alpha = (CGFloat)0.0f;
                self.imageActivityIndicatorView.transform = CGAffineTransformMakeScale((CGFloat)1.5f, (CGFloat)1.5f);
            } completion:^(BOOL finished) {
                [self.imageActivityIndicatorView stopAnimating];
                self.imageActivityIndicatorView.alpha = (CGFloat)1.0f;
                self.imageActivityIndicatorView.transform = CGAffineTransformIdentity;
            }];
        }
        else if ([self.imageActivityIndicatorView isAnimating]) {
            [self.imageActivityIndicatorView stopAnimating];
        }
        else {
            self.imageView.hidden = NO;
        }
    }
    else if (object == self.controller && [keyPath isEqualToString:@"state"]) {
        // TODO
        switch (self.controller.state) {
            case PAControllerStateIdle:
                self.stateLabel.text = @"IDLE";
                break;
                
            case PAControllerStateNoNetwork:
                self.stateLabel.text = @"NO NETWORK";
                break;
                
            case PAControllerStateError:
                self.stateLabel.text = [NSString stringWithFormat:@"ERROR: %@", self.controller.error];
                break;
                
            case PAControllerStateServing:
                self.stateLabel.text = [NSString stringWithFormat:@"SERVING AT %@", self.controller.serverURL];
                break;
        }
    }
}


#pragma mark -
#pragma mark Properties


- (void)setController:(PAController *)controller
{
    if (_controller != controller) {
        [_controller removeObserver:self forKeyPath:@"photoInfo"];
        [_controller removeObserver:self forKeyPath:@"state"];
        [_controller release];
        _controller = [controller retain];
        [_controller addObserver:self
                      forKeyPath:@"photoInfo"
                         options:(NSKeyValueObservingOptionNew
                                  | NSKeyValueObservingOptionOld)
                         context:NULL];
        [_controller addObserver:self
                      forKeyPath:@"state"
                         options:(NSKeyValueObservingOptionNew
                                  | NSKeyValueObservingOptionOld)
                         context:NULL];
        
        // Post (delayed) change notifications for "state"
        [_controller performBlockOnMainThread:^(id controller) {
            [controller willChangeValueForKey:@"state"];
            [controller didChangeValueForKey:@"state"];
        } waitUntilDone:NO];
    }
}


#pragma mark -
#pragma mark IBActions


- (IBAction)presentImagePickerControllerForSender:(id)sender
{
    // Handling gesture recognition first
    if ([sender isKindOfClass:[UIGestureRecognizer class]]) {
        if (self.cameraButtonItem.enabled && self.photoLibraryButtonItem.enabled) {
            UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                                     delegate:self
                                                            cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                       destructiveButtonTitle:nil
                                                            otherButtonTitles:NSLocalizedString(@"Take Picture", nil), NSLocalizedString(@"Choose Existing Photo", nil), nil];
            [actionSheet showFromRect:[self.view convertRect:[[sender view] frame]
                                                    fromView:[sender view]]
                               inView:self.view
                             animated:YES];
            [actionSheet release];
            return;
        }
        else if (self.cameraButtonItem.enabled) {
            sender = self.cameraButtonItem;
        }
        else if (self.photoLibraryButtonItem.enabled) {
            sender = self.photoLibraryButtonItem;
        }
    }

    UIImagePickerControllerSourceType sourceType;
    if (sender == self.cameraButtonItem) {
        sourceType = UIImagePickerControllerSourceTypeCamera;
    }
    else if ([UIImagePickerController isMediaType:(NSString *)kUTTypeImage
                           availableForSourceType:UIImagePickerControllerSourceTypePhotoLibrary]) {
        sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    }
    else {
        sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    }
    if (![UIImagePickerController isMediaType:(NSString *)kUTTypeImage availableForSourceType:sourceType]) {
        NSString *message = ((sourceType == UIImagePickerControllerSourceTypeCamera)
                             ? NSLocalizedString(@"Your device does not include a camera.", nil)
                             : NSLocalizedString(@"Your device does not include a photo library.", nil));
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                            message:message
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"Dismiss", nil)
                                                  otherButtonTitles:nil];
        [alertView show];
        [alertView release];
        return;
    }
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.allowsEditing = (sourceType == UIImagePickerControllerSourceTypeCamera);
    imagePickerController.delegate = self;
    imagePickerController.sourceType = sourceType;
    imagePickerController.mediaTypes = [NSArray arrayWithObject:(NSString *)kUTTypeImage];
    [self presentModalViewController:imagePickerController animated:YES];
    [imagePickerController release];
}


- (IBAction)infoButtonItemDidActivate:(id)sender
{
    // TODO
}


#pragma mark -
#pragma mark UIActionSheetDelegate


- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex) {
        case 0: // Take Picture
            [self presentImagePickerControllerForSender:self.cameraButtonItem];
            break;

        case 1: // Choose Existing Photo
            [self presentImagePickerControllerForSender:self.photoLibraryButtonItem];
            break;
    }
}


#pragma mark -
#pragma mark UIImagePickerControllerDelegate


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)imagePickerController
{
    [imagePickerController dismissModalViewControllerAnimated:YES];
}


- (void)imagePickerController:(UIImagePickerController *)imagePickerController didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    if ([(NSString *)kUTTypeImage isEqualToString:[info objectForKey:UIImagePickerControllerMediaType]]) {
        // Determine the CoreGraphics image and the orientation of the selected image
        UIImage *selectedImage = [info objectForKey:UIImagePickerControllerEditedImage] ?: [info objectForKey:UIImagePickerControllerOriginalImage];
        CGImageRef image = CGImageRetain(selectedImage.CGImage);
        BMImageOrientation imageOrientation = BMImageOrientationFromUIImageOrientation(selectedImage.imageOrientation);

        // Determine the preview image size (in pixels)
        CGSize previewSize = CGSizeMake(self.imageView.frame.size.width * self.imageView.contentScaleFactor,
                                        self.imageView.frame.size.height * self.imageView.contentScaleFactor);

        // Hide the image view and display an activity indicator
        self.imageView.hidden = YES;
        [self.imageActivityIndicatorView startAnimating];
        
        // Generate the preview image and the JPEG data for the PAPhotoInfo in the background
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void) {
            // Rotate the image to "Up" orientation first (normalized version)
            CGImageRef normalizedImage = BMImageCreateWithImageInOrientation(image, imageOrientation);

            // Generate the preview image for in-app display
            CGImageRef previewImage = BMImageCreateWithImageScaledDownToAspectFill(normalizedImage,
                                                                                   previewSize,
                                                                                   kCGInterpolationDefault);

            // Generate the photo information
            PAPhotoInfo *photoInfo = [[PAPhotoInfo alloc] initWithNormalizedImage:normalizedImage
                                                                     previewImage:previewImage];
            [_controller performBlockOnMainThread:^(id controller) {
                [controller setPhotoInfo:photoInfo];
            } waitUntilDone:YES];

            // Cleanup
            [photoInfo release];
            CGImageRelease(normalizedImage);
            CGImageRelease(previewImage);
            CGImageRelease(image);
        });
    }
    [imagePickerController dismissModalViewControllerAnimated:YES];
}


#pragma mark -
#pragma mark UIViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Recognize tap gestures on the image container view
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(presentImagePickerControllerForSender:)];
    tapGestureRecognizer.numberOfTapsRequired = 1;
    tapGestureRecognizer.numberOfTouchesRequired = 1;
    [self.imageContainerView addGestureRecognizer:tapGestureRecognizer];
    [tapGestureRecognizer release];
    
    // Add drop shadow to the image container view
    self.imageContainerView.layer.shadowOpacity = 0.25f;
    self.imageContainerView.layer.shadowOffset = CGSizeMake(5.0f, 5.0f);
    self.imageContainerView.layer.shadowColor = [[UIColor blackColor] CGColor];
    
    // Add drop shadow to the info container view
    self.stateContainerView.layer.shadowOpacity = 0.25f;
    self.stateContainerView.layer.shadowOffset = CGSizeMake(5.0f, 5.0f);
    self.stateContainerView.layer.shadowColor = [[UIColor blackColor] CGColor];
    self.stateContainerView.layer.cornerRadius = 10.0f;
    self.stateContainerView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    self.stateContainerView.layer.borderWidth = 1.0f;

    // Enable/disable the Photo Library and Camera buttons depending on whether the
    // device includes a photo library (most probably) and/or a camera
    self.photoLibraryButtonItem.enabled = ([UIImagePickerController isMediaType:(NSString *)kUTTypeImage
                                                         availableForSourceType:UIImagePickerControllerSourceTypePhotoLibrary]
                                           || [UIImagePickerController isMediaType:(NSString *)kUTTypeImage
                                                            availableForSourceType:UIImagePickerControllerSourceTypeSavedPhotosAlbum]);
    self.cameraButtonItem.enabled = [UIImagePickerController isMediaType:(NSString *)kUTTypeImage
                                                  availableForSourceType:UIImagePickerControllerSourceTypeCamera];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


@end
