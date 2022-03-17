//
//  PCSDocumentCaptureViewController.h
//  DocumentCapture
//
//  Created by Denis Silko on 12.12.2021.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Delegate

@protocol PCSDocumentCaptureViewControllerDelegate <NSObject>

- (void)willCaptureDocument;
- (void)didCaptureDocument:(UIImage *)image;
- (void)didFirstDocumentDetect;

@end

#pragma mark - Types

typedef NS_ENUM(NSUInteger, PCSDocumentType) {
    PASSPORT,
    ID,
    GREEN_BOOK,
    WHOLE_SCREEN
};

#pragma mark - ViewController

@interface PCSDocumentCaptureViewController : UIViewController

@property (weak, nonatomic) id <PCSDocumentCaptureViewControllerDelegate> delegate;
@property (assign, nonatomic) PCSDocumentType documentType;
@property (assign, nonatomic) BOOL documentWithFace;

@property (strong, nonatomic) UIColor *previewColor;
@property (strong, nonatomic) UIImage *previewImage;
 
- (void)reset;

@end

NS_ASSUME_NONNULL_END
