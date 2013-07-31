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
-(void)restartByHelper;

-(void)runFileVaultSetupHelperForUser:(NSString *)name
                    withPassword:(NSString *)passwordString
                     andSettings:(NSArray *)settings
                       withReply:(void (^)(NSString* result,NSString *error,NSDictionary *key))reply;

-(void)escrowKeyForUser:(NSString*)user onServer:(NSString*)server
               withKeys:(NSDictionary*)keys withReply:(void (^)(NSError *error))reply;

@end


@protocol FVSHelperProgress

@end