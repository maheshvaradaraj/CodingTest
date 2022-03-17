//
//  CaptureVideoPreviewLayerDelegate.h
//  DocumentCropper
//
//  Created by Denis Silko on 1/22/19.
//  Copyright © 2019 Paycasso. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DocumentCropper/DocumentCropper.h>

NS_ASSUME_NONNULL_BEGIN

@protocol CaptureVideoPreviewLayerDelegate <NSObject>

@optional
- (void)documentCaptureIsComplete;

@end

@protocol CaptureVideoPreviewLayerInterface <NSObject>

@property (weak, nonatomic) id <CaptureVideoPreviewLayerDelegate> delegateController;
@property (assign, nonatomic) dc::ExpectedDocument expectedDocument;
@property (strong, nonatomic) UIImage *document;

- (void)showDocument:(cv::Mat)src points:(std::vector<cv::Point>)points;
- (void)showWithRedQuadranglePoints:(std::vector<cv::Point>)points expectedDocument:(dc::ExpectedDocument)expectedDocument;
- (void)showWithYellowQuadranglePoints:(std::vector<cv::Point>)points expectedDocument:(dc::ExpectedDocument)expectedDocument;
- (void)showWithGreenQuadranglePoints:(std::vector<cv::Point>)points expectedDocument:(dc::ExpectedDocument)expectedDocument;
- (void)showWithQuadranglePoints:(std::vector<cv::Point>)points color:(UIColor *)color expectedDocument:(dc::ExpectedDocument)expectedDocument;
- (void)clean;
- (void)reset;
- (void)stopAnimation;
- (void)startAnimation;
- (UIImage *)exportDocumentImage;

- (CGImageRef)CGImageFromCVMat:(cv::Mat)cvMat;

@end

NS_ASSUME_NONNULL_END

