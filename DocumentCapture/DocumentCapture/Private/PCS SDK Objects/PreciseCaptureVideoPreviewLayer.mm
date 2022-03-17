//
//  PreciseCaptureVideoPreviewLayer.m
//  Paycasso
//
//  Created by Denis on 22.01.19.
//  Copyright © 2017 Paycasso Verify. All rights reserved.
//

#import "PreciseCaptureVideoPreviewLayer.h"
#include <iostream>
#include <chrono>
#include "opencv2/core/core.hpp"
#include "opencv2/features2d.hpp"
#include "opencv2/features2d/features2d.hpp"
#include "opencv2/calib3d/calib3d.hpp"

using namespace dc;

@interface PreciseCaptureVideoPreviewLayer ()

typedef struct {
    CGPoint tl, tr, br, bl;
} Quadrilateral;

@property (weak, nonatomic) CALayer *bgLayer;
@property (weak, nonatomic) CAShapeLayer *blurMaskLayer;
@property (weak, nonatomic) CAShapeLayer *targetLayer;
@property (weak, nonatomic) CALayer *documentImage;
@property (assign, nonatomic) float viewHeight;
@property (strong, nonatomic) UIColor *red, *yellow, *green, *white;
@property (assign, nonatomic) CGFloat blurIntensity;
@property (assign, nonatomic) BOOL isShowDocument, isShowQuadrangle;
@property (assign, nonatomic) BOOL canMoveTarget;
@property (assign, nonatomic) BOOL canResetAnimation;
@property (assign, nonatomic) BOOL resetAnimation;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (assign, nonatomic) cv::Mat src;
@property (assign, nonatomic) std::vector<cv::Point> points;
@property (assign, nonatomic) Quadrilateral quadrilateral;
@property (assign, nonatomic) Quadrilateral finalQuadrilateral;
@property (assign, nonatomic) float tlSpeed, trSpeed, brSpeed, blSpeed;
@property (assign, nonatomic) float blurFactor;
@property (assign, nonatomic) float topSizeFactor;
@property (assign, nonatomic) CFTimeInterval lastTimeStamp;

@property (strong, nonatomic) UIImpactFeedbackGenerator *impactFeedbackGenerator;

@end

using namespace cv;

@implementation PreciseCaptureVideoPreviewLayer


+ (PreciseCaptureVideoPreviewLayer *)layerWithSession:(AVCaptureSession *)session frame:(CGRect)frame {
    return [[self alloc] initWithSession:session frame:frame];
}

- (instancetype)initWithSession:(AVCaptureSession *)session frame:(CGRect)frame {
    if (self = [super initWithSession:session]) {
        self.frame = frame;
        
        _impactFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        
        _previewColor = [UIColor whiteColor];
        
        _blurIntensity = 0.0;
        
        _isShowDocument = NO;
        _isShowQuadrangle = NO;
        _canMoveTarget = NO;
        _canResetAnimation = NO;
        _resetAnimation = NO;
        
        _targetLayer = [CAShapeLayer layer];
        _targetLayer.hidden = NO;
        
        _documentImage = [CALayer layer];
        
        float srcAr = 1080.0 / 1920.0; // AR by Camera frame resolution
        self.viewHeight = self.frame.size.width / srcAr;
        
        float ar = 1.58577250833642; // ID
        float imageWidth = self.frame.size.width;
        float imageHeight = self.frame.size.width / ar;
        float add = (self.frame.size.height - _viewHeight) / 2;
        float y = (_viewHeight / 2) - (imageHeight / 2) + add;
        
        _documentImage.frame = CGRectMake(0, y, imageWidth, imageHeight);
        
        _red = [UIColor redColor];
        _yellow = [UIColor yellowColor];
        _green = [UIColor greenColor];
        _white = [UIColor whiteColor];
        
        _targetLayer.fillColor = nil;
        _targetLayer.lineWidth = self.frame.size.width * 0.016908; // 7
        _targetLayer.opacity = 1.0;
        _targetLayer.lineCap = kCALineCapRound;
        _targetLayer.strokeColor = _red.CGColor;
        _targetLayer.hidden = YES;
        
//        PaycassoViewModel *viewModel = [[PaycassoConfiguration sharedInstance] viewModel];
//        UIView <CaptureSessionScreenProtocol> *captureView = (UIView <CaptureSessionScreenProtocol> *)viewModel.captureSessionScreen;
        
        self.previewColor = UIColor.whiteColor;
        
        if (self.previewColor) {
            // BlurView
            _bgLayer = [CALayer layer];
            _bgLayer.backgroundColor = self.previewColor.CGColor;
            _bgLayer.opacity = 0;
            
            float blurWidth = frame.size.width;
            float blurHeight = frame.size.width / srcAr;
            float border = (frame.size.height - blurHeight) / 2;
            
            _blurMaskLayer = [CAShapeLayer layer];
            _blurMaskLayer.fillRule = kCAFillRuleEvenOdd;
            _blurMaskLayer.frame = frame;
            _blurMaskLayer.bounds = CGRectMake(0, border, blurWidth, blurHeight);
            _blurMaskLayer.lineWidth = self.frame.size.width * 0.004831;
        } else if (self.previewImage) {
            _bgLayer = [CALayer layer];
            _bgLayer.contentsGravity = kCAGravityResizeAspectFill;
            UIImage *bgImage = self.previewImage;
            _bgLayer.contents = (UIImage *)bgImage.CGImage;
            _bgLayer.opacity = 0;
            
            _blurMaskLayer = [CAShapeLayer layer];
            _blurMaskLayer.fillRule = kCAFillRuleEvenOdd;
            _blurMaskLayer.frame = frame;
            _blurMaskLayer.lineWidth = self.frame.size.width * 0.004831;
        }
        
        _blurMaskLayer.lineCap = kCALineCapRound;
        _blurMaskLayer.strokeColor = [UIColor redColor].CGColor;
        
        _bgLayer.frame = frame;
        _bgLayer.hidden = NO;
        _bgLayer.mask = _blurMaskLayer;

        [self addSublayer:_documentImage];
        [self addSublayer:_bgLayer];
        [self addSublayer:_targetLayer];
        
        [self clean];
    }
    
    return self;
}

- (UIImage *)exportDocumentImage {
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.fillRule = kCAFillRuleEvenOdd;
    maskLayer.frame = CGRectMake(0, 0, document.size.width, document.size.height);
    maskLayer.lineWidth = self.frame.size.width * 0.004831; // 2 //self.frame.size.width * 0.009662; //4
    maskLayer.lineCap = kCALineCapRound;
    maskLayer.strokeColor = [UIColor redColor].CGColor;
    
    CALayer *backgroundgLayer = [CALayer layer];
    backgroundgLayer.backgroundColor = _white.CGColor;
    backgroundgLayer.mask = maskLayer;
    backgroundgLayer.frame = CGRectMake(0, 0, document.size.width, document.size.height);
    
    float radius = document.size.width * 0.037097526831545;
    CGPoint tl = CGPointMake(0, 0);
    CGPoint tr = CGPointMake(document.size.width, 0);
    CGPoint br = CGPointMake(document.size.width, document.size.height);
    CGPoint bl = CGPointMake(0, document.size.height);
    CGMutablePathRef targetPath = CGPathCreateMutable();
    CGPathMoveToPoint(targetPath, NULL, (bl.x + tl.x) / 2, (bl.y + tl.y) / 2);
    CGPathAddArcToPoint(targetPath, NULL, tl.x, tl.y, tr.x, tr.y, expectedDocument != dc::PASSPORT && expectedDocument != dc::A4 ? radius : 0);
    CGPathAddArcToPoint(targetPath, NULL, tr.x, tr.y, br.x, br.y, expectedDocument != dc::PASSPORT && expectedDocument != dc::A4 ? radius : 0);
    CGPathAddArcToPoint(targetPath, NULL, br.x, br.y, bl.x, bl.y, expectedDocument != dc::A4 ? radius : 0);
    CGPathAddArcToPoint(targetPath, NULL, bl.x, bl.y, tl.x, tl.y, expectedDocument != dc::A4 ? radius : 0);
    CGPathCloseSubpath(targetPath);
    
    CGMutablePathRef blurMaskPath = CGPathCreateMutableCopyByTransformingPath(targetPath, NULL);
    CGPathAddRect(blurMaskPath, nil, maskLayer.frame);
    CGPathCloseSubpath(blurMaskPath);
    maskLayer.path = blurMaskPath;
    

    CALayer *documentImage = [CALayer layer];
    documentImage.frame = CGRectMake(0, 0, document.size.width, document.size.height);
    documentImage.contents = (__bridge id)document.CGImage;
    [documentImage addSublayer:backgroundgLayer];
    
    CGPathRelease(blurMaskPath);
    CGPathRelease(targetPath);
    
    return [self imageFromLayer:documentImage];
}

- (UIImage *)imageFromLayer:(CALayer *)layer {
    UIGraphicsBeginImageContextWithOptions(layer.frame.size, NO, 0);
    
    [layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *outputImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return outputImage;
}

#pragma mark - Tick

- (void)startDisplayLink {
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleDisplayLink:)];
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopDisplayLink {
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)prepareTargetWithPoints:(CGPoint)tl tr:(CGPoint)tr br:(CGPoint)br bl:(CGPoint)bl mask:(BOOL)mask {
    float maxBorderLenght = MAX(norm(Point2f(tl.x, tl.y) - Point2f(tr.x, tr.y)), norm(Point2f(bl.x, bl.y) - Point2f(br.x, br.y)));
    _blurFactor = maxBorderLenght / self.frame.size.width;
    
    float radius = maxBorderLenght * 0.037097526831545;
    
    CGMutablePathRef targetPath = CGPathCreateMutable();
    CGPathMoveToPoint(targetPath, NULL, (bl.x + tl.x) / 2, (bl.y + tl.y) / 2);
    CGPathAddArcToPoint(targetPath, NULL, tl.x, tl.y, tr.x, tr.y, expectedDocument != dc::PASSPORT && expectedDocument != dc::A4 ? radius : 0);
    CGPathAddArcToPoint(targetPath, NULL, tr.x, tr.y, br.x, br.y, expectedDocument != dc::PASSPORT && expectedDocument != dc::A4 ? radius : 0);
    CGPathAddArcToPoint(targetPath, NULL, br.x, br.y, bl.x, bl.y, expectedDocument != dc::A4 ? radius : 0);
    CGPathAddArcToPoint(targetPath, NULL, bl.x, bl.y, tl.x, tl.y, expectedDocument != dc::A4 ? radius : 0);
    CGPathCloseSubpath(targetPath);
    _targetLayer.path = targetPath;
    
    if (mask) {
        CGMutablePathRef blurMaskPath = CGPathCreateMutableCopyByTransformingPath(targetPath, NULL);
        CGPathAddRect(blurMaskPath, nil, _blurMaskLayer.frame);
        CGPathCloseSubpath(blurMaskPath);
        _blurMaskLayer.path = blurMaskPath;
        
        CGPathRelease(blurMaskPath);
    }
    
    CGPathRelease(targetPath);
}

- (void)stopAnimation {
    [self stopDisplayLink];
}

- (void)startAnimation {
    [self startDisplayLink];
}

- (void)handleDisplayLink:(CADisplayLink *)displayLink {
    //    float actualFramesPerSecond = 1 / (displayLink.targetTimestamp - displayLink.timestamp);
    
    if (_resetAnimation) {
        _blurIntensity -= 0.65 * displayLink.duration;
        
        if (_blurIntensity < 0) {
            _blurIntensity = 0;
            
            _resetAnimation = NO;
        }
        
        _bgLayer.opacity = _blurIntensity;
    }
    
    if (_isShowDocument && !_src.empty()) {
        // Background animation
        
//        _bgLayer.opacity += 1200.0 * displayLink.duration;
//        _bgLayer.opacity = MIN(_bgLayer.opacity, 1);
        
//        _bgLayer.opacity = 1.0;

        _targetLayer.hidden = NO;
        _targetLayer.opacity -= 900.0 * displayLink.duration;
        _targetLayer.opacity = MAX(_targetLayer.opacity, 0);
        
        
        if (_canMoveTarget) {
            // Mask and document animation
            [CATransaction begin];
            [CATransaction setAnimationDuration:0.0];
            //        [CATransaction disableActions];
            
            self.documentImage.anchorPoint = CGPointZero;
            self.documentImage.transform = [self transformToFitQuadLayer:self.documentImage
                                                                 topLeft:_quadrilateral.tl
                                                                topRight:_quadrilateral.tr
                                                              bottomLeft:_quadrilateral.bl
                                                             bottomRight:_quadrilateral.br];
            [CATransaction commit];
            
            
            [self prepareTargetWithPoints:_quadrilateral.tl tr:_quadrilateral.tr br:_quadrilateral.br bl:_quadrilateral.bl mask:YES];
            
            BOOL tl = [self animateCornerWithPoints:_quadrilateral.tl end:_finalQuadrilateral.tl speed:_tlSpeed horizontalSide:YES deltaTime:displayLink.duration];
            BOOL tr = [self animateCornerWithPoints:_quadrilateral.tr end:_finalQuadrilateral.tr speed:_trSpeed horizontalSide:NO deltaTime:displayLink.duration];
            BOOL br = [self animateCornerWithPoints:_quadrilateral.br end:_finalQuadrilateral.br speed:_brSpeed horizontalSide:NO deltaTime:displayLink.duration];
            BOOL bl = [self animateCornerWithPoints:_quadrilateral.bl end:_finalQuadrilateral.bl speed:_blSpeed horizontalSide:YES deltaTime:displayLink.duration];
            
            if (tl && tr && br && bl) {
                _canMoveTarget = NO;
                
                [CATransaction begin];
                [CATransaction setAnimationDuration:0.0];
                
                self.documentImage.anchorPoint = CGPointZero;
                self.documentImage.transform = [self transformToFitQuadLayer:self.documentImage
                                                                     topLeft:_quadrilateral.tl
                                                                    topRight:_quadrilateral.tr
                                                                  bottomLeft:_quadrilateral.bl
                                                                 bottomRight:_quadrilateral.br];
                [CATransaction commit];
                
                
                [self prepareTargetWithPoints:_quadrilateral.tl tr:_quadrilateral.tr br:_quadrilateral.br bl:_quadrilateral.bl mask:YES];
                
                [self stopDisplayLink];
                [delegateController documentCaptureIsComplete];
            }
        }
        
        return;
    }
    
    if (_isShowQuadrangle) {
//        _blurIntensity = MAX(_blurIntensity, 0.05);
//        _blurIntensity += 3.00 * displayLink.duration;
//        _blurIntensity = MIN(_blurIntensity, 1.2 * (_topSizeFactor / self.frame.size.width) - 0.6);
//        //        NSLog(@"%f ", 1.2 * (_topSizeFactor / self.frame.size.width) - 0.6);
//
//        _bgLayer.opacity = _blurIntensity;
        _bgLayer.opacity = 0;
//        _targetLayer.opacity = 1;
        _targetLayer.hidden = NO;
    } else {
//        _blurIntensity -= 3 * displayLink.duration;
//        _blurIntensity = MAX(_blurIntensity, 0.0);
//
//        _bgLayer.opacity = _blurIntensity;
        
        _targetLayer.hidden = YES;
        _bgLayer.opacity = 0;
//        _targetLayer.opacity = 0;
    }
}

- (BOOL)animateCornerWithPoints:(CGPoint &)start end:(CGPoint)end speed:(CGFloat)speed horizontalSide:(BOOL)isLeft deltaTime:(CFTimeInterval)dt {
    if (start.x != end.x && start.y != end.y) {
        float deltaDistanceTravelled = speed * dt;
        
        float angle = atan2f((end.y - start.y), (end.x - start.x));
        
        float deltaX = deltaDistanceTravelled * cos(angle);
        float deltaY = deltaDistanceTravelled * sin(angle);
        
        start.x += deltaX;
        start.y += deltaY;
        
        BOOL endMove = isLeft ? start.x < 0 : start.x > self.frame.size.width;
        
        if (endMove) {
            start.x = end.x;
            start.y = end.y;
            
            return true;
        }
    } else {
        return true;
    }
    
    return false;
}

- (void)reset {
    _isShowDocument = NO;
    _isShowQuadrangle = NO;
    _canMoveTarget = NO;
    
    _targetLayer.opacity = 1.0;
    _targetLayer.hidden = YES;
    
    [self stopDisplayLink];
    [self startDisplayLink];
    
    if (!_canResetAnimation) {
        _blurIntensity = 0;
        _bgLayer.opacity = _blurIntensity;
        
        _documentImage.hidden = YES;
    } else {
        [CATransaction begin];
        [CATransaction setAnimationDuration:0.0];
        _documentImage.hidden = YES;
        
        CGMutablePathRef blurMaskPath = CGPathCreateMutable();
        CGPathAddRect(blurMaskPath, nil, _blurMaskLayer.frame);
        CGPathCloseSubpath(blurMaskPath);
        _blurMaskLayer.path = blurMaskPath;
        
        CGPathRelease(blurMaskPath);
        
        [CATransaction commit];
        
        _resetAnimation = YES;
    }
}

- (void)clean {
    _isShowQuadrangle = NO;
}

- (void)showWithRedQuadranglePoints:(std::vector<cv::Point>)points expectedDocument:(dc::ExpectedDocument)expectedDocument {
    [self showWithQuadranglePoints:points color:_red expectedDocument:expectedDocument];
}

- (void)showWithYellowQuadranglePoints:(std::vector<cv::Point>)points expectedDocument:(dc::ExpectedDocument)expectedDocument {
    [self showWithQuadranglePoints:points color:_yellow expectedDocument:expectedDocument];
}

- (void)showWithGreenQuadranglePoints:(std::vector<cv::Point>)points expectedDocument:(dc::ExpectedDocument)expectedDocument {
    [self showWithQuadranglePoints:points color:_green expectedDocument:expectedDocument];
}

- (void)showWithQuadranglePoints:(std::vector<cv::Point>)points color:(UIColor *)color expectedDocument:(dc::ExpectedDocument)expectedDocument {
    self.expectedDocument = expectedDocument;
    
    _isShowQuadrangle = YES;
    
    _targetLayer.strokeColor = color.CGColor;
    
    float viewWidth = self.frame.size.width;
    
    float diff = viewWidth / 1080.0;
    float add = (self.frame.size.height - _viewHeight) / 2;
    
    for (int i = 0; i < points.size(); i++) {
        points[i] *= diff;
        points[i].y += add;
    }
    
    CGPoint tl = CGPointMake(points[0].x, points[0].y);
    CGPoint tr = CGPointMake(points[1].x, points[1].y);
    CGPoint br = CGPointMake(points[2].x, points[2].y);
    CGPoint bl = CGPointMake(points[3].x, points[3].y);
    
    _topSizeFactor = [self distanceBeetwenPoint:tl point:tr];
    
    [self prepareTargetWithPoints:tl tr:tr br:br bl:bl mask:NO];
}

- (float)distanceBeetwenPoint:(CGPoint)p1 point:(CGPoint)p2 {
    float xDist = (p2.x - p1.x);
    float yDist = (p2.y - p1.y);
    
    return sqrt((xDist * xDist) + (yDist * yDist));
}

- (void)showDocument:(cv::Mat)src points:(std::vector<cv::Point>)points {
    if (_isShowDocument) {
        return;
    }
    
    [_impactFeedbackGenerator impactOccurred];
    
    _isShowDocument = YES;
    _canMoveTarget = YES;
    _canResetAnimation = YES;
    
    if (!_src.empty()) {
        _src.release();
    }
    
    _src = src.clone();
    
    _points.clear();
    _points = points;
    
    float viewWidth = self.frame.size.width;
    
    float diff = viewWidth / 1080.0;
    float add_ = (self.frame.size.height - _viewHeight) / 2;
    
    for (int i = 0; i < _points.size(); i++) {
        _points[i] *= diff;
        _points[i].y += add_;
    }
    
    _quadrilateral.tl = CGPointMake(_points[0].x, _points[0].y);
    _quadrilateral.tr = CGPointMake(_points[1].x, _points[1].y);
    _quadrilateral.br = CGPointMake(_points[2].x, _points[2].y);
    _quadrilateral.bl = CGPointMake(_points[3].x, _points[3].y);
    
    float ar = (float)_src.cols / (float)_src.rows;
    float imageWidth = self.frame.size.width;
    float imageHeight = self.frame.size.width / ar;
    float add = (self.frame.size.height - _viewHeight) / 2;
    float y = (_viewHeight / 2) - (imageHeight / 2) + add;
    
    _finalQuadrilateral.tl = CGPointMake(0, y);
    _finalQuadrilateral.tr = CGPointMake(imageWidth, y);
    _finalQuadrilateral.br = CGPointMake(imageWidth, y + imageHeight);
    _finalQuadrilateral.bl = CGPointMake(0, y + imageHeight);
    
    
    ///////////
    float tlDist = [self distanceBeetwenPoint:_quadrilateral.tl point:_finalQuadrilateral.tl];
    float trDist = [self distanceBeetwenPoint:_quadrilateral.tr point:_finalQuadrilateral.tr];
    float brDist = [self distanceBeetwenPoint:_quadrilateral.br point:_finalQuadrilateral.br];
    float blDist = [self distanceBeetwenPoint:_quadrilateral.bl point:_finalQuadrilateral.bl];
    
    float maxDist = MAX(MAX(tlDist, trDist), MAX(brDist, blDist));
//    float maxDist = MIN(MIN(tlDist, trDist), MIN(brDist, blDist));
    float speed = 550;
    
    _tlSpeed = tlDist / maxDist * speed;
    _trSpeed = trDist / maxDist * speed;
    _brSpeed = brDist / maxDist * speed;
    _blSpeed = blDist / maxDist * speed;
    /////////////
    
    // Save document
    CGImageRef imageRef = [self CGImageFromCVMat:_src];
    
    document = nil;
    document = [UIImage imageWithCGImage:imageRef];
    
    self.documentImage.contents = nil;
    self.documentImage.frame = CGRectMake(0, y, imageWidth, imageHeight);
    self.documentImage.contents = (__bridge id)document.CGImage;
    self.documentImage.hidden = NO;
    
    CGImageRelease(imageRef);
    
    _bgLayer.opacity = 1.0;
    _targetLayer.opacity = 1.0;
//    _targetLayer.strokeColor = _white.CGColor;
}

- (CATransform3D)transformToFitQuadLayer:(CALayer *)layer topLeft:(CGPoint)tl topRight:(CGPoint)tr bottomLeft:(CGPoint)bl bottomRight:(CGPoint)br {
    CGRect boundingBox = [[self class] boundingBoxForQuadTR:tr tl:tl bl:bl br:br];
    layer.frame = boundingBox;
    
    CGPoint frameTopLeft = boundingBox.origin;
    CATransform3D transform = [[self class] rectToQuad:layer.bounds
                                                quadTL:CGPointMake(tl.x-frameTopLeft.x, tl.y-frameTopLeft.y)
                                                quadTR:CGPointMake(tr.x-frameTopLeft.x, tr.y-frameTopLeft.y)
                                                quadBL:CGPointMake(bl.x-frameTopLeft.x, bl.y-frameTopLeft.y)
                                                quadBR:CGPointMake(br.x-frameTopLeft.x, br.y-frameTopLeft.y)];
    
    return transform;
}

+ (CGRect)boundingBoxForQuadTR:(CGPoint)tr tl:(CGPoint)tl bl:(CGPoint)bl br:(CGPoint)br {
    CGRect boundingBox = CGRectZero;
    
    CGFloat xmin = MIN(MIN(MIN(tr.x, tl.x), bl.x),br.x);
    CGFloat ymin = MIN(MIN(MIN(tr.y, tl.y), bl.y),br.y);
    CGFloat xmax = MAX(MAX(MAX(tr.x, tl.x), bl.x),br.x);
    CGFloat ymax = MAX(MAX(MAX(tr.y, tl.y), bl.y),br.y);
    
    boundingBox.origin.x = xmin;
    boundingBox.origin.y = ymin;
    boundingBox.size.width = xmax - xmin;
    boundingBox.size.height = ymax - ymin;
    
    return boundingBox;
}

+ (CATransform3D)rectToQuad:(CGRect)rect
                     quadTL:(CGPoint)topLeft
                     quadTR:(CGPoint)topRight
                     quadBL:(CGPoint)bottomLeft
                     quadBR:(CGPoint)bottomRight
{
    return [self rectToQuad:rect quadTLX:topLeft.x quadTLY:topLeft.y quadTRX:topRight.x quadTRY:topRight.y quadBLX:bottomLeft.x quadBLY:bottomLeft.y quadBRX:bottomRight.x quadBRY:bottomRight.y];
}

+ (CATransform3D)rectToQuad:(CGRect)rect
                    quadTLX:(CGFloat)x1a
                    quadTLY:(CGFloat)y1a
                    quadTRX:(CGFloat)x2a
                    quadTRY:(CGFloat)y2a
                    quadBLX:(CGFloat)x3a
                    quadBLY:(CGFloat)y3a
                    quadBRX:(CGFloat)x4a
                    quadBRY:(CGFloat)y4a {
    CGFloat X = rect.origin.x;
    CGFloat Y = rect.origin.y;
    CGFloat W = rect.size.width;
    CGFloat H = rect.size.height;
    
    CGFloat y21 = y2a - y1a;
    CGFloat y32 = y3a - y2a;
    CGFloat y43 = y4a - y3a;
    CGFloat y14 = y1a - y4a;
    CGFloat y31 = y3a - y1a;
    CGFloat y42 = y4a - y2a;
    
    CGFloat a = -H*(x2a*x3a*y14 + x2a*x4a*y31 - x1a*x4a*y32 + x1a*x3a*y42);
    CGFloat b = W*(x2a*x3a*y14 + x3a*x4a*y21 + x1a*x4a*y32 + x1a*x2a*y43);
    CGFloat c = H*X*(x2a*x3a*y14 + x2a*x4a*y31 - x1a*x4a*y32 + x1a*x3a*y42) - H*W*x1a*(x4a*y32 - x3a*y42 + x2a*y43) - W*Y*(x2a*x3a*y14 + x3a*x4a*y21 + x1a*x4a*y32 + x1a*x2a*y43);
    
    CGFloat d = H*(-x4a*y21*y3a + x2a*y1a*y43 - x1a*y2a*y43 - x3a*y1a*y4a + x3a*y2a*y4a);
    CGFloat e = W*(x4a*y2a*y31 - x3a*y1a*y42 - x2a*y31*y4a + x1a*y3a*y42);
    CGFloat f = -(W*(x4a*(Y*y2a*y31 + H*y1a*y32) - x3a*(H + Y)*y1a*y42 + H*x2a*y1a*y43 + x2a*Y*(y1a - y3a)*y4a + x1a*Y*y3a*(-y2a + y4a)) - H*X*(x4a*y21*y3a - x2a*y1a*y43 + x3a*(y1a - y2a)*y4a + x1a*y2a*(-y3a + y4a)));
    
    CGFloat g = H*(x3a*y21 - x4a*y21 + (-x1a + x2a)*y43);
    CGFloat h = W*(-x2a*y31 + x4a*y31 + (x1a - x3a)*y42);
    CGFloat i = W*Y*(x2a*y31 - x4a*y31 - x1a*y42 + x3a*y42) + H*(X*(-(x3a*y21) + x4a*y21 + x1a*y43 - x2a*y43) + W*(-(x3a*y2a) + x4a*y2a + x2a*y3a - x4a*y3a - x2a*y4a + x3a*y4a));
    
    const double kEpsilon = 0.0001;
    
    if(fabs(i) < kEpsilon)
    {
        i = kEpsilon* (i > 0 ? 1.0 : -1.0);
    }
    
    CATransform3D transform = {a/i, d/i, 0, g/i, b/i, e/i, 0, h/i, 0, 0, 1, 0, c/i, f/i, 0, 1.0};
    
    return transform;
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

- (void)dealloc {
    [self stopDisplayLink];
}

@synthesize delegateController;

@synthesize document;

@synthesize expectedDocument;

@end


