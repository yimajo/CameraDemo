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

@end

#define INDICATOR_RECT_SIZE 50.0

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self sessionInit];
    [self focusLayerInit];

    UIGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                     action:@selector(didTapGesture:)];
    
    [self.captureImageView addGestureRecognizer:gestureRecognizer];

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
    self.focusLayer.frame = CGRectMake(0, 0, INDICATOR_RECT_SIZE, INDICATOR_RECT_SIZE);
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
    
    //ビデオデータ出力作成
    NSDictionary *settings = @{(id)kCVPixelBufferPixelFormatTypeKey:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]};
    
    AVCaptureVideoDataOutput *dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    dataOutput.videoSettings = settings;
    [dataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];

    //セッション生成。inputとoutputを指定
    self.captureSession = [[AVCaptureSession alloc] init];
    [self.captureSession addInput:captureInput];
    [self.captureSession addOutput:dataOutput];
    
    //TODO: Photoじゃないとどうなるのか
    self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
    //beginConfigurationとcommitConfigurationとはなにか

    // プレビュー表示
    AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    previewLayer.frame = self.captureImageView.bounds;
//    previewLayer.automaticallyAdjustsMirroring = NO;
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.captureImageView.layer addSublayer:previewLayer];
    

    
//    AVCaptureConnection *videoConnection = NULL;
//    
//    // カメラの向きなどを設定する
//    [self.captureSession beginConfiguration];
//    
//    for ( AVCaptureConnection *connection in [dataOutput connections] )
//    {
//        for ( AVCaptureInputPort *port in [connection inputPorts] )
//        {
//            if ( [[port mediaType] isEqual:AVMediaTypeVideo] )
//            {
//                videoConnection = connection;
//                
//            }
//        }
//    }
//    if([videoConnection isVideoOrientationSupported]) // **Here it is, its always false**
//    {
//        [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
//    }
//    
//    [self.captureSession commitConfiguration];

    // セッションをスタートする
    [self.captureSession startRunning];
    
}

//delegateメソッド。各フレームにおける処理
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    // 画像の表示
//    self.captureImageView.image = [self imageFromSampleBufferRef:sampleBuffer];
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

- (IBAction)shutterCamera:(id)sender
{
    
}

- (void)didTapGesture:(UITapGestureRecognizer *)gestureRecognizer
{
    self.focusLayer.hidden = NO;

    CGPoint p = [gestureRecognizer locationInView:gestureRecognizer.view];

    [self setFocusPoint:p];
    
}

- (void)setFocusPoint:(CGPoint)point
{
    self.focusLayer.frame = CGRectMake(point.x - INDICATOR_RECT_SIZE / 2.0,
                                       point.y - INDICATOR_RECT_SIZE / 2.0,
                                       INDICATOR_RECT_SIZE,
                                       INDICATOR_RECT_SIZE);
    
    //[0,1]に正規化する
    CGFloat x = point.x / self.captureImageView.bounds.size.width;
    CGFloat y = point.y / self.captureImageView.bounds.size.height;
    
    CGPoint pointOfInterest = CGPointMake(x, y);
    
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
    if (!self.adjustingExposure) {
        return;
    }
    
    if ([keyPath isEqual:@"adjustingExposure"]) {
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
