//
//  PCSImageConverter.h
//  PaycassoVerifyVision
//
//  Created by Denis on 20.01.17.
//  Copyright © 2017 Paycasso Verify. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "opencv2/imgproc/imgproc.hpp"

@interface PCSImageConverter : NSObject

+ (CGImageRef)CGImageFromCVMat:(cv::Mat)cvMat;
+ (CIImage *)CIImageFromMat:(cv::Mat)mat;
+ (cv::Mat)matFromSampleBuffer:(CMSampleBufferRef)buffer;
+ (NSString *)base64StringFromMat:(cv::Mat)mat withCompressionQuality:(CGFloat)quality;
+ (NSData *)dataFromMat:(cv::Mat)mat withCompressionQuality:(CGFloat)quality;
+ (NSString *)base64StringFromImage:(UIImage *)image withCompressionQuality:(CGFloat)quality;
+ (NSString *)base64StringFromMat:(cv::Mat)mat;
+ (NSString *)base64StringFromImage:(UIImage *)image;

@end



