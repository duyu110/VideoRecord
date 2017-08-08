//
//  ViewController.m
//  VideoRecord
//
//  Created by user on 15/10/20.
//  Copyright © 2015年 user. All rights reserved.
//

#import "BasicController.h"
#import "CommonVideoRecorder.h"

@interface BasicController ()

@end

@implementation BasicController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)enterClick:(UIButton *)sender {
    
    CommonVideoRecorder *vc = [[UIStoryboard storyboardWithName:@"CommonVideo" bundle:nil] instantiateViewControllerWithIdentifier:@"CommonVideoRecorder"];
    [self presentViewController:vc animated:YES completion:nil];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
