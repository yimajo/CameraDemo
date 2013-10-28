//
//  ViewController.m
//  CameraDemo
//
//  Created by yimajo on 2013/10/28.
//  Copyright (c) 2013年 Curiosity Software Inc. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (strong, nonatomic) AVCaptureSession *captureSession;

@property (weak, nonatomic) IBOutlet UIImageView *captureImageView;

@property (strong, nonatomic) CALayer *focusLayer;

//タップされた際にYESにし、露出変更時にNOにする
@property (nonatomic) BOOL adjustingExposure;

//撮影中の映像をそのまま
@property (strong, nonatomic) AVCaptureStillImageOutput *stillImageOutput;

@end

static const CGFloat focusLayerSize = 50.0;

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self sessionInit];
    [self focusLayerInit];

    UITapGestureRecognizer *tapGestureRecognizer
        = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                  action:@selector(didTapGesture:)];
    
    UISwipeGestureRecognizer *swipeLeftGestureRecognizer
        = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                    action:@selector(swipeGesture:)];
    swipeLeftGestureRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
    
    UISwipeGestureRecognizer *swipeRightGestureRecognizer
        = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(swipeGesture:)];

    swipeRightGestureRecognizer.direction = UISwipeGestureRecognizerDirectionRight;

    [self.captureImageView addGestureRecognizer:tapGestureRecognizer];
    [self.captureImageView addGestureRecognizer:swipeLeftGestureRecognizer];
    [self.captureImageView addGestureRecognizer:swipeRightGestureRecognizer];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)focusLayerInit
{
    self.focusLayer = [[CALayer alloc] init];
    self.focusLayer.borderColor = [[UIColor whiteColor] CGColor];
    self.focusLayer.borderWidth = 1.0;
    self.focusLayer.frame = CGRectMake(self.captureImageView.center.x,
                                       self.captureImageView.center.y,
                                       focusLayerSize,
                                       focusLayerSize);
    self.focusLayer.hidden = YES;
    [self.captureImageView.layer addSublayer:self.focusLayer];
}

- (void)sessionInit
{
    //キャプチャデバイスの初期化
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    NSError *error;

    if ([device lockForConfiguration:&error]) {

        //フォーカスモードの指定
        if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            //必要に応じてフォーカスモードになる
            device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        } else if ([device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            //フォーカスがシーンの中心から外れてもフォーカスを意地
            device.focusMode = AVCaptureFocusModeAutoFocus;
        }
        
        //iPhoe4端末では下記をサポートしてなさそう
        if ([device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            //必要に応じて自動で露出を調整
            device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        } else if ([device isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
            //露出変更（露出固定ではない）
            device.exposureMode = AVCaptureExposureModeAutoExpose;
        }
        
        //ホワイトバランスモード設定
        if ([device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
            //継続的なホワイトバランスモードにしておく
            device.whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
        } else if ([device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
            //ホワイトバランスモードにしておく
            device.whiteBalanceMode = AVCaptureWhiteBalanceModeAutoWhiteBalance;
        }
        
        [device unlockForConfiguration];

    }

    
    //
    //デバイスが露出の設定を変更しているかどうかはadjustingExposureプロパティで分かる
    [device addObserver:self
             forKeyPath:@"adjustingExposure"
                options:NSKeyValueObservingOptionNew
                context:nil];
    
    
    AVCaptureInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                         error:&error];
    
    //セッション生成。inputとoutputを指定
    //input
    self.captureSession = [[AVCaptureSession alloc] init];
    [self.captureSession addInput:captureInput];

    //output
    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    [self.captureSession addOutput:self.stillImageOutput];
    
    //解像度を指定。Photoは端末に応じた最高の解像度になる
    self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto;

    // プレビュー表示
    AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    previewLayer.frame = self.captureImageView.bounds;

    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.captureImageView.layer addSublayer:previewLayer];
    
    // セッションをスタートする
    [self.captureSession startRunning];
    
}

// CMSampleBufferRefをUIImageへ
- (UIImage *)imageFromSampleBufferRef:(CMSampleBufferRef)sampleBuffer
{
    // イメージバッファの取得
    CVImageBufferRef    buffer;
    buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // イメージバッファのロック
    CVPixelBufferLockBaseAddress(buffer, 0);
    // イメージバッファ情報の取得
    uint8_t*    base;
    size_t      width, height, bytesPerRow;
    base = CVPixelBufferGetBaseAddress(buffer);
    width = CVPixelBufferGetWidth(buffer);
    height = CVPixelBufferGetHeight(buffer);
    bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
    
    // ビットマップコンテキストの作成
    CGColorSpaceRef colorSpace;
    CGContextRef    cgContext;
    colorSpace = CGColorSpaceCreateDeviceRGB();
    cgContext = CGBitmapContextCreate(
                                      base, width, height, 8, bytesPerRow, colorSpace,
                                      kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);
    
    // 画像の作成
    CGImageRef  cgImage;
    UIImage*    image;
    cgImage = CGBitmapContextCreateImage(cgContext);
    image = [UIImage imageWithCGImage:cgImage scale:1.0f
                          orientation:UIImageOrientationUp];
    CGImageRelease(cgImage);
    CGContextRelease(cgContext);
    
    // イメージバッファのアンロック
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    return image;
}

- (IBAction)takePhoto:(id)sender
{
    AVCaptureConnection *videoConnection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    
    if (!videoConnection) {
        return;
    }
    
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection
                                                       completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error)
    {
        if (!imageDataSampleBuffer) {
            return ;
        }
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        
        UIImage *image = [[UIImage alloc] initWithData:imageData];
        
        UIImageWriteToSavedPhotosAlbum(image, self, nil, nil);
    }];
}

#pragma mark - gesture

- (void)didTapGesture:(UITapGestureRecognizer *)gestureRecognizer
{
    CGPoint p = [gestureRecognizer locationInView:gestureRecognizer.view];
    
    [self setFocusPoint:p];
    
}

- (void)swipeGesture:(UISwipeGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.direction == UISwipeGestureRecognizerDirectionLeft) {
        NSLog(@"left");
    } else if (gestureRecognizer.direction == UISwipeGestureRecognizerDirectionRight) {
        NSLog(@"right");
    }
}

#pragma mark - 

- (void)setFocusPoint:(CGPoint)point
{
    self.focusLayer.frame = CGRectMake(point.x - focusLayerSize / 2.0,
                                       point.y - focusLayerSize / 2.0,
                                       focusLayerSize,
                                       focusLayerSize);
    
    self.focusLayer.hidden = NO;

    //pointOfInterestへの代入には座標系に応じて値を変換してやる必要がある
    //{0,0}の座標が縦持ちにして右上になり下がx、左がyとなる（x,yがそれぞれテレコ、かつyが逆）
    //それぞれを[0,1]に正規化する
    CGPoint pointOfInterest = CGPointMake(point.y / self.captureImageView.bounds.size.height,
                                          1.0 - point.x / self.captureImageView.bounds.size.width);
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError *error;
    if ([device lockForConfiguration:&error]) {
        
        //フォーカス
        if ([device isFocusPointOfInterestSupported] &&
            [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            //フォーカスを指定する
            device.focusPointOfInterest = pointOfInterest;
            device.focusMode = AVCaptureFocusModeAutoFocus;
        }
        
        //露出
        if ([device isExposurePointOfInterestSupported] &&
            [device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]){
            self.adjustingExposure = YES;
            //露出を指定。ここでは露出が変更中だと露出の変更ができないのでAutoにし、KVOでLockする
            device.exposurePointOfInterest = pointOfInterest;
            device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        }
        
        [device unlockForConfiguration];
        
    }
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqual:@"adjustingExposure"]) {
        if (!self.adjustingExposure) {
            return;
        }

        if ([[change objectForKey:NSKeyValueChangeNewKey] boolValue] == NO) {
            //NOのとき露出が変更中ではないので露出を固定させる
            self.adjustingExposure = NO;
            AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
            
            NSError *error = nil;
            if ([device lockForConfiguration:&error]) {
                //露出固定
                device.exposureMode = AVCaptureExposureModeLocked;
                [device unlockForConfiguration];
            }
        }
    }
}

@end
