//
//  PCSDocumentCaptureViewController.m
//  DocumentCapture
//
//  Created by Denis Silko on 12.12.2021.
//

#import "PCSDocumentCaptureViewController.h"
#import "PCSCamera.h"
#import "PCSImageConverter.h"
#import "LenseCaptureVideoPreviewLayer.h"
#import "PreciseCaptureVideoPreviewLayer.h"
#import <DocumentCropper/DocumentCropper.h>
#include <opencv2/imgcodecs/ios.h>
#include <opencv2/imgproc/imgproc.hpp>

@interface PCSDocumentCaptureViewController () <PCSCameraDelegate, CaptureVideoPreviewLayerDelegate>

// Device
@property (strong, nonatomic) PCSCamera *camera;

// View
@property (strong, nonatomic) UIView *cameraView;
@property (weak,   nonatomic) AVCaptureVideoPreviewLayer <CaptureVideoPreviewLayerInterface> *videoPreviewLayer;

// Computer vision
@property (assign, nonatomic) dc::DocumentCatcher documentCatcher;
@property (assign, nonatomic) dc::DocumentDetector documentDetector;

// Model
@property (assign, nonatomic) dc::ExpectedDocument expectedDocument;
@property (assign, nonatomic) BOOL canCapture, canCaptureDocument, isFirstDocumentDetect;
@property (weak, nonatomic) NSTimer *wholeScreenCaptureTimer;
@property (strong, nonatomic) UIImpactFeedbackGenerator *impactFeedbackGenerator;

@end


@implementation PCSDocumentCaptureViewController

NSTimeInterval const wholeScreenTimeInterval = 3.0;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _impactFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];

    _camera = [PCSCamera cameraWithDelegate:self];
    _cameraView = [[UIView alloc] initWithFrame:self.view.frame];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *cascadePath = [bundle pathForResource:@"haarcascade_frontalface_alt2" ofType:@"xml"];
    self.documentDetector = dc::DocumentDetector(true);
    self.documentCatcher = dc::DocumentCatcher([cascadePath UTF8String]);
    
    [self resetCaptureSession];
    
    [self.view addSubview:_cameraView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (_previewColor) {
        _videoPreviewLayer = [PreciseCaptureVideoPreviewLayer layerWithSession:_camera.session frame:self.view.frame];
        [(PreciseCaptureVideoPreviewLayer *)_videoPreviewLayer setPreviewColor:_previewColor];
    } else if (_previewImage) {
        _videoPreviewLayer = [PreciseCaptureVideoPreviewLayer layerWithSession:_camera.session frame:self.view.frame];
        [(PreciseCaptureVideoPreviewLayer *)_videoPreviewLayer setPreviewImage:_previewImage];
    } else {
        _videoPreviewLayer = [LenseCaptureVideoPreviewLayer layerWithSession:_camera.session frame:self.view.frame];
    }
    
    [_videoPreviewLayer reset];
    _videoPreviewLayer.delegateController = self;
    [_cameraView.layer addSublayer:_videoPreviewLayer];
    
    [self resetCaptureSession];
}

- (void)disableWholeScreenCapture {}

- (void)viewWillDisappear:(BOOL)animated {
    _canCapture = NO;
    [_camera stop];
    
    [super viewWillDisappear:animated];
    
    if (_videoPreviewLayer) {
        [_videoPreviewLayer stopAnimation];
        [_videoPreviewLayer removeFromSuperlayer];
        _videoPreviewLayer = nil;
    }
}

// MARK: - Public1

- (void)setDocumentType:(PCSDocumentType)documentType {
    _documentType = documentType;
    
    switch (_documentType) {
        case PCSDocumentType::PASSPORT:
            _expectedDocument = dc::PASSPORT;
            break;
            
        case PCSDocumentType::ID:
            _expectedDocument = dc::ID;
            break;
            
        case PCSDocumentType::GREEN_BOOK:
            _expectedDocument = dc::GREEN_BOOK;
            break;
            
        default:
            break;
    }
}

- (void)reset {
    [self resetCaptureSession];
}

// MARK: - Private

- (void)resetCaptureSession {
    if (_documentType == PCSDocumentType::WHOLE_SCREEN) {
        [_wholeScreenCaptureTimer invalidate];
        _wholeScreenCaptureTimer = [NSTimer scheduledTimerWithTimeInterval:wholeScreenTimeInterval
                                                                    target:self
                                                                  selector:@selector(disableWholeScreenCapture)
                                                                  userInfo:nil
                                                                   repeats:NO];
    }
    
    [_videoPreviewLayer reset];
    _documentCatcher.reset();
    _documentDetector.reset();
    _canCapture = YES;
    _isFirstDocumentDetect = NO;
    [_camera start];
}

// MARK: - CaptureVideoPreviewLayerDelegate

- (void)documentCaptureIsComplete {
    if (_delegate) {
        [_delegate didCaptureDocument:_videoPreviewLayer.exportDocumentImage];
    }
}

- (void)didFirstDocumentDetect {
    if (_delegate) {
        [_delegate didFirstDocumentDetect];
    }
}

// MARK: - PCSCameraDelegate

- (void)frame:(cv::Mat &)frame isStable:(BOOL)isStable fromCamera:(PCSCamera *)camera {
    if (!self.canCapture) {
        return;
    }
    
    if (_documentType == PCSDocumentType::WHOLE_SCREEN) {
        if (isStable && ![_wholeScreenCaptureTimer isValid]) {
            transpose(frame, frame);
            flip(frame, frame, 1);
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                [_camera stop];
                [self.impactFeedbackGenerator impactOccurred];
                self.canCapture = NO;
                
                
                CGImageRef imageRef = [PCSImageConverter CGImageFromCVMat:frame];
                
                if (_delegate) {
                    [_delegate willCaptureDocument];
                    [_delegate didCaptureDocument:[UIImage imageWithCGImage:imageRef]];
                }
                
                CGImageRelease(imageRef);
            });
        }
        
        return;
    }
    
    dc::DocumentDetectorResult documentDetectorResult = _documentDetector.detect(frame, _expectedDocument, dc::LANDSCAPE);
    
    std::vector<cv::Point> quadranglePoints {
        cv::Point(documentDetectorResult.tl.x, documentDetectorResult.tl.y),
        cv::Point(documentDetectorResult.tr.x, documentDetectorResult.tr.y),
        cv::Point(documentDetectorResult.br.x, documentDetectorResult.br.y),
        cv::Point(documentDetectorResult.bl.x, documentDetectorResult.bl.y)
    };
    
    if (documentDetectorResult.predictedAccuracy == dc::PA_NONE) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.videoPreviewLayer clean];
        });
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (!_isFirstDocumentDetect) {
                _isFirstDocumentDetect = YES;
                
                [self didFirstDocumentDetect];
            }
            
            if (isStable) {
                if (documentDetectorResult.predictedAccuracy == dc::PA_1) {
                    [self.videoPreviewLayer showWithGreenQuadranglePoints:quadranglePoints expectedDocument:_expectedDocument];
                } else {
                    [self.videoPreviewLayer showWithYellowQuadranglePoints:quadranglePoints expectedDocument:_expectedDocument];
                }
            } else {
                [self.videoPreviewLayer showWithRedQuadranglePoints:quadranglePoints expectedDocument:_expectedDocument];
            }
        });
    }
    
    if (isStable) {
        dc::DocumentCatcherResult documentCatcherResult = _documentCatcher.catchDocument(frame, documentDetectorResult, _expectedDocument, _documentWithFace);
        
        if (documentCatcherResult.pass) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                self.canCapture = NO;
                
                if (_delegate) {
                    [_delegate willCaptureDocument];
                }

                [self.videoPreviewLayer showDocument:documentCatcherResult.document points:quadranglePoints];
            });
        }
    }
}

@end
