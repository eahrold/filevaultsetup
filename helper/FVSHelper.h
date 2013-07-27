//
//  FVSHelper.h
//  FileVault Setup
//
//  Created by Eldon Ahrold on 7/26/13.
//  Copyright (c) 2013 Simon Fraser Universty. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "Interfaces.h"


@interface FVSHelper : NSObject <FVSHelperAgent,NSXPCListenerDelegate>
@property (nonatomic, assign) BOOL helperToolShouldQuit;

+ (FVSHelper *)sharedAgent;

@property (weak) NSXPCConnection *xpcConnection;

@end
