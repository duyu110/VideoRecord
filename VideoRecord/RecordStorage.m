//
//  RecordStorage.m
//  guimiquan
//
//  Created by Chen Rui on 7/15/15.
//  Copyright (c) 2015 Vanchu. All rights reserved.
//

#import "RecordStorage.h"
//#import "Helper+String.h"

static NSString *VIDEO_FOLDER = @"videos";

@interface RecordStorage()
{
	NSInteger          _numberOfFragmentFiles;
    NSMutableArray    *_fileNames;
    NSString          *_currentFileName;
}
@property (strong, nonatomic, readonly) NSString *workingDirectory;
@end

@implementation RecordStorage

+ (instancetype)sharedInstance {
	static RecordStorage *thiz = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		thiz = [[RecordStorage alloc] init];
	});
	return thiz;
}

- (instancetype)init {
	if (self = [super init]) {
		[self reset];
	}
	return self;
}

- (void)reset {
	_numberOfFragmentFiles = 0;
    _fileNames = [NSMutableArray array];
    
	if ([[NSFileManager defaultManager] fileExistsAtPath:self.workingDirectory]) {
		[[NSFileManager defaultManager] removeItemAtPath:self.workingDirectory error:nil];
	}
	
	if (![[NSFileManager defaultManager] createDirectoryAtPath:self.workingDirectory withIntermediateDirectories:YES attributes:nil error:nil]) {
		[NSException raise:@"Operation failed" format:@"failed to create dir %@", self.workingDirectory];
	}
}

- (NSString *)createFragmentFile {
//    AVCaptureSession有一个bug：在startRunning和stopRunning之间，只能出现之前没提供过的文件名，与文件存在与否无关
    NSString *uniqString = @"";//[Helper stringCreateAsUuid];
    NSString *fileName = [[self workingDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4",uniqString]];
    _currentFileName = fileName;
    return fileName;
}

- (void)nextFragmentFile {
	_numberOfFragmentFiles++;
    [_fileNames addObject:_currentFileName];
}

- (void)rewindFragementFile {
	if (_numberOfFragmentFiles > 0&&_fileNames.count>0) {
        _numberOfFragmentFiles--;
        [_fileNames removeLastObject];
	}
}

- (NSURL *)getFragmentFileAsURLAtIndex:(NSInteger)index {
	if ((index < 0) || (index >= _numberOfFragmentFiles)) {
		return nil;
	}
    return [NSURL fileURLWithPath:_fileNames[index]];
}

- (NSInteger)numberOfFragmentFiles {
	return _numberOfFragmentFiles;
}

- (NSURL *)createTempFile{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"YYYYMMddhhmmss"];
    return [NSURL fileURLWithPath:[self.workingDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@.mp4",[formatter stringFromDate:[NSDate date]],@(arc4random()%1000)]]];
}

#pragma mark - Getters
- (NSString *)workingDirectory {
	static NSString *s_workingDirectory = nil;
	if (s_workingDirectory == nil) {
		s_workingDirectory = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:VIDEO_FOLDER];
	}
	return s_workingDirectory;
}

@end
