//
//  ViewController.m
//  DYScreenShot
//
//  Created by duanqinglun on 16/6/29.
//  Copyright © 2016年 duan.yu. All rights reserved.
//

#import "ViewController.h"
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

@interface UIStatusBarWindow : UIWindow
@end

@interface UIStatusBarWindow (screenshot)
@end

@implementation UIStatusBarWindow (screenshot)

static UIStatusBarWindow *statusBarWindow;

+ (void)load
{
    method_exchangeImplementations(class_getInstanceMethod([self class], @selector(initWithFrame:)),
                                   class_getInstanceMethod([self class], @selector(new_initWithFrame:)));
}

- (instancetype)new_initWithFrame:(CGRect)frame
{
    statusBarWindow = [self new_initWithFrame:frame];
    return statusBarWindow;
}

@end

@interface PreviewView : UIView

@property (nonatomic) AVCaptureSession *session;

@end

@implementation PreviewView

+ (Class)layerClass
{
    return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureSession *)session
{
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.layer;
    return previewLayer.session;
}

- (void)setSession:(AVCaptureSession *)session
{
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.layer;
    previewLayer.session = session;
}

@end

@interface DrawingBoard : UIView

@end

@implementation DrawingBoard
{
    UIBezierPath *path;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        path = [UIBezierPath bezierPath];
        [path setLineWidth:5.0];
    }
    return self;
}

- (void)didMoveToSuperview
{
    self.backgroundColor = [UIColor whiteColor];
}

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
    [[UIColor redColor] setStroke];
    [path stroke];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    CGPoint point = [self convertPoint:[[touches anyObject] locationInView:self] fromView:nil];
    [path moveToPoint:point];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    CGPoint point = [self convertPoint:[[touches anyObject] locationInView:self] fromView:nil];
    [path addLineToPoint:point];
    [self setNeedsDisplay];
}

- (void)clean
{
    [path removeAllPoints];
    [self setNeedsDisplay];
}

@end

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

@end

@implementation ViewController
{
    UIImageView *imgvPhoto;
    DrawingBoard *drawingBoard;
    PreviewView *previewView;
    
    AVCaptureSession *session;
    AVCaptureDeviceInput *videoDeviceInput;
    AVCaptureStillImageOutput *stillImageOutput;
    AVCaptureVideoPreviewLayer *previewLayer;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    drawingBoard = [[DrawingBoard alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:drawingBoard];
    
    previewView = [[PreviewView alloc] initWithFrame:CGRectMake(self.view.frame.size.width/4, self.view.frame.size.height/4, self.view.frame.size.width/2, self.view.frame.size.height/2)];
    [self.view addSubview:previewView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenshot) name:UIApplicationUserDidTakeScreenshotNotification object:nil];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideImg)];
    [self.view addGestureRecognizer:tap];
    
    if (!imgvPhoto) {
        imgvPhoto = [[UIImageView alloc] init];
        imgvPhoto.frame = CGRectMake(self.view.frame.size.width/4, self.view.frame.size.height/4, self.view.frame.size.width/2, self.view.frame.size.height/2);
        imgvPhoto.backgroundColor = [UIColor whiteColor];
        
        CALayer *layer = [imgvPhoto layer];
        layer.borderColor = [[UIColor lightGrayColor] CGColor];
        layer.borderWidth = 1.0f;
        layer.shadowColor = [UIColor blackColor].CGColor;
        layer.shadowOffset = CGSizeMake(4, 4);
        layer.shadowOpacity = 0.5;
        layer.shadowRadius = 2.0;
        
        [self.view addSubview:imgvPhoto];
        imgvPhoto.hidden = YES;
    }
    
    session = [[AVCaptureSession alloc] init];
    previewView.session = session;
    [session beginConfiguration];
    
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:NULL];
    if ( [session canAddInput:videoDeviceInput] ) {
        [session addInput:videoDeviceInput];
    }
    previewLayer = (AVCaptureVideoPreviewLayer *)previewView.layer;
    
    stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    if ( [session canAddOutput:stillImageOutput] ) {
        stillImageOutput.outputSettings = @{AVVideoCodecKey : AVVideoCodecJPEG};
        [session addOutput:stillImageOutput];
    }
    
    [session commitConfiguration];
    [session startRunning];
    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [self latestAsset:^(UIImage *image) {
//            imgvPhoto.image = image;
//            imgvPhoto.hidden = NO;
//        }];
//    });
}

- (void)screenshot
{
    [self snapStillImageWithBlock:^(UIImage *image) {
        imgvPhoto.image = [self uikitScreenshotWithOther:image];
        imgvPhoto.hidden = NO;
    }];
    
//    imgvPhoto.image = [self uikitScreenshot];
//    imgvPhoto.hidden = NO;
    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        UIView *snapshotView = [[UIScreen mainScreen] snapshotViewAfterScreenUpdates:NO];
//        snapshotView.frame = imgvPhoto.bounds;
//        [imgvPhoto addSubview:snapshotView];
//        imgvPhoto.hidden = NO;
//    });
}

- (UIImage *)uikitScreenshotWithOther:(UIImage *)otherImage
{
    CGSize imageSize = [[UIScreen mainScreen] bounds].size;
    UIGraphicsBeginImageContextWithOptions(imageSize, YES, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    for (UIWindow *window in [[UIApplication sharedApplication] windows])
    {
        if ([window screen] == [UIScreen mainScreen])
        {
            CGContextSaveGState(context);
            CGContextTranslateCTM(context, [window center].x, [window center].y);
            CGContextConcatCTM(context, [window transform]);
            CGContextTranslateCTM(context,
                                  -[window bounds].size.width * [[window layer] anchorPoint].x,
                                  -[window bounds].size.height * [[window layer] anchorPoint].y);
            [[window layer] renderInContext:context];
            CGContextRestoreGState(context);
        }
    }
    
    [otherImage drawInRect:previewView.frame];
    
    [statusBarWindow.layer renderInContext:context];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)snapStillImageWithBlock:(void (^)(UIImage *))block
{
    AVCaptureConnection *connection = [stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    connection.videoOrientation = previewLayer.connection.videoOrientation;
    
    [stillImageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^( CMSampleBufferRef imageDataSampleBuffer, NSError *error ) {
        if ( imageDataSampleBuffer ) {
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *image = [UIImage imageWithData:imageData];
            if (block) {
                block(image);
            }
        }
    }];
}

- (void)hideImg
{
    imgvPhoto.hidden = YES;
    [drawingBoard clean];
}

- (void)latestAsset:(void (^)(UIImage *))block
{
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    PHFetchResult *assetsFetchResults = [PHAsset fetchAssetsWithOptions:options];
    PHCachingImageManager *imageManager = [[PHCachingImageManager alloc] init];
    PHAsset *asset = [assetsFetchResults firstObject];
    [imageManager requestImageForAsset:asset
                            targetSize:imgvPhoto.frame.size
                           contentMode:PHImageContentModeAspectFill
                               options:nil
                         resultHandler:^(UIImage *result, NSDictionary *info) {
                             if (block) {
                                 block(result);
                             }
                         }];
}

@end