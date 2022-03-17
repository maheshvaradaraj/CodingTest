//
//  LCCamera.h
//  PaycassoVerifyVision
//
//  Created by Denis on 16.01.17.
//  Copyright © 2017 Paycasso Verify. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "opencv2/imgproc/imgproc.hpp"

@class PCSCamera;

@protocol PCSCameraDelegate <NSObject>

@optional
- (void)frame:(cv::Mat &)src isStable:(BOOL)isStable fromCamera:(PCSCamera *)camera;

@end


@interface PCSCamera : NSObject

@property (assign, nonatomic) BOOL debugMode;

@property (weak, nonatomic) id <PCSCameraDelegate> delegate;
@property (weak, nonatomic) CALayer *proccessLayer;
@property (assign, nonatomic) AVCaptureDevicePosition devicePosition;
@property (strong, nonatomic) AVCaptureSession *session;


+ (PCSCamera *)cameraWithDelegate:(id <PCSCameraDelegate>)delegate;

- (void)start;
- (void)stop;
- (void)switchCamera;

@end




