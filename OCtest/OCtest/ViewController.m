//
//  ViewController.m
//  OCtest
//
//  Created by yingjie on 2017/8/22.
//  Copyright © 2017年 yingjie. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end

@implementation ViewController


- (IBAction)StartCam:(id)sender {
    //    start + end the cam
    //    didn't show until touch TakePic button
}

- (IBAction)PhotoLib:(id)sender {
//import a pic
//hide the cam button [subview setHidden:true];
}
- (IBAction)TakePic:(id)sender {
//    use the pic
//    show the cam button [subview setHidden:false];
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}





- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
