//
//  LenseCaptureVideoPreviewLayerr.h
//  Paycasso
//
//  Created by Denis on 22.01.19.
//  Copyright © 2017 Paycasso Verify. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <CaptureVideoPreviewLayerDelegate.h>

@interface LenseCaptureVideoPreviewLayer : AVCaptureVideoPreviewLayer <CaptureVideoPreviewLayerInterface>

+ (LenseCaptureVideoPreviewLayer *)layerWithSession:(AVCaptureSession *)session frame:(CGRect)frame;

- (void)reset;

@end


