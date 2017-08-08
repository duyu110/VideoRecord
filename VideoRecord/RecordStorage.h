//
//  RecordStorage.h
//  guimiquan
//
//  Created by Chen Rui on 7/15/15.
//  Copyright (c) 2015 Vanchu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RecordStorage : NSObject

@property (assign, nonatomic, readonly) NSInteger numberOfFragmentFiles;

+ (instancetype)sharedInstance;

- (void)reset;
- (NSString *)createFragmentFile;

- (void)nextFragmentFile;
- (void)rewindFragementFile;

- (NSURL *)getFragmentFileAsURLAtIndex:(NSInteger)index;

- (NSURL *)createTempFile;

@end
