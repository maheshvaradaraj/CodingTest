//
//  LCCamera.m
//  PaycassoVerifyVision
//
//  Created by Denis on 16.01.17.
//  Copyright © 2017 Paycasso Verify. All rights reserved.
//

#import "PCSCamera.h"
#import <UIKit/UIKit.h>
#import "opencv2/imgcodecs/ios.h"
#import "opencv2/core/version.hpp"

using namespace cv;

@interface PCSCamera () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (strong, nonatomic) AVCaptureVideoDataOutput *output;
@property (weak, nonatomic) AVCaptureDeviceInput *input;
@property (weak, nonatomic) AVCaptureDevice *device;
@property (weak, nonatomic) NSTimer *refocusTimer;

@end

@implementation PCSCamera

NSInteger               const refocusTimeInterval = 2;
CGPoint                 const defaultFocusPointOfInterest = CGPointMake(0.5f, 0.5f);
NSString               *const defaultCaptureSessionPreset = AVCaptureSessionPreset1920x1080;
AVCaptureDevicePosition const defaultDevicePosition = AVCaptureDevicePositionBack;

+ (PCSCamera *)cameraWithDelegate:(id <PCSCameraDelegate>)delegate {
    return [[self alloc] initWithDelegate:delegate];
}

- (instancetype)initWithDelegate:(id <PCSCameraDelegate>)delegate {
    if (self = [super init]) {
        self.delegate = delegate;
        self.session = [[AVCaptureSession alloc] init];
        self.session.sessionPreset = defaultCaptureSessionPreset;
        self.devicePosition = defaultDevicePosition;
        self.device = [self deviceWithPosition:self.devicePosition];
        self.input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
        [self.session addInput:self.input];
        
        self.output = [AVCaptureVideoDataOutput new];
        self.output.alwaysDiscardsLateVideoFrames = YES;
        self.output.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]};
        [self.output setSampleBufferDelegate:self queue:dispatch_queue_create("VideoCaptureQueue", DISPATCH_QUEUE_SERIAL)];
        
        [self.session addOutput:self.output];
        
        self.debugMode = NO;
    }
    
    return self;
}

- (void)setProccessLayer:(CALayer *)proccessLayer {
    _proccessLayer = proccessLayer;
    
    float ar = 0.0;
    if (self.session.sessionPreset == AVCaptureSessionPreset1920x1080) {
        ar = 1920.0 / 1080.0;
    }
    
    CGRect frame = _proccessLayer.frame;
    
    // Landscape src for portraite view
    _proccessLayer.bounds = CGRectMake(0, 0, frame.size.width * ar, frame.size.width);
    _proccessLayer.contentsGravity = kCAGravityResize;
    _proccessLayer.affineTransform = CGAffineTransformMakeRotation(M_PI / 2);
    
    // Portraite src for portraite view
//    _proccessLayer.bounds = CGRectMake(0, 0, frame.size.width, frame.size.width * ar);
//    _proccessLayer.contentsGravity = kCAGravityResize;

}

- (void)setDebugMode:(BOOL)debugMode {
    if (debugMode) {
        if (self.proccessLayer) {
            _debugMode = debugMode;
        }
    } else {
        _debugMode = debugMode;
    }
}

#pragma mark - Main functionality

- (void)start {
    if (![_session isRunning]) {
        [self refocus];
        
        _refocusTimer = [NSTimer scheduledTimerWithTimeInterval:refocusTimeInterval target:self selector:@selector(refocus) userInfo:nil repeats:YES];
        [_session startRunning];
    }
}

- (void)stop {
    [_refocusTimer invalidate];
    [_session stopRunning];
}

- (void)switchCamera {
    self.devicePosition = _devicePosition == AVCaptureDevicePositionBack ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    BOOL isStableFrame = ![self.device isAdjustingFocus] && ![self.device isAdjustingExposure] && ![self.device isAdjustingWhiteBalance];
    
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    int bufferWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
    int bufferHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
    unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
    
    Mat frame = cv::Mat(bufferHeight, bufferWidth, CV_8UC4, pixel);
    
    // Rotate lanscape mat to portraite
//    transpose(frame, frame);
//    flip(frame, frame, 1);
    
    [_delegate frame:frame isStable:isStableFrame fromCamera:self];
    
    if (self.debugMode) {
        CGImageRef imageRef = [self CGImageFromCVMat:frame];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.proccessLayer.contents = (__bridge id)imageRef;
        });
        
        CGImageRelease(imageRef);
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

- (CGImageRef)CGImageFromCVMat:(Mat)cvMat {
    if (cvMat.elemSize() == 4) {
        cv::cvtColor(cvMat, cvMat, COLOR_BGRA2RGBA);
    }
    
    if (cvMat.elemSize() == 3) {
        cv::cvtColor(cvMat, cvMat, COLOR_BGR2RGB);
    }
    
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                              //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNoneSkipLast|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return imageRef;
}

#pragma mark - NSTimer selectors

- (void)refocus {
    if ([self.device lockForConfiguration:nil]) {
        if ([self.device isFocusPointOfInterestSupported]) {
            self.device.focusPointOfInterest = defaultFocusPointOfInterest;
        }
        
        if ([self.device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            self.device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        }
        
        [self.device unlockForConfiguration];
    }
}

#pragma mark - 

- (AVCaptureDevice *)deviceWithPosition:(AVCaptureDevicePosition)position {
    NSArray *devices;
    
    AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession
                                                         discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                                                         mediaType:AVMediaTypeVideo
                                                         position:position];
    devices = [discoverySession devices];
    
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    
    return nil;
}

- (void)setDevicePosition:(AVCaptureDevicePosition)devicePosition {
    _devicePosition = devicePosition;
    
    if (self.input) {
        BOOL isRunning = self.session.isRunning;
        
        if (isRunning) {
            [self stop];
            [self.session stopRunning];
        }
        
        [self.session removeInput:self.input];
        
        switch (devicePosition) {
            case AVCaptureDevicePositionBack:
                self.session.sessionPreset = AVCaptureSessionPreset1920x1080;
                break;
                
            case AVCaptureDevicePositionFront:
                self.session.sessionPreset = AVCaptureSessionPreset1280x720;
                break;
                
            default:
                self.session.sessionPreset = defaultCaptureSessionPreset;
                break;
        }
        
        self.device = [self deviceWithPosition:devicePosition];
        self.input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
        [self.session addInput:self.input];
        [self.session commitConfiguration];
        
        [self refocus];
        
        if (isRunning) {
            [self.session startRunning];
            [self start];
        }
    }
}

@end


