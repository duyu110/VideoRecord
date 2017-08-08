//
//  RecordCompositioner.h
//  guimiquan
//
//  Created by vanchu on 15/6/30.
//  Copyright (c) 2015年 Vanchu. All rights reserved.
//

#import <Foundation/Foundation.h>
@interface RecordCompositioner : NSObject

- (void)mergeAndExportVideoWithComplete:(void (^)(NSURL *url))complete failed:(void (^)(NSError *error))fail;
@end
