//
//  FVSSetupWindowController.m
//  FileVault Setup
//
//  Created by Brian Warsing on 2013-03-05.

/*
 * Copyright (c) 2013 Simon Fraser Universty. All rights reserved.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FVSSetupWindowController.h"

@implementation FVSSetupWindowController

static int   numberOfShakes  = 4;
static float durationOfShake = 0.4f;
static float vigourOfShake   = 0.02f;

@synthesize password = _password;
@synthesize spinner  = _spinner;
@synthesize setup    = _setup;
@synthesize cancel   = _cancel;

- (id)init
{
    self = [super initWithWindowNibName:@"FVSSetupWindowController"];
        username = NSUserName();
    return self;
}

// All credit to Matt Long
// This function was lifted directly from his awesome blog.
// http://www.cimgf.com/2008/02/27/core-animation-tutorial-window-shake-effect/
- (CAKeyframeAnimation *)shakeAnimation:(NSRect)frame
{
    CAKeyframeAnimation *shakeAnimation = [CAKeyframeAnimation animation];
	
    CGMutablePathRef shakePath = CGPathCreateMutable();
    CGPathMoveToPoint(shakePath, NULL, NSMinX(frame), NSMinY(frame));
	int index;
	for (index = 0; index < numberOfShakes; ++index)
	{
		CGPathAddLineToPoint(shakePath,
                             NULL,
                             NSMinX(frame) - frame.size.width * vigourOfShake,
                             NSMinY(frame));
		CGPathAddLineToPoint(shakePath,
                             NULL,
                             NSMinX(frame) + frame.size.width * vigourOfShake,
                             NSMinY(frame));
	}
    CGPathCloseSubpath(shakePath);
    shakeAnimation.path = shakePath;
    shakeAnimation.duration = durationOfShake;
    CFRelease(shakePath);
    return shakeAnimation;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
}

- (IBAction)setupAction:(NSButton *)sender
{
    if ([self passwordMatch:[_password stringValue] forUsername:username]) {
        [self runFileVaultSetupForUser:username
                          withPassword:[_password stringValue]];
    } else {
        // Shake it!
        [self harlemShake:@"Password Incorrect"];
    }
}

- (IBAction)cancelAction:(NSButton *)sender
{
    [NSApp endSheet:[self window] returnCode:-1];
}

- (BOOL)passwordMatch:(NSString *)password forUsername:(NSString *)name
{
    BOOL match = NO;
	ODSessionRef session = NULL;
	ODNodeRef node = NULL;
	ODRecordRef	rec = NULL;
    
    session = ODSessionCreate(NULL, NULL, NULL);
    node = ODNodeCreateWithNodeType(NULL,
                                    session,
                                    kODNodeTypeAuthentication,
                                    NULL);

    if (node) {
        rec = ODNodeCopyRecord(node,
                               kODRecordTypeUsers,
                               (__bridge CFStringRef)(name),
                               NULL,
                               NULL);
      
  
        if (rec) {
            match = ODRecordVerifyPassword(rec,
                                           (__bridge CFStringRef)(password),
                                           NULL);
            CFRelease(rec);
        }
        
        CFRelease(node);
    }

    CFRelease(session);
    return match;
}

- (void)harlemShake:(NSString *)message
{
    [_message setStringValue:message];
    [_sheet setAnimations:[NSDictionary
                           dictionaryWithObject:[self
                                                 shakeAnimation:[_sheet frame]]
                           forKey:@"frameOrigin"]];
	[[_sheet animator] setFrameOrigin:[_sheet frame].origin];
}

- (void)runFileVaultSetupForUser:(NSString *)name
                    withPassword:(NSString *)passwordString
{
    // UI Setup
    [_setup setEnabled:NO];
    [_cancel setEnabled:NO];
    [_message setStringValue:@"Running..."];
    [_spinner startAnimation:self];

    // Setup Task args here and pass over to the helper app
    NSMutableArray *task_args = [NSMutableArray arrayWithObjects:@"enable",
                                 @"-outputplist", @"-inputplist", nil];
    
    if (![[[NSUserDefaults standardUserDefaults]
          valueForKeyPath:FVSCreateRecoveryKey] boolValue]) {
        [task_args insertObject:@"-norecoverykey" atIndex:1];
    }
    
    if ([[[NSUserDefaults standardUserDefaults]
          valueForKeyPath:FVSUseKeychain] boolValue]) {
        [task_args insertObject:@"-keychain" atIndex:1];
    }
        
    NSXPCConnection *connection = [[NSXPCConnection alloc]
                                   initWithMachServiceName:kHelperName options:NSXPCConnectionPrivileged];
    
    connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(FVSHelperAgent)];
    connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(FVSHelperProgress)];
    connection.exportedObject = self;
    [connection resume];
    [[connection remoteObjectProxy] runFileVaultSetupHelperForUser:name withPassword:passwordString andSettings:task_args withReply:^(NSString* result,NSString *error) {
                                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                        [self setSetupError:error];
                                        [NSApp endSheet:[self window] returnCode:[result intValue]];

                                    }];
                                    [connection invalidate];
                                }];
}

- (void)dealloc
{
}

@end
