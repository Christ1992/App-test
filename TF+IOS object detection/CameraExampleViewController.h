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

//import framework
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UIKit.h>

#include <memory>
#include "tensorflow/core/public/session.h"
#include "tensorflow/core/util/memmapped_file_system.h"

@interface CameraExampleViewController
    : UIViewController<UIGestureRecognizerDelegate,
                       AVCaptureVideoDataOutputSampleBufferDelegate,UINavigationControllerDelegate, UIImagePickerControllerDelegate> {
  IBOutlet UIView *previewView;
  IBOutlet UIImageView *imageView;
  IBOutlet UITextView *textView;
  __weak IBOutlet UIView *drawView;
  AVCaptureVideoPreviewLayer *previewLayer;
   __weak IBOutlet UIImageView *boundView;
  UIView *flashView;
  UIView* correctArea;
                           
  AVCaptureVideoDataOutput *videoDataOutput;
  dispatch_queue_t videoDataOutputQueue;
  AVCaptureStillImageOutput *stillImageOutput;
  
  AVSpeechSynthesizer *synth;
  
  NSMutableArray *labelLayers;
  AVCaptureSession *session;
  std::unique_ptr<tensorflow::Session> tf_session;
  std::vector<std::string> labels;
                           
}
@property(strong, nonatomic) CATextLayer *predictionTextLayer;
@property (weak, nonatomic) IBOutlet UIButton *runStopBtn;
@property (weak, nonatomic) IBOutlet UIButton *runButton;

@property (nonatomic) UIImagePickerController *imagePickerController;
@property (nonatomic) NSMutableArray *capturedImages;

@property (nonatomic) CFURLRef soundFileURLRef;
@property (nonatomic) SystemSoundID soundFileObject;


@end
