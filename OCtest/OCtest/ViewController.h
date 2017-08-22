//
//  ViewController.h
//  OCtest
//
//  Created by yingjie on 2017/8/22.
//  Copyright © 2017年 yingjie. All rights reserved.
//

#import <UIKit/UIKit.h>
@import AVFoundation;

@interface ViewController : UIViewController<UIGestureRecognizerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>{
    
    
    __weak IBOutlet UIImageView *previewView;
    AVCaptureVideoPreviewLayer *previewLayer;
    AVCaptureVideoDataOutput *videoDataOutput;
    dispatch_queue_t videoDataOutputQueue;
    AVCaptureStillImageOutput *stillImageOutput;
    AVSpeechSynthesizer *synth;
    AVCaptureSession *session;
    UIView *flashView;
}


@end

