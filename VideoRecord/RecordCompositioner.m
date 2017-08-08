//
//  RecordCompositioner.m
//  guimiquan
//
//  Created by vanchu on 15/6/30.
//  Copyright (c) 2015年 Vanchu. All rights reserved.
//

#import "RecordCompositioner.h"
#import <AVFoundation/AVFoundation.h>
#import "RecordStorage.h"

@interface RecordCompositioner()
{
    NSInteger    _numberOfFilesInGroup;
    NSURL       *_currentURL;
}
@end

@implementation RecordCompositioner

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (void)mergeAndExportVideoWithComplete:(void (^)(NSURL *url))complete failed:(void (^)(NSError *error))fail {
    //    当前段每次与多少段合并，由于ios一次最多只能合并16段，所以此处设置为15
    _numberOfFilesInGroup = 15;
    
    _currentURL = [[RecordStorage sharedInstance] getFragmentFileAsURLAtIndex:0];

    [self _mergeWithVideoAtIndex:1 complete:^(NSURL *url) {
            complete(url);
    }failed:^(NSError *error) {
        fail(error);
    }];
}

- (void)_mergeWithVideoAtIndex:(NSInteger)index complete:(void (^)(NSURL *url))complete failed:(void (^)(NSError *error))fail{
	if (index >= [RecordStorage sharedInstance].numberOfFragmentFiles) {
//        已经经过剪切以及方向等处理
        if ([RecordStorage sharedInstance].numberOfFragmentFiles>1) {
            complete(_currentURL);
            
            return;
        }
        [self _doMergeWithFileUrls:@[_currentURL] withComplete:^(NSURL *url, NSError *error) {
            if (error) {
                fail(error);
            }else{
                complete(_currentURL);
            }
        }];
    }else {
        NSMutableArray *fileUrls = [NSMutableArray array];
        NSInteger mergeCount = MIN(_numberOfFilesInGroup, [RecordStorage sharedInstance].numberOfFragmentFiles-index);
        [fileUrls addObject:_currentURL];
        for (NSInteger i = index; i<index + mergeCount; i++) {
            [fileUrls addObject:[[RecordStorage sharedInstance] getFragmentFileAsURLAtIndex:i]];
        }
        [self _doMergeWithFileUrls:fileUrls withComplete:^(NSURL *url, NSError *error) {
            if (error) {
                fail(error);
            }else{
                [self _mergeWithVideoAtIndex:index+mergeCount complete:complete failed:fail];
            }
        }];
	}
}

- (void)_doMergeWithFileUrls:(NSArray *)fileUrls withComplete:(void (^)(NSURL *url,NSError *error))finish{
    
    NSError *error = nil;
    CGSize renderSize = CGSizeMake(0, 0);
    
    NSMutableArray *layerInstructions = [NSMutableArray array];
    AVMutableComposition *mixComposition = [AVMutableComposition composition];
    
    CMTime totalDuration = kCMTimeZero;
    
    NSMutableArray *videoAssetTracks = [NSMutableArray array];
    NSMutableArray *audioAssetTracks = [NSMutableArray array];
    NSMutableArray *assets = [NSMutableArray array];
    
    for (NSURL *fileURL in fileUrls) {
        AVAsset *asset = [AVAsset assetWithURL:fileURL];
        NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
        NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
        
        if (!videoTracks||(videoTracks.count==0)||
            !audioTracks||(audioTracks.count==0)){
            continue;
        }
        
        [assets addObject:asset];
        AVAssetTrack *videoTrack = videoTracks[0];
        AVAssetTrack *audioTrack = audioTracks[0];
        [videoAssetTracks addObject:videoTrack];
        [audioAssetTracks addObject:audioTrack];
        
        renderSize.width = MAX(renderSize.width, videoTrack.naturalSize.height);
        renderSize.height = MAX(renderSize.height, videoTrack.naturalSize.width);
    }
    
    if (assets.count == 0) {
        finish(nil,[NSError errorWithDomain:@"data" code:-1 userInfo:@{@"info":@"have no data file to merge!"}]);
        return;
    }
    
    CGFloat renderW = MIN(renderSize.width, renderSize.height);
    
    AVMutableCompositionTrack *audioCompositionTrack =[mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                                  preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *videoCompositionTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                                   preferredTrackID:kCMPersistentTrackID_Invalid];
    
    for (int i = 0; i < [assets count] && i < MIN(videoAssetTracks.count, audioAssetTracks.count); i++) {
        
        AVAsset *asset = [assets objectAtIndex:i];
        AVAssetTrack *videoTrack = videoAssetTracks[i];
        AVAssetTrack *audioTrack = audioAssetTracks[i];
      
        [audioCompositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                                ofTrack:audioTrack
                                 atTime:totalDuration
                                  error:nil];
        [videoCompositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                            ofTrack:videoTrack
                             atTime:totalDuration
                              error:&error];
        //fix orientationissue
        AVMutableVideoCompositionLayerInstruction *layerInstruciton = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoCompositionTrack];
        
        totalDuration = CMTimeAdd(totalDuration, asset.duration);
        
        CGFloat rate;
        rate = renderW / MIN(videoTrack.naturalSize.width, videoTrack.naturalSize.height);
        
        CGAffineTransform layerTransform = CGAffineTransformMake(videoTrack.preferredTransform.a, videoTrack.preferredTransform.b, videoTrack.preferredTransform.c, videoTrack.preferredTransform.d, videoTrack.preferredTransform.tx * rate, videoTrack.preferredTransform.ty * rate);
        layerTransform = CGAffineTransformConcat(layerTransform, CGAffineTransformMake(1, 0, 0, 1, 0, -(videoTrack.naturalSize.width - videoTrack.naturalSize.height) / 2.0));//向上移动取中部影响
        layerTransform = CGAffineTransformScale(layerTransform, rate, rate);//放缩，解决前后摄像结果大小不对称
        
        [layerInstruciton setTransform:layerTransform atTime:kCMTimeZero];
        [layerInstruciton setOpacity:0.0 atTime:totalDuration];
        
////        data
        [layerInstructions addObject:layerInstruciton];
    }
    
    //get save path
    NSURL *mergeFileURL = [[RecordStorage sharedInstance] createTempFile];
    
    //export
    AVMutableVideoCompositionInstruction *mainInstruciton = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruciton.timeRange = CMTimeRangeMake(kCMTimeZero, totalDuration);
    mainInstruciton.layerInstructions = layerInstructions;
    AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
    mainCompositionInst.instructions = @[mainInstruciton];
    mainCompositionInst.frameDuration = CMTimeMake(1, 15);
    mainCompositionInst.renderSize = CGSizeMake(renderW, renderW);
    
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetMediumQuality];
    exporter.videoComposition = mainCompositionInst;
    exporter.outputURL = mergeFileURL;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            _currentURL = exporter.outputURL;
            finish(exporter.outputURL,exporter.error);
        });
    }];
}


@end
