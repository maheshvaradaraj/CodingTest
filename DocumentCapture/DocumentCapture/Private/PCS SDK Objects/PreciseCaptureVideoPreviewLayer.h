//
//  PreciseCaptureVideoPreviewLayer.h
//  Paycasso
//
//  Created by Denis on 22.01.19.
//  Copyright © 2017 Paycasso Verify. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "CaptureVideoPreviewLayerDelegate.h"
#import <DocumentCropper/DocumentCropper.h>

@interface PreciseCaptureVideoPreviewLayer : AVCaptureVideoPreviewLayer <CaptureVideoPreviewLayerInterface>

@property (strong, nonatomic) UIImage *previewImage;
@property (strong, nonatomic) UIColor *previewColor;

+ (PreciseCaptureVideoPreviewLayer *)layerWithSession:(AVCaptureSession *)session frame:(CGRect)frame;

- (void)reset;

@end
//#endif


