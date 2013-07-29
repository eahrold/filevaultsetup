//
//  FVSHelperAgent.h
//  FileVault Setup
//
//  Created by Eldon Ahrold on 7/26/13.
//  Copyright (c) 2013 Simon Fraser Universty. All rights reserved.
//

#import <Foundation/Foundation.h>
#define kHelperName @"ca.sfu.its.filevaultsetup.helper"

@protocol FVSHelperAgent <NSObject>

-(void)helperQuitSelf;
-(void)helperStartSelf;
-(void)helperCheckSelf;

-(void)restartByHelper;

-(void)runFileVaultSetupHelperForUser:(NSString *)name
                    withPassword:(NSString *)passwordString
                     andSettings:(NSMutableArray *)settings
                       withReply:(void (^)(int result,NSString *error))reply;

@end

@protocol FVSHelperProgress

@end