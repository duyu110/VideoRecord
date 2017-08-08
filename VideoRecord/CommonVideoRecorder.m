//
//  CommonVideoTaker.m
//  guimiquan
//
//  Created by vanchu on 15/6/24.
//  Copyright (c) 2015年 Vanchu. All rights reserved.
//

#import "CommonVideoRecorder.h"
#import "RecordProgressView.h"
#import "RecordCompositioner.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVKit/AVKit.h>

//#import "GMToast.h"
//#import "CommonVideoEditor.h"
//#import "UIAlertView+Blocks.h"
//#import "Helper+System.h"
//#import "Helper+Time.h"
#import "RecordStorage.h"
//#import "UIAlertView+Blocks.h"
#import <MobileCoreServices/MobileCoreServices.h>
//#import "CommonVideoTrim.h"
//#import "CommonVideoAlbumPicker.h"
typedef  NS_ENUM(NSInteger, ObtainVideoWay){
    ObtainVideoWayRecord=0,
    ObtainVideoWayLoad=1,
};

@interface CommonVideoRecorder ()<AVCaptureFileOutputRecordingDelegate,RecordProgressViewDelegate>//CommonVideoPickerDelegate>
{
    AVCaptureSession            *_captureSession;
    AVCaptureDeviceInput        *_deviceInput;
    AVCaptureMovieFileOutput    *_movieFileOutPut;
    AVCaptureVideoPreviewLayer  *_previewLayer;
    
    NSMutableArray       *_secondsRecordeds;
    RecordCompositioner  *_compositioner;
    CGFloat             _secondsRecorded;
    CGFloat             _secondsMax;
    NSTimer              *_timer;
    
}

@property (weak, nonatomic) IBOutlet UIView   *videoPreview;
@property (weak, nonatomic) IBOutlet UIButton *dismissButton;
@property (weak, nonatomic) IBOutlet UIButton *torchButton;
@property (weak, nonatomic) IBOutlet UIButton *cameraButton;

@property (weak, nonatomic) IBOutlet UIButton *backButton;
@property (weak, nonatomic) IBOutlet UIImageView *recordButtonView;
@property (weak, nonatomic) IBOutlet UIButton *confirmButton;

@property (weak, nonatomic) IBOutlet UIButton *loadVideoButton;

@property (weak, nonatomic) IBOutlet UILabel *recordTipsLabel;

@property (weak, nonatomic) IBOutlet UILabel *recordTimeLabel;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *constraintRecordTopToProgressBottom;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *constraintTextTopToRecordBottom;
@property (weak, nonatomic) IBOutlet RecordProgressView *progressView;

@end

@implementation CommonVideoRecorder
{
    BOOL _canLoadVideo;
    
    BOOL _recordToEnd;

    BOOL _isMerging;
    
    BOOL _isTorchOn;
    BOOL _isSupportTorch;
    BOOL _isSupportCameraSwitch;
}

#pragma mark - life cycle
// [UIStoryboard storyboardwith...] will invoke
- (instancetype)initWithCoder:(NSCoder *)aDecoder{
   self = [super initWithCoder:aDecoder];
    if (self) {
        _isTorchOn = NO;
        _isMerging = NO;
        _isSupportTorch = NO;
        _isSupportCameraSwitch = NO;
        _recordToEnd = NO;
        _canLoadVideo =NO;
        _secondsRecorded = 0;
        _secondsMax = 30.0f;
        _secondsRecordeds = [NSMutableArray array];
        [_secondsRecordeds addObject:@0];
        
		[[RecordStorage sharedInstance] reset];
//        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive) name:EVENT_APP_WILL_RESIGN_ACTIVE object:nil];
//        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive) name:EVENT_APP_ENTER_FOREGROUND object:nil];
    }
    return self;
}

- (void)dealloc{
    _captureSession = nil;
    _deviceInput = nil;
    _movieFileOutPut = nil;
    [_captureSession stopRunning];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadDevice];
    [self checkupDeviceSupport];
//    [self checkLoadVideoAuthority];
    
    [self renderUI];
//    [self changeButtonStatusWithObtainVideoWay:ObtainVideoWayLoad];

    self.progressView.maxProgressTime = _secondsMax;
    self.progressView.minProgressTime = 2.0f;
    self.progressView.delegate = self;
    
    self.confirmButton.enabled = NO;
//	ACTION_REPORT(@"article_video_record", nil);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [_captureSession startRunning];
    _compositioner = [[RecordCompositioner alloc] init];
    [self topBarShouldHidden:YES];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    if (_isTorchOn) {
//        [self setTorchMode:AVCaptureTorchModeOn];
    }
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    [self topBarShouldHidden:NO];
}

- (void)viewFirstDidLayoutSubviews{
//    [super viewFirstDidLayoutSubviews];
    _previewLayer.frame = self.videoPreview.bounds;
//    if ([Helper isEqualToSmallScreen]) {
//        self.constraintRecordTopToProgressBottom.constant = 5;
//        self.constraintTextTopToRecordBottom.constant = 5;
//    }
}

- (void)appWillResignActive{
        [_movieFileOutPut stopRecording];
}

- (void)appDidBecomeActive{
    if (_isTorchOn) {
//        [self setTorchMode:AVCaptureTorchModeOn];
    }
}

- (BOOL)shouldAutorotate{
    return NO;
}

# pragma mark - private func
- (void)topBarShouldHidden:(BOOL)hidden{
    self.navigationController.navigationBar.hidden = hidden;
    [UIApplication sharedApplication].statusBarHidden = hidden;
}

- (void)loadDevice{
    _captureSession = [[AVCaptureSession alloc] init];
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPresetMedium]) {
        _captureSession.sessionPreset = AVCaptureSessionPresetMedium;
    }

    AVCaptureDevice *device = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    if (!device) {
        device = [self getCameraDeviceWithPosition:AVCaptureDevicePositionFront];
    }
    if (!device) {
//        [self showAuthorityAlertWithTitle:@"无法使用摄像头! o(>﹏<)o\n请在系统的\"设置－隐私\"选项中，允许闺蜜圈访问你的相机。"];
        return;
    }
    
    AVCaptureDevice *audioDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];

    NSError *error = nil;
    _deviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    if (error) {
//        [self showAuthorityAlertWithTitle:@"无法使用摄像头! o(>﹏<)o\n请在系统的\"设置－隐私\"选项中，允许闺蜜圈访问你的相机。" ];
        return;
    }
    
    AVCaptureDeviceInput *audioDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:&error];
    if (error) {
//        [self showAuthorityAlertWithTitle:@"无法使用麦克风! o(>﹏<)o\n请在系统的\"设置－隐私\"选项中，允许闺蜜圈访问你的麦克风。"];
        return;
    }
    
    _movieFileOutPut = [[AVCaptureMovieFileOutput alloc] init];
//    如果不设置，当单次录制时长超过13s时，在ios8.1上会没有声音
    [_movieFileOutPut setMovieFragmentInterval:kCMTimeInvalid];
    
    if ([_captureSession canAddInput:_deviceInput]) {
        [_captureSession addInput:_deviceInput];
        [_captureSession addInput:audioDeviceInput];
        AVCaptureConnection *connection =[_movieFileOutPut connectionWithMediaType:AVMediaTypeVideo];
        if ([connection isVideoStabilizationSupported]) {
            connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }
    }
    
    if ([_captureSession canAddOutput:_movieFileOutPut]) {
        [_captureSession addOutput:_movieFileOutPut];
    }
}

- (void)renderUI{
    self.cameraButton.hidden = !_isSupportCameraSwitch;
    self.torchButton.hidden = !_isSupportTorch;
    
    CALayer *layer = self.videoPreview.layer;
    _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    _previewLayer.frame = self.videoPreview.frame;
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [layer insertSublayer:_previewLayer above:layer];
}

- (void)checkupDeviceSupport{
    AVCaptureDevice *captureDevice = [_deviceInput device];
    if ([captureDevice hasTorch]) {
        _isSupportTorch = YES;
    }
    if ([self getCameraDeviceWithPosition:AVCaptureDevicePositionBack]
      &&[self getCameraDeviceWithPosition:AVCaptureDevicePositionFront]) {
        _isSupportCameraSwitch = YES;
    }
}

//- (void)checkLoadVideoAuthority{
//    if (OBTAIN_SERVICE(UserService).user.info.isInVideoWhiteList || OBTAIN_SERVICE(UserService).user.info.level >= OBTAIN_SERVICE(AppService).config.sys.loadVideoLowestLevel) {
//        _canLoadVideo = YES;
//    }else{
//        _canLoadVideo = NO;
//    }
//}

- (void)recordDidFinish{
    if (_progressView.currentProgress < _progressView.minProgressTime/_progressView.maxProgressTime) {
//        [[GMToast make:@"您的视频长度不足，请再继续录制一些片段"] show];
        return;
    }
    if (_isMerging) {
        return;
    }
    _isMerging = YES;
    [_captureSession stopRunning];
//    [self showLoadingWithMessage:@"正在处理视频中..." inFrame:self.videoPreview.frame autoHidden:NO];
    [_compositioner mergeAndExportVideoWithComplete:^(NSURL *url) {
//        [self hideLoading];
        _isMerging = NO;
        AVAsset *asset = [AVAsset assetWithURL:url];
        NSLog(@"%f",CMTimeGetSeconds(asset.duration));
        
        AVPlayer *player = [[AVPlayer alloc] initWithURL:url];
        AVPlayerViewController *playController = [[AVPlayerViewController alloc] init];
        playController.player = player;
        [self presentViewController:playController animated:YES completion:nil];
            // 跳转编辑页
//            CommonVideoEditor *vc = [[UIStoryboard storyboardWithName:@"CommonVideo" bundle:nil] instantiateViewControllerWithIdentifier:@"CommonVideoEditor"];
//            vc.videoSourceUrl = url;
//            [self.navigationController pushViewController:vc animated:YES];
       
    } failed:^(NSError *error) {
//        [self hideLoading];
//        [[GMToast make:@"处理失败，请重试"] show];
        _isMerging = NO;
        [_captureSession startRunning];
    }];
}

#pragma mark - event handle
- (IBAction)onBackClick:(id)sender {
    if (_isMerging) {
        return;
    }
    
    if (self.progressView.backProgress == YES) {
        [self.progressView didBackProgress];
        [self retroveLastTime];
        
        _recordToEnd = NO;
		[[RecordStorage sharedInstance] rewindFragementFile];
        if ([RecordStorage sharedInstance].numberOfFragmentFiles == 0) {
            [self changeButtonStatusWithObtainVideoWay:ObtainVideoWayLoad];
        }
        
        if (_progressView.currentProgress < _progressView.minProgressTime/_progressView.maxProgressTime) {
            self.confirmButton.enabled = NO;
        }
    }else{
        [self.progressView willBackProgress];
    }
}

- (IBAction)onRecordFinishClick:(id)sender {
    [self recordDidFinish];
    
}

- (IBAction)onDismissButtonClick:(id)sender {
    if ([RecordStorage sharedInstance].numberOfFragmentFiles > 0) {
//        [UIAlertView showWithTitle:@"是否放弃已录制的视频?" message:@"" cancelButtonTitle:@"取消" otherButtonTitles:@[@"放弃"] tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
//            if (buttonIndex != alertView.cancelButtonIndex) {
//                [self dismissViewControllerAnimated:YES completion:nil];
//            }
//        }];
//    }else{
//        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (IBAction)onTorchSwitchClick:(id)sender {
    self.torchButton.enabled = NO;
    if (_isTorchOn) {
        [self setTorchMode:AVCaptureTorchModeOff];
    }else{
        [self setTorchMode:AVCaptureTorchModeOn];
    }
    _isTorchOn = !_isTorchOn;
}

- (IBAction)onCameraToggleClick:(id)sender {
    AVCaptureDevice *currentDevice=[_deviceInput device];
    AVCaptureDevice *toChangeDevice;
    AVCaptureDevicePosition currentPosition=[currentDevice position];
    AVCaptureDevicePosition toChangePosition=AVCaptureDevicePositionFront;
    if (currentPosition==AVCaptureDevicePositionUnspecified
      ||currentPosition==AVCaptureDevicePositionFront) {
        toChangePosition=AVCaptureDevicePositionBack;
    }
    toChangeDevice=[self getCameraDeviceWithPosition:toChangePosition];
    AVCaptureDeviceInput *toChangeDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:toChangeDevice error:nil];
    
    [_captureSession beginConfiguration];
    [_captureSession removeInput:_deviceInput];
    [_captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    if ([_captureSession canAddInput:toChangeDeviceInput]) {
        [_captureSession addInput:toChangeDeviceInput];
        _deviceInput = toChangeDeviceInput;
    }else{
        [_captureSession addInput:_deviceInput];
    }
    [_captureSession commitConfiguration];
    
    if (toChangePosition == AVCaptureDevicePositionBack) {
        _torchButton.hidden = !_isSupportTorch;
        if (_isTorchOn) {
            [self setTorchMode:AVCaptureTorchModeOn];
        }
    }else{
        if (toChangePosition == AVCaptureDevicePositionFront) {
            _torchButton.hidden = YES;
        }
    }
}

- (IBAction)onLoadVideoClick:(id)sender {
//    CommonVideoAlbumPicker *albumPicker = [[UIStoryboard storyboardWithName:@"CommonVideo" bundle:nil] instantiateViewControllerWithIdentifier:NSStringFromClass([CommonVideoAlbumPicker class])];
//    [self.navigationController pushViewController:albumPicker animated:YES];
//	ACTION_REPORT(@"article_video_select", nil);
}


- (IBAction)onRecordLongPress:(id)sender {
    UIGestureRecognizer *gesture = sender;
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self performStartRecording];
    }
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [self performStopRecording];
    }
}

#pragma mark - videoRecord delegate
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
//    NSLog(@"%@",NSStringFromSelector(_cmd));
    self.progressView.secondsRemained = _secondsMax-_secondsRecorded;
    [self.progressView startRunning];
    [self startCount];
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error{
    [self stopCount];
    if (error) {
        [self retroveLastTime];
        [_progressView cancelCurrentProgress];
        return;
    }
    if (_progressView.currentProgress < _progressView.minProgressTime/_progressView.maxProgressTime) {
        self.confirmButton.enabled = NO;
    }
    [_secondsRecordeds addObject:@(_secondsRecorded)];
//    NSLog(@"%@",NSStringFromSelector(_cmd));
	[[RecordStorage sharedInstance] nextFragmentFile];
    if (!_recordToEnd) {
        [self.progressView stopRunning];
    }else{
        [self recordDidFinish];
    }
}

- (void)recordProgressRunningToEnd{
    _recordToEnd = YES;
    [self changeButtonStatusWithRecording:NO];
    [self changeRecordTipsWithRecordingStatus:NO];
    [_movieFileOutPut stopRecording];
}

#pragma mark - NSTimer Count
- (void)startCount{
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(onCountdownTick:) userInfo:nil repeats:YES];
}

- (void)stopCount{
    [_timer invalidate];
}

- (void)resetCount{
    _secondsRecorded = 0.0f;
}

- (void)retroveLastTime{
    [_secondsRecordeds removeLastObject];
    _secondsRecorded = [[_secondsRecordeds lastObject] floatValue];
    self.recordTimeLabel.text = [NSString stringWithFormat:@"%0.1fs",_secondsRecorded];
}

- (void)onCountdownTick:(NSTimer *)timer {
    _secondsRecorded+=0.1;
    self.recordTimeLabel.text = [NSString stringWithFormat:@"%0.1fs",_secondsRecorded];
    if (_secondsRecorded >= _secondsMax) {
        [_timer invalidate];
    }
}


#pragma mark - helper func
- (void)changeButtonStatusWithRecording:(BOOL)isRecording{
    self.dismissButton.hidden = isRecording;
    self.backButton.enabled = !isRecording;
//    if (isRecording) {
//        [self.recordButtonView setImage:[UIImage imageNamed:@"btn_common_videorecorder_record_select"]];
//    }else{
//        [self.recordButtonView setImage:[UIImage imageNamed:@"btn_common_videorecorder_record"]];
//    }
    
    if (_isSupportTorch) {
        self.torchButton.hidden = isRecording;
    }
    if (_isSupportCameraSwitch) {
        self.cameraButton.hidden = isRecording;
    }
    if (_progressView.currentProgress < _progressView.minProgressTime/_progressView.maxProgressTime) {
        self.confirmButton.enabled = NO;
    }else{
        self.confirmButton.enabled = !isRecording;
    }
}

- (void)changeButtonStatusWithObtainVideoWay:(ObtainVideoWay)way{
    if (way == ObtainVideoWayRecord) {
        self.backButton.hidden = NO;
        self.confirmButton.hidden = NO;
        self.loadVideoButton.hidden = YES;
    }else{
        self.backButton.hidden = YES;
        self.confirmButton.hidden = YES;
        self.loadVideoButton.hidden = NO;
    }
    
    if (!_canLoadVideo) {
        self.loadVideoButton.hidden = YES;
    }
}

- (void)changeRecordTipsWithRecordingStatus:(BOOL)isRecord{
    if (isRecord) {
        self.recordTipsLabel.text = @"松开结束";
    }else{
        self.recordTipsLabel.text = @"按住拍摄";
    }
}

- (AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position] == position) {
            return camera;
        }
    }
    return nil;
}

-(void)setTorchMode:(AVCaptureTorchMode )torchMode{
    if (!_isSupportTorch) {
        return;
    }
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isTorchModeSupported:torchMode]) {
            [captureDevice setTorchMode:torchMode];
            self.torchButton.enabled = YES;
        }
    }];
}

- (void)changeDeviceProperty:(void (^)(AVCaptureDevice *device))propertyChange{
    AVCaptureDevice *captureDevice = [_deviceInput device];
    NSError *error = nil;
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}
- (void)performStartRecording{
    
    if (_recordToEnd) {
        [self recordDidFinish];
        return;
    }
    [self changeButtonStatusWithRecording:YES];
    [self changeRecordTipsWithRecordingStatus:YES];
    
    [self changeButtonStatusWithObtainVideoWay:ObtainVideoWayRecord];
    NSString *outputFilePath = [[RecordStorage sharedInstance] createFragmentFile];
    NSURL *fileUrl = [NSURL fileURLWithPath:outputFilePath];
//    NSLog(@"file url---->%@",fileUrl);
    [_movieFileOutPut startRecordingToOutputFileURL:fileUrl recordingDelegate:self];
}

- (void)performStopRecording{
    [self changeButtonStatusWithRecording:NO];
    [self changeRecordTipsWithRecordingStatus:NO];
    
    if (_recordToEnd) {
        return;
    }
    [_movieFileOutPut stopRecording];
}

- (void)showAuthorityAlertWithTitle:(NSString *)title{
//#warning TEST!!!!!!!!!!!!!!!!!!!!!!!!!!
//    return;
//    if ([Helper isGreaterOrEqualToIOS8]) {
//        [UIAlertView showWithTitle:title message:@"" cancelButtonTitle:@"取消" otherButtonTitles:@[@"去设置"] tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
//            if (buttonIndex != alertView.cancelButtonIndex) {
//                NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
//                [[UIApplication sharedApplication] openURL:url];
//            }
//            [self dismissViewControllerAnimated:YES completion:nil];
//        }];
//    }else{
//        [UIAlertView showWithTitle:title message:@"" cancelButtonTitle:@"确定" otherButtonTitles:nil tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
//            if (buttonIndex == alertView.cancelButtonIndex) {
//                [self dismissViewControllerAnimated:YES completion:nil];
//            }
//        }];
//    }
}
@end
