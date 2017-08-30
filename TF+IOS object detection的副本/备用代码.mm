//        //displaying running result
//        CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
//        int bytes_per_row = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
//        
//        const int bits_per_component = 8;
//        
//        CGContextRef context = CGBitmapContextCreate(pixelBuffer, image_width, image_height,
//                                                     bits_per_component, bytes_per_row, color_space,
//                                                     kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
//        CGColorSpaceRelease(color_space);
//        
//        //draw deteced box, write detected name and score
//        //if no transform, the text will be rotated
//        CGAffineTransform normalState=CGContextGetCTM(context);
//        CGContextTranslateCTM(context, 0, image_height);
//        CGContextScaleCTM(context, 1, -1);
//        
//        
//        UIGraphicsPushContext(context);
//        
//        for(int i=0; i<boxName.size(); i++)
//        {
//            //draw text
//            NSString *detectedName = [NSString stringWithFormat:@"%s %5.3f", boxName.at(i).c_str(), boxScore.at(i)];
//            UIColor *textColor =[UIColor colorWithRed:0.1f green:0.1f blue:1.0f alpha:1.0f];
//            UIFont *helveticaBold = [UIFont fontWithName:@"HelveticaNeue" size:15.0f];
//            NSDictionary *dicAttribute = @{NSFontAttributeName:helveticaBold, NSForegroundColorAttributeName:textColor};
//            float l = boxRect.at(i*4+0);
//            float t = boxRect.at(i*4+1);
//            float r = boxRect.at(i*4+2);
//            float b = boxRect.at(i*4+3);
//            
//            CGRect textRect = CGRectMake(l, t-20>0 ? t-20 : 10, 100, 30);
//            CGRect drawRect = CGRectMake(l, t, r-l, b-t);
//            [detectedName drawWithRect:textRect options:NSStringDrawingUsesLineFragmentOrigin
//                            attributes:dicAttribute context:nil];
//            
//            //draw rect
//            CGContextSetRGBStrokeColor(context, 0.18, 0.72, 0.95, 0.95);//rect color
//            CGContextSetLineWidth(context, 2.0);
//            CGContextAddRect(context, drawRect);
//            CGContextStrokePath(context);
//            
//        }
//        
//        
//        UIGraphicsPopContext();
//        CGContextConcatCTM(context, normalState);
//        
//        
//        
//        CGImageRef toCGImage = CGBitmapContextCreateImage(context);
//        UIImage * image = [[UIImage alloc] initWithCGImage:toCGImage];
//        
//        //for test: write image to disk for simulator running
//        //    NSData * png = UIImagePNGRepresentation(image);
//        //    NSString *file_str=@"/Users/hejie/Desktop/ios_result.png";
//        //
//        //    [png writeToFile: file_str atomically:YES];
//        
//        //displaying detected result
//        CGFloat imageView_X = (image.size.width > self.view.frame.size.width) ? self.view.frame.size.width : image.size.width;
//        CGFloat imageView_Y = 0.0f;
//        CGFloat origin;
//        
//        if(image.size.width > self.view.frame.size.width){
//            origin = self.view.frame.size.width/image.size.width;
//            imageView_Y = image.size.height*origin;
//        }
//        
//        UIImageView *imgView1 = [[UIImageView alloc]initWithFrame:CGRectMake((self.view.frame.size.width-imageView_X)/2,
//                                                                             (self.view.frame.size.height-imageView_Y)/2,
//                                                                             imageView_X, imageView_Y)];
//        
//        
//        [imgView1 setImage:image];
//        imgView1.contentMode =  UIViewContentModeScaleAspectFit;
//        
//        [self.view addSubview:imgView1];
//        
//        
//        CGContextRelease(context);
//        CFRelease(toCGImage);
//       
//
        
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        CGFloat viewWidth = 200;
        CGFloat viewHeight = 200;
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake((screenSize.width - viewWidth)/2, (screenSize.height - viewHeight) / 2, viewWidth, viewHeight)];
        view.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1];
        view.layer.cornerRadius = CGRectGetWidth(view.bounds)/2;
        CAShapeLayer *borderLayer = [CAShapeLayer layer];
        borderLayer.bounds = CGRectMake(0, 0, viewWidth, viewHeight);
        borderLayer.position = CGPointMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds));
        
        //    borderLayer.path = [UIBezierPath bezierPathWithRect:borderLayer.bounds].CGPath;
        borderLayer.path = [UIBezierPath bezierPathWithRoundedRect:borderLayer.bounds cornerRadius:CGRectGetWidth(borderLayer.bounds)/2].CGPath;
        borderLayer.lineWidth = 1. / [[UIScreen mainScreen] scale];
        //虚线边框
        borderLayer.lineDashPattern = @[@8, @8];
        //实线边框
        //    borderLayer.lineDashPattern = nil;
        borderLayer.fillColor = [UIColor clearColor].CGColor;
        borderLayer.strokeColor = [UIColor redColor].CGColor;
        [view.layer addSublayer:borderLayer];
        
        [self.view addSubview:view];
        [self.view bringSubviewToFront:view];
//        UIView* drawView=[[UIView alloc] initWithFrame:[previewView frame]];
//
//        UIGraphicsBeginImageContextWithOptions(CGSizeMake(400, 400), NO , 1);
////        UIGraphicsPushContext();
//        drawView = [[UIView alloc] initWithFrame:[previewView frame]];
//        for(int i=0; i<boxName.size(); i++){
//            
//            float l = boxRect.at(i*4+0);
//            float t = boxRect.at(i*4+1);
//            float r = boxRect.at(i*4+2);
//            float b = boxRect.at(i*4+3);
//            
//            CGContextRef ctx = UIGraphicsGetCurrentContext();
//            CGContextSetRGBStrokeColor(ctx, 0.18, 0.72, 0.95, 0.95);//rect color
//            CGContextSetLineWidth(ctx, 2.0);
//            CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.8);
//            CGContextAddEllipseInRect(ctx, CGRectMake(0, 0, 100, 100));
//            CGContextStrokePath(ctx);
//            
////            CGRect myRect = CGRectMake(l, t, r-t, b-t);
////            [self drawRect:myRect originX:l originY:t width:r-t height:b-t];
////
//            
//            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
//            drawView.backgroundColor = [UIColor colorWithPatternImage:image];
//            
//            
////
////            NSLog(@"x:%f",myRect.origin.x);
////            NSLog(@"y:%f",myRect.origin.y);
////            NSLog(@"w:%f",myRect.size.width);
////            NSLog(@"h:%f",myRect.size.height);
////            CALayer *myLayer;
//////            CALayer *myLayer = [drawView layer];
////            [myLayer setBounds:myRect];
////            [myLayer setBorderColor:[[UIColor redColor] CGColor]];
////            [myLayer setBorderWidth:20.0f];
////            [drawView.layer addSublayer:myLayer];
//////            CALayer *myLayer = [drawView layer];
////            
////            
//////            [myLayer setBorderColor:[[UIColor redColor] CGColor]];
//////            [myLayer setBorderWidth:20.0f];
//////            [previewView.layer addSublayer:myLayer];
//////            [previewView.layer :myLayer];
//            
//        }
//      UIGraphicsEndImageContext();
//        [previewView addSubview:drawView];





               CGRect drawRect = CGRectMake(originX, originY, width, height);
//    属性设定
   CGFloat innerWidth = 2;
   CGContextSetLineWidth(ctx, innerWidth);
   CGContextSetRGBStrokeColor(ctx, 0.18, 0.72, 0.95, 0.95);//rect color
//    [[UIColor redColor] setStroke];
   CGContextAddRect(ctx, drawRect);
   
   
   // Stroke the path
   CGContextStrokePath(ctx);
