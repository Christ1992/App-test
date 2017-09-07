// Copyright 2015 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <AssertMacros.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import "CameraExampleViewController.h"

#include <sys/time.h>

#include "tensorflow_utils.h"
using tensorflow::Tensor;
using tensorflow::Status;
using tensorflow::string;
using tensorflow::int32;
using tensorflow::uint8;

// If you have your own model, modify this to the file name, and make sure
// you've added the file to your app resources too.
static NSString* model_file_name = @"strip_unused_nodes_graph";
static NSString* model_file_type = @"pb";

// If you have your own model, point this to the labels file.
static NSString* labels_file_name = @"kid_new_label_map";
static NSString* labels_file_type = @"txt";

// These dimensions need to match those the model was trained with.
const tensorflow::int32 wanted_input_width = 300;
const tensorflow::int32 wanted_input_height = 300;
const tensorflow::int32 wanted_input_channels = 3;


//const float input_mean = 128.0f;
//const float input_std = 128.0f;
//const std::string input_layer_name = "image_tensor";
//const std::array output_layer_name = "detection_boxes", "detection_scores", "detection_classes", "num_detections";


//global values setting
bool freezeBtn=false;
const int frameWidth=320;
const int frameHeight=320*640/480;
const int frameHeight2=524;
const int marginT=0;

NSString *labelName;
NSString *wordsToSay=nil;
NSArray *soundIDSet;

int predictedX=-1;
int predictedY=-1;
int predictedW=-1;
int predictedH=-1;
int predictedID=-1;

NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
NSString *doucumentDirectory = paths[0];
NSString *fullPath = [doucumentDirectory stringByAppendingPathComponent:@"photo.jpg"];

int typeFlag=0;



static void *AVCaptureStillImageIsCapturingStillImageContext =
    &AVCaptureStillImageIsCapturingStillImageContext;
CFBundleRef mainBundle = CFBundleGetMainBundle();


@interface CameraExampleViewController (InternalMethods)
- (void)setupAVCapture;
- (void)teardownAVCapture;

@end

@implementation CameraExampleViewController

// load view
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.capturedImages = [[NSMutableArray alloc] init];
    self.runStopBtn.hidden=YES;
    self.runButton.hidden=YES;
    
    // set up for camera capture
    [self setupAVCapture];
    
    // split memory
    synth = [[AVSpeechSynthesizer alloc] init];
    labelLayers = [[NSMutableArray alloc] init];
    
    // load model
    tensorflow::Status load_status;
    load_status = LoadModel(model_file_name, model_file_type, &tf_session);
    
    if (!load_status.ok()) {
        LOG(FATAL) << "Couldn't load model: " << load_status;
    }
    
    // load label
    tensorflow::Status labels_status =
    LoadLabels(labels_file_name, labels_file_type, &labels);
    if (!labels_status.ok()) {
        LOG(FATAL) << "Couldn't load labels: " << labels_status;
    }
    
}

// set up the camera capture session
- (void)setupAVCapture {
    NSError *error = nil;
    
    session = [AVCaptureSession new];
    session.sessionPreset = AVCaptureSessionPreset640x480;
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    [session addInput:input];
    
    // set up for capure still images
    stillImageOutput = [AVCaptureStillImageOutput new];
    [stillImageOutput
     addObserver:self
     forKeyPath:@"capturingStillImage"
     options:NSKeyValueObservingOptionNew
     context:(void *)(AVCaptureStillImageIsCapturingStillImageContext)];
    if ([session canAddOutput:stillImageOutput])
        [session addOutput:stillImageOutput];
    
    videoDataOutput = [AVCaptureVideoDataOutput new];
    
    // output format: 32BGRA
    NSDictionary *rgbOutputSettings = [NSDictionary
                                       dictionaryWithObject:[NSNumber numberWithInt:kCMPixelFormat_32BGRA]
                                       forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [videoDataOutput setVideoSettings:rgbOutputSettings];
    [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    videoDataOutputQueue =  dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    
    [session addOutput:videoDataOutput];
    
    [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
    
    // show captured image on preview layer
    previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    CGRect layerRect = CGRectMake(0, marginT, frameWidth,frameHeight );
    [previewLayer setFrame:layerRect];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    
    [previewView.layer addSublayer:previewLayer];
    
    // init the draw view for drawing boxes
    CGRect drawRect = CGRectMake(0, marginT, 414,600 );
    [drawView setFrame:drawRect];
    
    
    
    
    
}

- (void)teardownAVCapture {
    [stillImageOutput removeObserver:self forKeyPath:@"isCapturingStillImage"];
    [previewLayer removeFromSuperlayer];
}

// monitor the sample buffer
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    if (freezeBtn==false){
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CFRetain(pixelBuffer);
        
        // run the detection model
        [self prepareModel:pixelBuffer];
        CFRelease(pixelBuffer);
    }else{
        [session stopRunning];
    }
}

// transform to tensor and run
- (void)prepareModel:(CVPixelBufferRef)pixelBuffer {
    
    // get image from buffer
    OSType sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    int doReverseChannels;
    if (kCVPixelFormatType_32ARGB == sourcePixelFormat) {
        doReverseChannels = 1;
    } else if (kCVPixelFormatType_32BGRA == sourcePixelFormat) {
        doReverseChannels = 0;
    } else {
        NSLog(@"type error");  // Unknown source format
    }
    
    const int sourceRowBytes = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
    const int image_width = (int)CVPixelBufferGetWidth(pixelBuffer);
    const int fullHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
    
    CVPixelBufferLockFlags unlockFlags = kNilOptions;
    CVPixelBufferLockBaseAddress(pixelBuffer, unlockFlags);
    
    unsigned char *sourceBaseAddr =
    (unsigned char *)(CVPixelBufferGetBaseAddress(pixelBuffer));
    
    
    int image_height;
    unsigned char *sourceStartAddr;
    // device portrait
    if (fullHeight <= image_width) {
        image_height = fullHeight;
        sourceStartAddr = sourceBaseAddr;
    } else {
        // device - landscape
        image_height = image_width;
        const int marginY = ((fullHeight - image_width) / 2);
        sourceStartAddr = (sourceBaseAddr + (marginY * sourceRowBytes));
    }
    const int image_channels = 4;
    
    // generate the tensor from image
    tensorflow::Tensor image_tensor(
                                    tensorflow::DT_UINT8,
                                    tensorflow::TensorShape({1, wanted_input_height, wanted_input_width, wanted_input_channels}));
    auto image_tensor_mapped = image_tensor.tensor<uint8, 4>();
    tensorflow::uint8 *in = sourceStartAddr;
    uint8 *out = image_tensor_mapped.data();
    //    get resized pixels
    for (int y = 0; y < wanted_input_height; ++y) {
        uint8 *out_row = out + (y * wanted_input_width * wanted_input_channels);
        for (int x = 0; x < wanted_input_width; ++x) {
            const int in_x = (y * image_width) / wanted_input_width;
            const int in_y = (x * image_height) / wanted_input_height;
            tensorflow::uint8 *in_pixel =  in + (in_y * image_width * image_channels) + (in_x * image_channels);
            uint8 *out_pixel = (out_row + (x * wanted_input_channels));
            
            // transform the brga format to rgb format
            uint8 blue=in_pixel[0];
            uint8 green=in_pixel[1];
            uint8 red=in_pixel[2];
            
            out_pixel[0]=red;
            out_pixel[1]=green;
            out_pixel[2]=blue;
            
            
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, unlockFlags);
    
    //run the graph model
    if (tf_session.get()) {
        std::vector<tensorflow::Tensor> outputs;
        double a = CFAbsoluteTimeGetCurrent();
        
        // input image_tensor and receive outputs
        tensorflow::Status run_status = tf_session->Run({{"image_tensor", image_tensor}}, {"detection_boxes", "detection_scores", "detection_classes", "num_detections"}, {}, &outputs);
        
        predictedX=-1;
        predictedY=-1;
        predictedW=-1;
        predictedH=-1;
        predictedID=-1;
        
        if (!run_status.ok()) {
            LOG(ERROR) << "Running model failed:" << run_status;
        } else {
            
            // print time run of model
            double b = CFAbsoluteTimeGetCurrent();
            unsigned int m = ((b-a) * 1000.0f); // convert from seconds to milliseconds
            NSLog(@"%@: %d ms", @"Run Model Time taken", m);
            
            // prepare for print
            std::vector<float> boxScore;
            std::vector<float> boxRect;
            std::vector<std::string> boxName;
            
            tensorflow::TTypes<float>::Flat scores_flat = outputs[1].flat<float>();
            tensorflow::Tensor &indices = outputs[2];
            tensorflow::TTypes<float>::Flat indices_flat = indices.flat<float>();
            
            const tensorflow::Tensor& encoded_locations = outputs[0];
            auto locations_encoded = encoded_locations.flat<float>();
            
            
            // filter the predictions by thredhold 0.35
            for (int pos = 0; pos < 20; ++pos) {
                const int label_index = (tensorflow::int32)indices_flat(pos);
                const float score = scores_flat(pos);
                LOG(INFO) << "I am here " ;
                
                if (score < 0.35) break;
                
                float ymin = locations_encoded(pos * 4 + 0) ;
                float xmin = locations_encoded(pos * 4 + 1) ;
                float ymax = locations_encoded((pos * 4 + 2)) ;
                float xmax = locations_encoded(pos * 4 + 3) ;
                
                //  get the label
                std::string displayName = labels[label_index-1];
                if(pos==0){
                    
                    predictedID=label_index-1;
                }
                
                //            LOG(INFO) << "Detection "  << " score: " << score
                //            << " Detected Name: " << displayName
                //            << " Detected label number: " << label_index;;
                
                boxScore.push_back(score);
                boxName.push_back(displayName);
                boxRect.push_back(ymin); boxRect.push_back(xmin); boxRect.push_back(ymax); boxRect.push_back(xmax);
                
            }
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                
                [self removeAllLabelLayers];
                int labelCount = 0;
                
                // draw all bounding boxes
                for(int i=0; i<boxName.size(); i++)
                {
                    float ymin = boxRect.at(i*4+0);
                    float xmin = boxRect.at(i*4+1);
                    float ymax = boxRect.at(i*4+2);
                    float xmax = boxRect.at(i*4+3);
                    
                    NSString *labelValue = [NSString stringWithFormat:@"%s %5.3f", boxName.at(i).c_str(), boxScore.at(i)];
                    
                    labelName = [NSString stringWithFormat:@"%s", boxName.at(i).c_str()];
                    
                    const float topMargin=marginT;
                    const float originY = ymin*frameHeight+topMargin;
                    const float originX = (1-xmax)*frameWidth;
                    const float labelWidth=(xmax-xmin)*frameWidth;
                    const float labelHeight=(ymax-ymin)*frameHeight;
                    
                    
                    [self addLabelLayerWithText:labelValue
                                        originX:originX
                                        originY:originY
                                          width:labelWidth
                                         height:labelHeight
                                      alignment:kCAAlignmentLeft];
                    
                    // when top 1 score > 50%, prepare for Q & A session
                    if ((labelCount == 0) && (boxScore.at(i) > 0.5f)) {
                        
                        wordsToSay=[NSString stringWithFormat:@"There is a %@. Can you find it?", labelName];
                        predictedX=originX;
                        predictedY=originY;
                        predictedW=labelWidth;
                        predictedH=labelHeight;
                        
                    }
                    else if ((labelCount == 0) && (boxScore.at(i) <= 0.5f)){
                        wordsToSay=nil;
                    }
                    labelCount+=1;
                }
                
                
            });
        }
    }
}


// play the corresponding sound using AVToolBox
-(void)playSound:(int) ID{
 
    SystemSoundID soundID;
    NSString *str= [NSString stringWithCString:labels[ID].c_str() encoding:[NSString defaultCStringEncoding]];
    NSString* strSoundFile = FilePathForResourceName(str, @"wav");
    
    // create sound ID & play
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:strSoundFile],&soundID);
    
    AudioServicesPlaySystemSound(soundID);
}

// function to give audio instructions
- (void)speak:(NSString *)words {
    if ([synth isSpeaking]) {
        return;
    }
    AVSpeechUtterance *utterance =
    [AVSpeechUtterance speechUtteranceWithString:words];
    
    utterance.voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"en-US"];
    utterance.rate = 1 * AVSpeechUtteranceDefaultSpeechRate;
    
    [synth speakUtterance:utterance];
    
}


// press the run model button, detect the still image
- (IBAction)runButton:(id)sender {
    [sender setTitle:@"Loading...." forState:UIControlStateNormal];
    
    // preparation for detection model, initialization
    int width;
    int height;
    int channels;
    std::vector<tensorflow::Tensor> outputs;
    predictedX=-1;
    predictedY=-1;
    predictedW=-1;
    predictedH=-1;
    predictedID=-1;
    NSString* filepath = [doucumentDirectory stringByAppendingFormat:@"/photo"];
    [self removeAllLabelLayers];
    
    // run model session
    int ret = runModel(filepath, @"jpg", &width, &height, &channels, typeFlag, outputs);

    
    // get result and print
    if(ret==0){
        std::vector<float> boxScore;
        std::vector<float> boxRect;
        std::vector<std::string> boxName;
        tensorflow::TTypes<float>::Flat scores_flat = outputs[1].flat<float>();
        tensorflow::Tensor &indices = outputs[2];
        tensorflow::TTypes<float>::Flat indices_flat = indices.flat<float>();
        wordsToSay=nil;
        const tensorflow::Tensor& encoded_locations = outputs[0];
        auto locations_encoded = encoded_locations.flat<float>();
        
        
        // filter the predictions by thredhold 0.35
        for (int pos = 0; pos < 20; ++pos) {
            const int label_index = (tensorflow::int32)indices_flat(pos);
            const float score = scores_flat(pos);
            LOG(INFO) << "I am here " ;
        
            if (score < 0.35) break;
        
            float ymin = locations_encoded(pos * 4 + 0) ;
            float xmin = locations_encoded(pos * 4 + 1) ;
            float ymax = locations_encoded((pos * 4 + 2)) ;
            float xmax = locations_encoded(pos * 4 + 3) ;
        
            // get the label
            std::string displayName = labels[label_index-1];
            if(pos==0){
                predictedID=label_index-1;
            }
//            LOG(INFO) << "Detection " << pos << ": "
//            << "xmin:" << xmin << " "
//            << "ymin:" << ymin << " "
//            << "xmax:" << xmax << " "
//            << "ymax:" << ymax << " "
//            << "(" << pos << ") score: " << score << " Detected Name: " << displayName<< " Detected label number: " << label_index;
            
            boxScore.push_back(score);
            boxName.push_back(displayName);
            boxRect.push_back(ymin); boxRect.push_back(xmin); boxRect.push_back(ymax); boxRect.push_back(xmax);
        
    }
    // async system
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        [self removeAllLabelLayers];
        int labelCount = 0;
        
        // calculate the transformed coordinate
        if(boxName.size()>0){
            for(int i=0; i<boxName.size(); i++)
            {
                float ymin = boxRect.at(i*4+0);
                float xmin = boxRect.at(i*4+1);
                float ymax = boxRect.at(i*4+2);
                float xmax = boxRect.at(i*4+3);
                
                NSString *labelValue = [NSString stringWithFormat:@"%s %5.3f", boxName.at(i).c_str(), boxScore.at(i)];
                
                labelName = [NSString stringWithFormat:@"%s", boxName.at(i).c_str()];
                float ratioImg=(float)width/height;
                float ratioScreen=(float)frameWidth/frameHeight2;
                float Margin,originY,originX,labelWidth,labelHeight = 0.0;
                if (ratioImg>ratioScreen) {
                    
                    //restrict the size by image width
                    
                    Margin=marginT+(frameHeight2-frameWidth/ratioImg)/2;
                    LOG(INFO) << "new height: " << frameWidth/ratioImg << ": ";
                    originY = ymin*frameWidth/ratioImg+Margin;
                    originX = xmin*frameWidth;
                    labelWidth=(xmax-xmin)*frameWidth;
                    labelHeight=(ymax-ymin)*frameWidth/ratioImg;
                    
                    
                    
                }else{
                    
                     //restrict the size by image height
                    
                    Margin=(frameWidth-frameHeight2*ratioImg)/2;
                    originY = ymin*frameHeight2;
                    originX = xmin*frameHeight2*ratioImg+Margin;
                    labelWidth=(xmax-xmin)*frameHeight2*ratioImg;
                    labelHeight=(ymax-ymin)*frameHeight2;
                    
                    
                    
                }
//                LOG(INFO) << "Margin " << Margin << ": "
//                << "originX:" << originX << " "
//                << "originY:" << originY << " "
//                << "xmlabelWidthax:" << labelWidth << " "
//                << "labelHeight:" << labelHeight << " "<< "ratioImg:" << ratioImg<< "ratioScreen:" << ratioScreen
//                ;
                
                // draw all predicted boxes
                [self addLabelLayerWithText:labelValue
                                    originX:originX
                                    originY:originY
                                      width:labelWidth
                                     height:labelHeight
                                  alignment:kCAAlignmentLeft];
                
                // generating the Q & A session for the Top 1 score > 0.5
                
                if ((labelCount == 0) && (boxScore.at(i) > 0.5f)) {
                    
                    wordsToSay=[NSString stringWithFormat:@"There is a %@. Can you find it?", labelName];
                    predictedX=originX;
                    predictedY=originY;
                    predictedW=labelWidth;
                    predictedH=labelHeight;
                }
                labelCount+=1;
            }
           
            dispatch_async(dispatch_get_main_queue(), ^(void) {
            if(wordsToSay!=nil){
                
                // prepare correct area view for answer
                    CGRect correctrect=CGRectMake(predictedX, predictedY, predictedW, predictedH);
                    correctArea=[[UIView alloc] initWithFrame:correctrect];
                    correctArea.userInteractionEnabled = YES;
                    [correctArea setBackgroundColor:[UIColor clearColor]];
                
                // add tap gesture interaction
                    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapView:)];
                    [correctArea addGestureRecognizer:tap];
                    [drawView addSubview:correctArea];
                
                // audio instruction
                [self speak:wordsToSay];
                
                
            }else{
                //  Detected something but unsure about it (score: 35%~50%)
                [self speak:@"Sorry, I'm not sure about the object."];
            }
            });
        
        
        }

        else{
            // nothing detected(all confidence < 35%), show an alert
            
            UIAlertController * alert=[UIAlertController alertControllerWithTitle:@"Sorry"
                                                                          message:@"No object detected. I am not perfect. Further improvement ongoing."
                                                                   preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction * action) {
                                                                  
                                                                      [textView setHidden:NO];
                                                                      [self.runButton setHidden:YES];
                                                                  }];
            
            [alert addAction:defaultAction];
            [self presentViewController:alert animated:YES completion:nil];
          
        }
        // change button status
        [sender setTitle:@"Finished" forState:UIControlStateNormal];

        
    });
  }
}


// press the phone library button
- (IBAction)PhotoLib:(id)sender {
    //   stop the photo capture session
    [session stopRunning];
    
    //change interface
    self.runStopBtn.hidden=YES;
    textView.hidden=YES;
    imageView.hidden=NO;
    previewView.hidden=YES;
    self.runButton.hidden=NO;
    freezeBtn=true;
    [correctArea removeFromSuperview];
    
    // prepare the image view for showing the image picked from library
    [self.view addSubview:imageView];
    [self.view sendSubviewToBack:imageView];
    
    [self.runButton setTitle:@"Run Model" forState:UIControlStateNormal];
    [self removeAllLabelLayers];
    
    // show the picked image
    [self showImage:UIImagePickerControllerSourceTypePhotoLibrary fromButton:sender];
}


// display the image
- (void)showImage:(UIImagePickerControllerSourceType)sourceType fromButton:(UIBarButtonItem *)button
{
    if (imageView.isAnimating)
    {
        [imageView stopAnimating];
    }
    
    if (self.capturedImages.count > 0)
    {
        [self.capturedImages removeAllObjects];
    }
    
    // pick the image
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.modalPresentationStyle = UIModalPresentationCurrentContext;
    imagePickerController.sourceType = sourceType;
    imagePickerController.delegate = self;
    imagePickerController.modalPresentationStyle =
    (sourceType == UIImagePickerControllerSourceTypeCamera) ? UIModalPresentationFullScreen : UIModalPresentationPopover;
    
    UIPopoverPresentationController *presentationController = imagePickerController.popoverPresentationController;
    presentationController.barButtonItem = button;
    // display popover from the UIBarButtonItem as an anchor
    
    _imagePickerController = imagePickerController;
    
    [self presentViewController:self.imagePickerController animated:YES completion:^{
        //.. done presenting
    }];
}


// This method is called when an image has been chosen from the library
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = [info valueForKey:UIImagePickerControllerOriginalImage];
    if (UIImagePNGRepresentation(image) == nil) {
        //jpg format
        typeFlag=3;
        
    } else {
        //png format
        typeFlag=4;
    }
    
    //save picture to local path
    [self.capturedImages addObject:image];
    [UIImageJPEGRepresentation(image, 0.5) writeToFile:fullPath atomically:YES];
    
    [self finishAndUpdate];
}


// cancel the pickup from lib
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:^{
        //.. done dismissing
    }];
    [textView setHidden:NO];
    [self.runButton setHidden:YES];
}


// display the image
- (void)finishAndUpdate
{
    
    // Dismiss the image picker.
    [self dismissViewControllerAnimated:YES completion:nil];
    
    // set the background image to the picked image
    [imageView setContentMode:UIViewContentModeScaleAspectFit];
    [imageView setImage:[self.capturedImages objectAtIndex:0]];
    [textView setHidden:YES];
    
    
    // To be ready to start again, clear the captured images array.
    [self.capturedImages removeAllObjects];
    _imagePickerController = nil;
}

// when press the camera button
- (IBAction)TakePic:(id)sender {
    // Interface changes
    [self.capturedImages removeAllObjects];
    _imagePickerController = nil;
    textView.hidden=YES;
    previewView.hidden=NO;
    imageView.hidden=YES;
    self.runStopBtn.hidden=NO;
    self.runButton.hidden=YES;
    [imageView removeFromSuperview];
    [self removeAllLabelLayers];
    [correctArea removeFromSuperview];
    imageView=[[UIImageView alloc] initWithFrame:CGRectMake(0, 0,boundView.frame.size.width,boundView.frame.size.height)];
    freezeBtn=false;
    
    
    // start to capture img
    [session startRunning];
    
}

- (IBAction)FreezeCam:(id)sender {
    
    //  freeze the frame
    if ([session isRunning]) {
        [session stopRunning];
        freezeBtn=true;

        [sender setTitle:@"Continue" forState:UIControlStateNormal];
        
        // flash light effect
        
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
        
        
        // give instruction and generate the touchable area
        if(wordsToSay!=nil){
            
            // if the high confidence object were detected
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                // if the high confidence object were detected, generate the view according to prediction
                CGRect correctrect=CGRectMake(predictedX, predictedY, predictedW, predictedH);
                correctArea=[[UIView alloc] initWithFrame:correctrect];
                correctArea.userInteractionEnabled = YES;
                [correctArea setBackgroundColor:[UIColor clearColor]];
                
                // add touch behavior to the view
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapView:)];
                [correctArea addGestureRecognizer:tap];
                [drawView addSubview:correctArea];
            });
            // [self playSound:predictedID];
            // give audio instruction
            [self speak:wordsToSay];

            
        }else{
             // play audio instruction
            [self speak:@"Sorry, I'm not sure about the object."];
        
        
        }
    } else {
        // switch between freeze and continue
        [sender setTitle:@"Freeze Frame" forState:UIControlStateNormal];
        freezeBtn=false;
        [session startRunning];
        
        // initialization for new capture
        predictedX=-1; predictedY=-1; predictedW=-1; predictedH=-1;predictedID=-1;
        [correctArea removeFromSuperview];
        
        [self removeAllLabelLayers];
        
    }
}

int speakControl = 1;

// when tap the correctArea view
-(void)tapView:(UITapGestureRecognizer *)sender{
    // tap to change random color
    correctArea.backgroundColor = [UIColor colorWithRed:arc4random()%256/255.0 green:arc4random()%256/255.0 blue:arc4random()%256/255.0 alpha:0.2];
    
    // 3 available appraisal
    switch (speakControl)
    {
        case 1:
            [self speak:@"Smart kid!"];
            
            // play the animal sounds
            [self playSound:predictedID];
            speakControl++;
            break;
        case 2:
            [self speak:@"Good choice."];
            [self playSound:predictedID];
            speakControl++;
            break;
        default:
            [self speak:@"Nice shot."];
            [self playSound:predictedID];
            speakControl=1;
            break;
    }
    
}



// delete all the bounding boxes
- (void)removeAllLabelLayers {
    for (CATextLayer *layer in labelLayers) {
        [layer removeFromSuperlayer];
    }
    [labelLayers removeAllObjects];
}


// function to draw the bounding boxes and label texts
- (void)addLabelLayerWithText:(NSString *)text
                      originX:(float)originX
                      originY:(float)originY
                        width:(float)width
                       height:(float)height
                    alignment:(NSString *)alignment {
    
    CFTypeRef font = (CFTypeRef) @"Menlo-Regular";
    const float fontSize = 13.0f;
    
    const float marginSizeX = 5.0f;
    const float marginSizeY = 2.0f;
    
    CGRect backgroundBounds = CGRectMake(originX, originY, width, height);
    
    CGRect textBounds = CGRectMake((originX + marginSizeX), (originY - 8*marginSizeY),
               (width - (marginSizeX * 2)), (height - (marginSizeY * 2)));
    
    
    // draw bounding boxes
    CATextLayer *background = [CATextLayer layer];
    [background setBackgroundColor:[UIColor clearColor].CGColor];
    [background setBorderColor:[UIColor blackColor].CGColor];
    [background setBorderWidth:2];
    [background setFrame:backgroundBounds];
    
    [[drawView layer] addSublayer:background];
    [labelLayers addObject:background];
    
    
    // draw label texts
    CATextLayer *layer = [CATextLayer layer];
    [layer setForegroundColor:[UIColor blueColor].CGColor];
    [layer setFrame:textBounds];
    [layer setAlignmentMode:alignment];
    [layer setWrapped:YES];
    [layer setFont:font];
    [layer setFontSize:fontSize];
    layer.contentsScale = [[UIScreen mainScreen] scale];
    [layer setString:text];
    
    [[drawView layer] addSublayer:layer];
    [labelLayers addObject:layer];
}


// if out of memory
- (void)dealloc {
  [self teardownAVCapture];
    UIAlertController * alert=[UIAlertController alertControllerWithTitle:@"Sorry"
                                                                  message:@"I am out of memory"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                             
                                                          }];
    
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


- (void)viewDidUnload {
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:
(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

@end
