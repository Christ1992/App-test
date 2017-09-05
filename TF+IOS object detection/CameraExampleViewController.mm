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
// This controls whether we'll be loading a plain GraphDef proto, or a
// file created by the convert_graphdef_memmapped_format utility that wraps a
// GraphDef and parameter file that can be mapped into memory from file to
// reduce overall memory usage.
//const bool model_uses_memory_mapping = false;
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
bool freezeBtn=false;
const int frameWidth=320;
const int frameHeight=320*640/480;
const int frameHeight2=524;
const int marginT=0;
NSString *labelName;
NSString *wordsToSay=nil;
int predictedX=-1;
int predictedY=-1;
int predictedW=-1;
int predictedH=-1;
int predictedID=-1;
NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
NSString *doucumentDirectory = paths[0];
NSString *fullPath = [doucumentDirectory stringByAppendingPathComponent:@"photo.jpg"];
int typeFlag=0;
NSArray *soundIDSet;
//bool drawfinish=true;
static void *AVCaptureStillImageIsCapturingStillImageContext =
    &AVCaptureStillImageIsCapturingStillImageContext;
UIColor *textColor =[UIColor colorWithRed:0.1f green:0.1f blue:1.0f alpha:1.0f];
UIFont *helveticaBold = [UIFont fontWithName:@"HelveticaNeue" size:15.0f];
NSDictionary *dicAttribute = @{NSFontAttributeName:helveticaBold, NSForegroundColorAttributeName:textColor};

CFBundleRef mainBundle = CFBundleGetMainBundle();

@interface CameraExampleViewController (InternalMethods)
- (void)setupAVCapture;
- (void)teardownAVCapture;

@end



@implementation CameraExampleViewController

//std::vector<float> predictedRect;
//std::vector<std::string> predictedName;

-(void)playSound:(int) ID{
//    SystemSoundID soundID;
//    NSString *soundFile = [[NSBundle mainBundle] pathForResource:@"dingdong" ofType:@"wav"];
//    AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:soundFile], &soundID);
//    //提示音 带震动
//    //    AudioServicesPlayAlertSound(soundID);
//    //系统声音labels[i].c_str()
    
        SystemSoundID soundID;
        NSString *str= [NSString stringWithCString:labels[ID].c_str() encoding:[NSString defaultCStringEncoding]];
//        NSString *strSoundFile = [[NSBundle mainBundle] pathForResource:str ofType:@"wav"];
        NSLog(@"str:%@",str);
    
    NSString* strSoundFile = FilePathForResourceName(str, @"wav");
     NSLog(@"strSoundFile:%@",strSoundFile);
        AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:strSoundFile],&soundID);
        AudioServicesPlaySystemSound(soundID);
        //        AudioServicesPlaySystemSound(soundID);
    
   }
- (IBAction)runButton:(id)sender {
    [sender setTitle:@"Loading...." forState:UIControlStateNormal];
    
    int width;
    int height;
    int channels;
    [self removeAllLabelLayers];
    
    std::vector<tensorflow::Tensor> outputs;
    NSString* filepath = [doucumentDirectory stringByAppendingFormat:@"/photo"];
    
    predictedX=-1;
    predictedY=-1;
    predictedW=-1;
    predictedH=-1;
    predictedID=-1;
    int ret = runModel(filepath, @"jpg", &width, &height, &channels, typeFlag, outputs);
//    开始print的准备工作
    
//    std::vector<float> locations;
    if(ret==0){
        std::vector<float> boxScore;
        std::vector<float> boxRect;
        std::vector<std::string> boxName;
        tensorflow::TTypes<float>::Flat scores_flat = outputs[1].flat<float>();
        tensorflow::Tensor &indices = outputs[2];
        tensorflow::TTypes<float>::Flat indices_flat = indices.flat<float>();
//        predictedRect.clear();
//        predictedName.clear();
        wordsToSay=nil;
//    
        const tensorflow::Tensor& encoded_locations = outputs[0];
        auto locations_encoded = encoded_locations.flat<float>();
        
        
    
    //    filter the predictions by thredhold 0.25
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
            LOG(INFO) << "Detection " << pos << ": "
            << "xmin:" << xmin << " "
            << "ymin:" << ymin << " "
            << "xmax:" << xmax << " "
            << "ymax:" << ymax << " "
            << "(" << pos << ") score: " << score << " Detected Name: " << displayName<< " Detected label number: " << label_index;
            
            boxScore.push_back(score);
            boxName.push_back(displayName);
            boxRect.push_back(ymin); boxRect.push_back(xmin); boxRect.push_back(ymax); boxRect.push_back(xmax);
        
    }
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        [self removeAllLabelLayers];
        int labelCount = 0;
        
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
                    //width >>height 以宽为主
                    
                    Margin=marginT+(frameHeight2-frameWidth/ratioImg)/2;
                    LOG(INFO) << "new height: " << frameWidth/ratioImg << ": ";
                    originY = ymin*frameWidth/ratioImg+Margin;
                    originX = xmin*frameWidth;
                    labelWidth=(xmax-xmin)*frameWidth;
                    labelHeight=(ymax-ymin)*frameWidth/ratioImg;
                    
                    
                    
                }else{
                    Margin=(frameWidth-frameHeight2*ratioImg)/2;
                    originY = ymin*frameHeight2;
                    originX = xmin*frameHeight2*ratioImg+Margin;
                    labelWidth=(xmax-xmin)*frameHeight2*ratioImg;
                    labelHeight=(ymax-ymin)*frameHeight2;
                    
                    
                    
                }
                LOG(INFO) << "Margin " << Margin << ": "
                << "originX:" << originX << " "
                << "originY:" << originY << " "
                << "xmlabelWidthax:" << labelWidth << " "
                << "labelHeight:" << labelHeight << " "<< "ratioImg:" << ratioImg<< "ratioScreen:" << ratioScreen
                ;
                
                [self addLabelLayerWithText:labelValue
                                    originX:originX
                                    originY:originY
                                      width:labelWidth
                                     height:labelHeight
                                  alignment:kCAAlignmentLeft];
                
//                predictedRect.push_back(originX);predictedRect.push_back(originY);predictedRect.push_back(labelWidth);predictedRect.push_back(labelHeight);
//                predictedName.push_back(boxName.at(i).c_str());
                
                //
                if ((labelCount == 0) && (boxScore.at(i) > 0.5f)) {
                    
                    wordsToSay=[NSString stringWithFormat:@"There is a %@. Guess where it is?", labelName];
                    predictedX=originX;
                    predictedY=originY;
                    predictedW=labelWidth;
                    predictedH=labelHeight;
                }
                labelCount+=1;
            }
            dispatch_async(dispatch_get_main_queue(), ^(void) {
            if(wordsToSay!=nil){
                //
               
                    CGRect correctrect=CGRectMake(predictedX, predictedY, predictedW, predictedH);
                    correctArea=[[UIView alloc] initWithFrame:correctrect];
                    correctArea.userInteractionEnabled = YES;
                    [correctArea setBackgroundColor:[UIColor clearColor]];
                    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapView:)];
                    [correctArea addGestureRecognizer:tap];
                    [drawView addSubview:correctArea];
                
                //      add touchable area
                [self playSound:predictedID];
                [self speak:wordsToSay];
                
                
            }else{
                [self speak:@"Sorry, I'm not sure about the object."];
                
                
            }
            });
        
        
        }
        
        
        else{
//            UIAlertViewStyleDefault
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
        
           
        
        [sender setTitle:@"Finished" forState:UIControlStateNormal];

        
    });
  }
}
- (IBAction)PhotoLib:(id)sender {
    //   相机关闭，pre层消失。相机按钮消失。imaview出现，text消失
    [session stopRunning];
    previewView.hidden=YES;
    textView.hidden=YES;
    self.runStopBtn.hidden=YES;
    imageView.hidden=NO;
    self.runButton.hidden=NO;
    [correctArea removeFromSuperview];
//    int w=boundView.frame.size.width;
//    int h=boundView.frame.size.height;
    
    
    [self.view addSubview:imageView];
    [self.view sendSubviewToBack:imageView];
    
    freezeBtn=true;
    [self.runButton setTitle:@"Run Model" forState:UIControlStateNormal];
    [self removeAllLabelLayers];
    [self showImage:UIImagePickerControllerSourceTypePhotoLibrary fromButton:sender];
}
//展示照片
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
    
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.modalPresentationStyle = UIModalPresentationCurrentContext;
    imagePickerController.sourceType = sourceType;
    imagePickerController.delegate = self;
    imagePickerController.modalPresentationStyle =
    (sourceType == UIImagePickerControllerSourceTypeCamera) ? UIModalPresentationFullScreen : UIModalPresentationPopover;
    
    UIPopoverPresentationController *presentationController = imagePickerController.popoverPresentationController;
    presentationController.barButtonItem = button;  // display popover from the UIBarButtonItem as an anchor
    //    presentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    
    
    
    _imagePickerController = imagePickerController; // we need this for later
    
    [self presentViewController:self.imagePickerController animated:YES completion:^{
        //.. done presenting
    }];
}
// This method is called when an image has been chosen from the library or taken from the camera.
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = [info valueForKey:UIImagePickerControllerOriginalImage];
    if (UIImagePNGRepresentation(image) == nil) {
//        jpg格式
        typeFlag=3;
        
    } else {
//        png格式
        typeFlag=4;

        
    }
    NSLog(@"typeFlag:%d",typeFlag);
    [self.capturedImages addObject:image];
    
    
    
//    本地保存图片
    [UIImageJPEGRepresentation(image, 0.5) writeToFile:fullPath atomically:YES];
    
    [self finishAndUpdate];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:^{
        //.. done dismissing
    }];
    [textView setHidden:NO];
    [self.runButton setHidden:YES];
}

- (void)finishAndUpdate
{
    
    // Dismiss the image picker.
    [self dismissViewControllerAnimated:YES completion:nil];
    [imageView setImage:[self.capturedImages objectAtIndex:0]];
    [textView setHidden:YES];
    
    
    // To be ready to start again, clear the captured images array.
    [self.capturedImages removeAllObjects];
    _imagePickerController = nil;
    
    
}


- (IBAction)TakePic:(id)sender {
    //   相机打开，pre层出现。相机按钮出现。imavie消失,text消失
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
    //    run the previewView
    freezeBtn=false;
    [session startRunning];
    
}

- (IBAction)FreezeCam:(id)sender {
    //      截取画面，相机按钮变化。
    if ([session isRunning]) {
        [session stopRunning];
        freezeBtn=true;

        [sender setTitle:@"Continue" forState:UIControlStateNormal];
        
        //          give the instruction
        
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
        
        
//        if(predictedName.size()>0){
////        give instruction and generate the touchable area
        if(wordsToSay!=nil){
                //
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                        CGRect correctrect=CGRectMake(predictedX, predictedY, predictedW, predictedH);
                        correctArea=[[UIView alloc] initWithFrame:correctrect];
                        correctArea.userInteractionEnabled = YES;
                        [correctArea setBackgroundColor:[UIColor clearColor]];
                        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapView:)];
                        [correctArea addGestureRecognizer:tap];
                        [drawView addSubview:correctArea];
            });
//      add touchable area
                           [self playSound:predictedID];
                           [self speak:wordsToSay];

            
        }else{
            [self speak:@"Sorry, I'm not sure about the object."];
        
        
        }
    } else {
        [sender setTitle:@"Freeze Frame" forState:UIControlStateNormal];
        freezeBtn=false;
        [session startRunning];
        
        
        predictedX=-1; predictedY=-1; predictedW=-1; predictedH=-1;predictedID=-1;
        [correctArea removeFromSuperview];
        [correctArea removeFromSuperview];
        
//        
        [self removeAllLabelLayers];
        
    }
}

-(void)tapView:(UITapGestureRecognizer *)sender{
    //设置轻拍事件改变testView的颜色
    correctArea.backgroundColor = [UIColor colorWithRed:arc4random()%256/255.0 green:arc4random()%256/255.0 blue:arc4random()%256/255.0 alpha:0.2];
    NSLog(@"why no color?");
    [self speak:@"Yeah! You are so smart."];
}

- (void)setupAVCapture {
    NSError *error = nil;
    
    session = [AVCaptureSession new];
    session.sessionPreset = AVCaptureSessionPreset640x480;

    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    [session addInput:input];
   
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
    
    [session addOutput:videoDataOutput];
    
    [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
    
    previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    CGRect layerRect = CGRectMake(0, marginT, frameWidth,frameHeight );
    [previewLayer setFrame:layerRect];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];

    [previewView.layer addSublayer:previewLayer];
    
    CGRect drawRect = CGRectMake(0, marginT, 414,600 );
    [drawView setFrame:drawRect];
  
  
    
    
    
}

- (void)teardownAVCapture {
  [stillImageOutput removeObserver:self forKeyPath:@"isCapturingStillImage"];
  [previewLayer removeFromSuperlayer];
}

//Orientation--future work

//- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation:
//    (UIDeviceOrientation)deviceOrientation {
//  AVCaptureVideoOrientation result =
//      (AVCaptureVideoOrientation)(deviceOrientation);
//  if (deviceOrientation == UIDeviceOrientationLandscapeLeft)
//    result = AVCaptureVideoOrientationLandscapeRight;
//  else if (deviceOrientation == UIDeviceOrientationLandscapeRight)
//    result = AVCaptureVideoOrientationLandscapeLeft;
//  return result;
//}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
    fromConnection:(AVCaptureConnection *)connection {
    if (freezeBtn==false){
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CFRetain(pixelBuffer);
        [self prepareModel:pixelBuffer];
        CFRelease(pixelBuffer);
    }else{
        [session stopRunning];
    }
}


// transform to tensor and run
- (void)prepareModel:(CVPixelBufferRef)pixelBuffer {
 

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
    // portrait
    if (fullHeight <= image_width) {
        image_height = fullHeight;
        sourceStartAddr = sourceBaseAddr;
    } else {
        // landscape
        image_height = image_width;
        const int marginY = ((fullHeight - image_width) / 2);
        sourceStartAddr = (sourceBaseAddr + (marginY * sourceRowBytes));
    }
    const int image_channels = 4;
    
//    assert(image_channels >= wanted_input_channels);
    
    tensorflow::Tensor image_tensor(
                                    tensorflow::DT_UINT8,
                                    tensorflow::TensorShape(
                                                            {1, wanted_input_height, wanted_input_width, wanted_input_channels}));
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
    tensorflow::Status run_status = tf_session->Run(
        {{"image_tensor", image_tensor}}, {"detection_boxes", "detection_scores", "detection_classes", "num_detections"}, {}, &outputs);
      predictedX=-1;
      predictedY=-1;
      predictedW=-1;
      predictedH=-1;
      predictedID=-1;
//      wordsToSay=nil;
    if (!run_status.ok()) {
      LOG(ERROR) << "Running model failed:" << run_status;
    } else {

        ////        打印model运行时间
        double b = CFAbsoluteTimeGetCurrent();
        unsigned int m = ((b-a) * 1000.0f); // convert from seconds to milliseconds
        NSLog(@"%@: %d ms", @"Run Model Time taken", m);
        
//       开始print的准备工作
        std::vector<float> boxScore;
        std::vector<float> boxRect;
        std::vector<std::string> boxName;
//        predictedRect.clear();
//        predictedName.clear();
        
        std::vector<float> locations;
        
        tensorflow::TTypes<float>::Flat scores_flat = outputs[1].flat<float>();
        tensorflow::Tensor &indices = outputs[2];
        tensorflow::TTypes<float>::Flat indices_flat = indices.flat<float>();
       
        
        const tensorflow::Tensor& encoded_locations = outputs[0];
        auto locations_encoded = encoded_locations.flat<float>();
        
        
//    filter the predictions by thredhold 0.25
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
            
            LOG(INFO) << "Detection "  << " score: " << score
            << " Detected Name: " << displayName
            << " Detected label number: " << label_index;;
            
            boxScore.push_back(score);
            boxName.push_back(displayName);
            boxRect.push_back(ymin); boxRect.push_back(xmin); boxRect.push_back(ymax); boxRect.push_back(xmax);
            
        }
        
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        [self removeAllLabelLayers];
        int labelCount = 0;
        
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
            
//            predictedRect.push_back(originX);predictedRect.push_back(originY);predictedRect.push_back(labelWidth);predictedRect.push_back(labelHeight);
//            predictedName.push_back(boxName.at(i).c_str());
            
//
            if ((labelCount == 0) && (boxScore.at(i) > 0.5f)) {
            
                wordsToSay=[NSString stringWithFormat:@"There is a %@. Guess where it is?", labelName];
                predictedX=originX;
                predictedY=originY;
                predictedW=labelWidth;
                predictedH=labelHeight;
//                predictedID=i;
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


//删除所有的文字
- (void)removeAllLabelLayers {
    for (CATextLayer *layer in labelLayers) {
        [layer removeFromSuperlayer];
    }
    [labelLayers removeAllObjects];
}
- (void)addLabelLayerWithText:(NSString *)text
                      originX:(float)originX
                      originY:(float)originY
                        width:(float)width
                       height:(float)height
                    alignment:(NSString *)alignment {
    CFTypeRef font = (CFTypeRef) @"Menlo-Regular";
    const float fontSize = 10.0f;
    
    const float marginSizeX = 5.0f;
    const float marginSizeY = 2.0f;
    
    CGRect backgroundBounds = CGRectMake(originX, originY, width, height);
    
    CGRect textBounds =
    CGRectMake((originX + marginSizeX), (originY - 5*marginSizeY),
               (width - (marginSizeX * 2)), (height - (marginSizeY * 2)));
    
    
    CATextLayer *background = [CATextLayer layer];
    [background setBackgroundColor:[UIColor clearColor].CGColor];
    [background setBorderColor:[UIColor blackColor].CGColor];
    [background setBorderWidth:2];
    [background setFrame:backgroundBounds];
//    background.cornerRadius = 5.0f;
    
    [[drawView layer] addSublayer:background];
    [labelLayers addObject:background];
    
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

- (void)speak:(NSString *)words {
  if ([synth isSpeaking]) {
    return;
  }
  AVSpeechUtterance *utterance =
      [AVSpeechUtterance speechUtteranceWithString:words];
//    NSLog(@"words:%@",words);
  utterance.voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"en-US"];
  utterance.rate = 1 * AVSpeechUtteranceDefaultSpeechRate;
    
  [synth speakUtterance:utterance];
    
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    //  square = [UIImage imageNamed:@"squarePNG"];
    //    set up captured image array
    self.capturedImages = [[NSMutableArray alloc] init];
    self.runStopBtn.hidden=YES;
    self.runButton.hidden=YES;
    [self setupAVCapture];
    
    //    split
    synth = [[AVSpeechSynthesizer alloc] init];
    labelLayers = [[NSMutableArray alloc] init];
    oldPredictionValues = [[NSMutableDictionary alloc] init];
    
    tensorflow::Status load_status;
    load_status = LoadModel(model_file_name, model_file_type, &tf_session);
    
    if (!load_status.ok()) {
        LOG(FATAL) << "Couldn't load model: " << load_status;
    }
    
    tensorflow::Status labels_status =
    LoadLabels(labels_file_name, labels_file_type, &labels);
    if (!labels_status.ok()) {
        LOG(FATAL) << "Couldn't load labels: " << labels_status;
    }
    
    
    
    [self setupAVCapture];
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
