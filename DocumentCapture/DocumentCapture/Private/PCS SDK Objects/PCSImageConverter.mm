//
//  PCSImageConverter.m
//  PaycassoVerifyVision
//
//  Created by Denis on 20.01.17.
//  Copyright © 2017 Paycasso Verify. All rights reserved.
//

#import "PCSImageConverter.h"
#import "opencv2/imgcodecs/ios.h"
#import <CoreImage/CoreImage.h>

@implementation PCSImageConverter

using namespace cv;

+ (CGImageRef)CGImageFromCVMat:(cv::Mat)cvMat {
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

+ (cv::Mat)matFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    //Processing here
    int bufferWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
    int bufferHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
    unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
    
    // put buffer in open cv, no memory copied
    cv::Mat mat = cv::Mat(bufferHeight, bufferWidth, CV_8UC4, pixel);
    
    //End processing
    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
    
    return mat;
}

+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    //UIGraphicsBeginImageContext(newSize);
    // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
    // Pass 1.0 to force exact pixel size.
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

+ (NSString *)base64StringFromImage:(UIImage *)image withCompressionQuality:(CGFloat)quality {
    CGSize size = image.size;
    size.width /= 3.0;
    size.height /= 3.0;
    
    NSData *theData = UIImageJPEGRepresentation([self imageWithImage:image scaledToSize:size], quality);
    
    NSString *base = [theData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    
   return base;
}

+ (UIImage *)decodeBase64ToImage:(NSString *)strEncodeData {
  NSData *data = [[NSData alloc]initWithBase64EncodedString:strEncodeData options:NSDataBase64DecodingIgnoreUnknownCharacters];
  return [UIImage imageWithData:data];
}

+ (NSString *)base64StringFromMat:(cv::Mat)mat withCompressionQuality:(CGFloat)quality  {
    return [PCSImageConverter base64StringFromImage:MatToUIImage(mat) withCompressionQuality:quality];
}

+ (NSData *)dataFromMat:(cv::Mat)mat withCompressionQuality:(CGFloat)quality {
    UIImage *image = MatToUIImage(mat);
    CGSize size = image.size;
    size.width /= 3.0;
    size.height /= 3.0;

    return UIImageJPEGRepresentation([self imageWithImage:image scaledToSize:size], quality);
//    return UIImagePNGRepresentation(image);
//    return UIImageJPEGRepresentation(MatToUIImage(mat), quality);
}

+ (NSString *)base64StringFromMat:(cv::Mat)mat {
    return [PCSImageConverter base64StringFromImage:MatToUIImage(mat)];
}

+ (NSString *)base64StringFromImage:(UIImage *)image {
    NSData *theData = UIImagePNGRepresentation(image);
    
    const uint8_t* input = (const uint8_t*)[theData bytes];
    NSInteger length = [theData length];
    
    static char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
    
    NSMutableData* data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
    uint8_t* output = (uint8_t*)data.mutableBytes;
    
    NSInteger i;
    for (i=0; i < length; i += 3) {
        NSInteger value = 0;
        NSInteger j;
        for (j = i; j < (i + 3); j++) {
            value <<= 8;
            
            if (j < length) {
                value |= (0xFF & input[j]);
            }
        }
        
        NSInteger theIndex = (i / 3) * 4;
        output[theIndex + 0] =                    table[(value >> 18) & 0x3F];
        output[theIndex + 1] =                    table[(value >> 12) & 0x3F];
        output[theIndex + 2] = (i + 1) < length ? table[(value >> 6)  & 0x3F] : '=';
        output[theIndex + 3] = (i + 2) < length ? table[(value >> 0)  & 0x3F] : '=';
    }
    
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}


+ (CIImage *)CIImageFromMat:(cv::Mat)mat {
    NSData *data = [NSData dataWithBytes:mat.data length:mat.elemSize()*mat.total()];
    
    CGColorSpaceRef colorSpace;
    CGBitmapInfo bitmapInfo;
    
    if (mat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
        bitmapInfo = kCGImageAlphaNone | kCGBitmapByteOrderDefault;
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
        bitmapInfo = kCGBitmapByteOrder32Little | (mat.elemSize() == 3? kCGImageAlphaNone : kCGImageAlphaNoneSkipFirst);
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    CGImageRef imageRef = CGImageCreate(
                                        mat.cols,                   //width
                                        mat.rows,                   //height
                                        8,                          //bits per component
                                        8 * mat.elemSize(),         //bits per pixel
                                        mat.step[0],                //bytesPerRow
                                        colorSpace,                 //colorspace
                                        bitmapInfo,                 // bitmap info
                                        provider,                   //CGDataProviderRef
                                        NULL,                       //decode
                                        false,                      //should interpolate
                                        kCGRenderingIntentDefault   //intent
                                        );
    
    CIImage *finalImage = [CIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

@end


