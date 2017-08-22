//
//  ViewController.m
//  OCtest
//
//  Created by yingjie on 2017/8/22.
//  Copyright © 2017年 yingjie. All rights reserved.
//

#import "ViewController.h"

static void *AVCaptureStillImageIsCapturingStillImageContext =
&AVCaptureStillImageIsCapturingStillImageContext;

@interface ViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (strong, nonatomic) IBOutlet UIView *containerView;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (nonatomic) IBOutlet UIView *overlayView;

@property (weak, nonatomic) IBOutlet UIButton *runStopBtn;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *fromLib;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *fromCam;
@property (nonatomic) UIImagePickerController *imagePickerController;
@property (nonatomic) NSMutableArray *capturedImages;
@property (weak, nonatomic) IBOutlet UITextView *textView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
//    [self.containerView sendSubviewToBack: _textView];
    
//    set up captured image array
    self.capturedImages = [[NSMutableArray alloc] init];
    [self setupAVCapture];
}

// finished import + update function
- (IBAction)PhotoLib:(id)sender {
//   相机关闭，pre层消失。相机按钮消失。imaview出现，text消失
    [session stopRunning];
    previewView.hidden=YES;
    self.textView.hidden=YES;
    self.runStopBtn.hidden=YES;
    self.imageView.hidden=NO;
    
    [self showImage:UIImagePickerControllerSourceTypePhotoLibrary fromButton:sender];
}

- (void)showImage:(UIImagePickerControllerSourceType)sourceType fromButton:(UIBarButtonItem *)button
{
    if (self.imageView.isAnimating)
    {
        [self.imageView stopAnimating];
    }
    
    if (self.capturedImages.count > 0)
    {
        [self.capturedImages removeAllObjects];
    }
    
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.modalPresentationStyle = UIModalPresentationCurrentContext;
    imagePickerController.sourceType = sourceType;
    imagePickerController.delegate = self;
    imagePickerController.modalPresentationStyle =
    (sourceType == UIImagePickerControllerSourceTypeCamera) ? UIModalPresentationFullScreen : UIModalPresentationPopover;
    
    UIPopoverPresentationController *presentationController = imagePickerController.popoverPresentationController;
    presentationController.barButtonItem = button;  // display popover from the UIBarButtonItem as an anchor
    //    presentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    
    if (sourceType == UIImagePickerControllerSourceTypeCamera)
    {
        // The user wants to use the camera interface. Set up our custom overlay view for the camera.
        imagePickerController.showsCameraControls = NO;
        
        /*
         Load the overlay view from the OverlayView nib file. Self is the File's Owner for the nib file, so the overlayView outlet is set to the main view in the nib. Pass that view to the image picker controller to use as its overlay view, and set self's reference to the view to nil.
         */
        [[NSBundle mainBundle] loadNibNamed:@"OverlayView" owner:self options:nil];
        self.overlayView.frame = imagePickerController.cameraOverlayView.frame;
        imagePickerController.cameraOverlayView = self.overlayView;
        self.overlayView = nil;
    }
    
    _imagePickerController = imagePickerController; // we need this for later
    
    [self presentViewController:self.imagePickerController animated:YES completion:^{
        //.. done presenting
    }];
}

// This method is called when an image has been chosen from the library or taken from the camera.
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = [info valueForKey:UIImagePickerControllerOriginalImage];
    [self.capturedImages addObject:image];
    
    [self finishAndUpdate];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:^{
        //.. done dismissing
    }];
    [self.textView setHidden:NO];
    
}

- (void)finishAndUpdate
{
    // Dismiss the image picker.
    [self dismissViewControllerAnimated:YES completion:nil];
    
    if ([self.capturedImages count] > 0)
    {
        if ([self.capturedImages count] == 1)
        {
            // Camera took a single picture.
            [self.imageView setImage:[self.capturedImages objectAtIndex:0]];
            [self.textView setHidden:YES];
        }
        else
        {
            // Camera took multiple pictures; use the list of images for animation.
            self.imageView.animationImages = self.capturedImages;
            self.imageView.animationDuration = 5.0;    // Show each captured photo for 5 seconds.
            self.imageView.animationRepeatCount = 0;   // Animate forever (show all photos).
            [self.imageView startAnimating];
        }
        
        // To be ready to start again, clear the captured images array.
        [self.capturedImages removeAllObjects];
    }
    
    _imagePickerController = nil;
}


- (IBAction)TakePic:(UIBarButtonItem *)sender {
    //   相机打开，pre层出现。相机按钮出现。imavie消失,text消失
    [self.capturedImages removeAllObjects];
    _imagePickerController = nil;
    self.textView.hidden=YES;
    previewView.hidden=NO;
    self.imageView.hidden=YES;
    self.runStopBtn.hidden=NO;
    
    //    run the previewView
    [session startRunning];
}

- (void)setupAVCapture {
    NSError *error = nil;
    
    session = [AVCaptureSession new];
    if ([[UIDevice currentDevice] userInterfaceIdiom] ==
        UIUserInterfaceIdiomPhone)
        [session setSessionPreset:AVCaptureSessionPreset640x480];
    else
        [session setSessionPreset:AVCaptureSessionPresetPhoto];
    
    AVCaptureDevice *device =
    [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    assert(error == nil);
    
    if ([session canAddInput:deviceInput]) [session addInput:deviceInput];
    
    stillImageOutput = [AVCaptureStillImageOutput new];
    [stillImageOutput
     addObserver:self
     forKeyPath:@"capturingStillImage"
     options:NSKeyValueObservingOptionNew
     context:(void *)(AVCaptureStillImageIsCapturingStillImageContext)];
    if ([session canAddOutput:stillImageOutput])
        [session addOutput:stillImageOutput];
    
    videoDataOutput = [AVCaptureVideoDataOutput new];
    
    NSDictionary *rgbOutputSettings = [NSDictionary
                                       dictionaryWithObject:[NSNumber numberWithInt:kCMPixelFormat_32BGRA]
                                       forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [videoDataOutput setVideoSettings:rgbOutputSettings];
    [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    videoDataOutputQueue =  dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    
    if ([session canAddOutput:videoDataOutput])
        [session addOutput:videoDataOutput];
    [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
    
    previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
//    [previewLayer setBackgroundColor:[[UIColor whiteColor] CGColor]];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    CALayer *rootLayer = [previewView layer];
    [rootLayer setMasksToBounds:YES];
    [previewLayer setFrame:[rootLayer bounds]];
    [rootLayer addSublayer:previewLayer];
    
    
    if (error) {
        NSString *title = [NSString stringWithFormat:@"Failed with error %d", (int)[error code]];
        UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:title
                                            message:[error localizedDescription]
                                     preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *dismiss =
        [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil];
        [alertController addAction:dismiss];
        [self presentViewController:alertController animated:YES completion:nil];
        [self teardownAVCapture];
    }
    
}
- (void)teardownAVCapture {
    [stillImageOutput removeObserver:self forKeyPath:@"isCapturingStillImage"];
    [previewLayer removeFromSuperlayer];
}
//watch for any changes
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (context == AVCaptureStillImageIsCapturingStillImageContext) {
        BOOL isCapturingStillImage =
        [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        
        if (isCapturingStillImage) {
            // do flash bulb like animation
            flashView = [[UIView alloc] initWithFrame:[previewView frame]];
            [flashView setBackgroundColor:[UIColor whiteColor]];
            [flashView setAlpha:0.f];
            [[[self view] window] addSubview:flashView];
            
            [UIView animateWithDuration:.4f
                             animations:^{
                                 [flashView setAlpha:1.f];
                             }];
        } else {
            [UIView animateWithDuration:.4f
                             animations:^{
                                 [flashView setAlpha:0.f];
                             }
                             completion:^(BOOL finished) {
                                 [flashView removeFromSuperview];
                                 flashView = nil;
                             }];
        }
    }
}


- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation:
(UIDeviceOrientation)deviceOrientation {
    AVCaptureVideoOrientation result =
    (AVCaptureVideoOrientation)(deviceOrientation);
    if (deviceOrientation == UIDeviceOrientationLandscapeLeft)
        result = AVCaptureVideoOrientationLandscapeRight;
    else if (deviceOrientation == UIDeviceOrientationLandscapeRight)
        result = AVCaptureVideoOrientationLandscapeLeft;
    return result;
}


- (IBAction)FreezeCam:(id)sender {
//      截取画面，相机按钮变化。
    if ([session isRunning]) {
        [session stopRunning];
        [sender setTitle:@"Continue" forState:UIControlStateNormal];
        
        flashView = [[UIView alloc] initWithFrame:[previewView frame]];
        [flashView setBackgroundColor:[UIColor whiteColor]];
        [flashView setAlpha:0.f];
        [[[self view] window] addSubview:flashView];
        
        [UIView animateWithDuration:.2f
                         animations:^{
                             [flashView setAlpha:1.f];
                         }
                         completion:^(BOOL finished) {
                             [UIView animateWithDuration:.2f
                                              animations:^{
                                                  [flashView setAlpha:0.f];
                                              }
                                              completion:^(BOOL finished) {
                                                  [flashView removeFromSuperview];
                                                  flashView = nil;
                                              }];
                         }];
        
    } else {
        [session startRunning];
        [sender setTitle:@"Freeze Frame" forState:UIControlStateNormal];
    }
}


@end

