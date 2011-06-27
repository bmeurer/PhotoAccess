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

#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>

#import "PARootViewController.h"
#import "UIImage+Resize.h"
#import "UIImagePickerController+PhotoAccess.h"


@implementation PARootViewController

@synthesize imageContainerView = _imageContainerView;
@synthesize imageView = _imageView;
@synthesize infoContainerView = _infoContainerView;
@synthesize photoLibraryButtonItem = _photosButtonItem;
@synthesize cameraButtonItem = _cameraButtonItem;
@synthesize infoButtonItem = _infoButtonItem;


- (void)dealloc
{
    [_imageContainerView release];
    [_imageView release];
    [_infoContainerView release];
    [_photosButtonItem release];
    [_cameraButtonItem release];
    [_infoButtonItem release];
    [super dealloc];
}


#pragma mark -
#pragma mark IBActions


- (IBAction)presentImagePickerControllerForSender:(id)sender
{
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


- (IBAction)imageContainerViewDoubleTapped:(id)sender
{
    if (self.cameraButtonItem.enabled && self.photoLibraryButtonItem.enabled) {
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                                 delegate:self
                                                        cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                   destructiveButtonTitle:nil
                                                        otherButtonTitles:NSLocalizedString(@"Take Picture", nil), NSLocalizedString(@"Choose Existing Photo", nil), nil];
        if ([sender isKindOfClass:[UIView class]]) {
            [actionSheet showFromRect:[self.view convertRect:[sender frame] fromView:sender] inView:self.view animated:YES];
        }
        else {
            [actionSheet showInView:self.view];
        }
        [actionSheet release];
    }
    else if (self.cameraButtonItem.enabled) {
        [self presentImagePickerControllerForSender:self.cameraButtonItem];
    }
    else {
        [self presentImagePickerControllerForSender:self.photoLibraryButtonItem];
    }
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
        UIImage *editedImage = [info objectForKey:UIImagePickerControllerEditedImage];
        UIImage *originalImage = [info objectForKey:UIImagePickerControllerOriginalImage];
        
        UIImage *image = editedImage ?: originalImage;
        if (image) {
            UIImage *thumbnailImage = [image thumbnailImage:self.imageView.frame.size.width transparentBorder:0 cornerRadius:0 interpolationQuality:kCGInterpolationHigh];
            self.imageView.image = thumbnailImage;
        }
    }
    [self imagePickerControllerDidCancel:imagePickerController];
}


#pragma mark -
#pragma mark UIViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageContainerViewDoubleTapped:)];
    tapGestureRecognizer.numberOfTapsRequired = 2;
    tapGestureRecognizer.numberOfTouchesRequired = 1;
    [_imageContainerView addGestureRecognizer:tapGestureRecognizer];
    [tapGestureRecognizer release];
    
    _imageContainerView.layer.shadowOpacity = 0.25f;
    _imageContainerView.layer.shadowOffset = CGSizeMake(5.0f, 5.0f);
    _imageContainerView.layer.shadowColor = [[UIColor blackColor] CGColor];
    
    _infoContainerView.layer.shadowOpacity = 0.25f;
    _infoContainerView.layer.shadowOffset = CGSizeMake(5.0f, 5.0f);
    _infoContainerView.layer.shadowColor = [[UIColor blackColor] CGColor];
    _infoContainerView.layer.cornerRadius = 10.0f;
    _infoContainerView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    _infoContainerView.layer.borderWidth = 1.0f;
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    _photosButtonItem.enabled = ([UIImagePickerController isMediaType:(NSString *)kUTTypeImage
                                               availableForSourceType:UIImagePickerControllerSourceTypePhotoLibrary]
                                 || [UIImagePickerController isMediaType:(NSString *)kUTTypeImage
                                                  availableForSourceType:UIImagePickerControllerSourceTypeSavedPhotosAlbum]);
    _cameraButtonItem.enabled = [UIImagePickerController isMediaType:(NSString *)kUTTypeImage
                                              availableForSourceType:UIImagePickerControllerSourceTypeCamera];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


@end
