//
//  FVSAppDelegate.m
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

#import "FVSAppDelegate.h"
#include <SystemConfiguration/SystemConfiguration.h>
#include <IOKit/IOKitLib.h>
#include <DiskArbitration/DASession.h>

NSString * const FVSDoNotAskForSetup     = @"FVSDoNotAskForSetup";
NSString * const FVSForceSetup           = @"FVSForceSetup";
NSString * const FVSUseKeychain          = @"FVSUseKeychain";
NSString * const FVSCreateRecoveryKey    = @"FVSCreateRecoveryKey";
NSString * const FVSEscrowKeyServer      = @"FVSEscrowKeyServer";


@implementation FVSAppDelegate

+ (void)initialize
{
    
    // Register defaults
    NSMutableDictionary *defaultValues = [NSMutableDictionary dictionary];
    [defaultValues setObject:[NSNumber numberWithBool:NO]
                      forKey:FVSDoNotAskForSetup];
    [defaultValues setObject:[NSNumber numberWithBool:NO]
                      forKey:FVSForceSetup];
    [defaultValues setObject:[NSNumber numberWithBool:NO]
                      forKey:FVSUseKeychain];
    [defaultValues setObject:[NSNumber numberWithBool:YES]
                      forKey:FVSCreateRecoveryKey];


    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
    
    // Establish the startup mode
    // Also, hide the menu bar.
    // Is this a forced setup? If not, respect that the user has
    // opted out, and simply exit.

    [NSMenu setMenuBarVisible:NO];
    if (![[[NSUserDefaults standardUserDefaults]
          valueForKeyPath:FVSForceSetup] boolValue]) {
        if ([[[NSUserDefaults standardUserDefaults]
             valueForKeyPath:FVSDoNotAskForSetup] boolValue]) {
            [NSApp disableLaunchAgent];
            exit(0);
        }
    }
}

// Returns the encryption state of the root volume
+ (BOOL)rootVolumeIsEncrypted
{
    CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                 CFSTR("/"),
                                                 kCFURLPOSIXPathStyle,
                                                 true);
    
    DASessionRef session = DASessionCreate(kCFAllocatorDefault);
    DADiskRef disk = DADiskCreateFromVolumePath(kCFAllocatorDefault,
                                                session,
                                                url);
    
    io_service_t diskService = DADiskCopyIOMedia(disk);
    CFTypeRef isEncrypted = IORegistryEntryCreateCFProperty(diskService,
                                                            CFSTR("CoreStorage Encrypted"),
                                                            kCFAllocatorDefault,
                                                            0);
    
    BOOL state = NO;
    if (isEncrypted) {
        CFRelease(isEncrypted);
        state = YES;
    }
    
    CFRelease(disk);
    CFRelease(url);
    CFRelease(session);
    IOObjectRelease(diskService);
    
    return state;
}

- (IBAction)showSetupSheet:(id)sender
{
    if (!setupController) {
        setupController = [[FVSSetupWindowController alloc] init];
    }
    
    [NSApp beginSheet: [setupController window]
       modalForWindow: _window
        modalDelegate: self
       didEndSelector: @selector(didEndSetupSheet:returnCode:)
          contextInfo: NULL];
}

- (IBAction)didEndSetupSheet:(id)sender returnCode:(int)result
{
    // Error
    NSString *error = [setupController setupError];

    [NSApp endSheet:[setupController window]];
    [[setupController window] orderOut:sender];
    setupController = nil;
    
    // Basic Alert
    NSAlert *alert = [[NSAlert alloc] init];
    SEL theSelector = @selector(setupDidEndWithError:);
    
    // What kind of alert?
    if (result == -1) {
        // Cancelled
        NSLog(@"User canceled operation");
    } else if (result == 0) {
        // Success
        theSelector = @selector(setupDidEndWithSuccess:);
        [alert setMessageText:@"Restart Required"];
        [alert setInformativeText:@"Click OK to restart and complete the setup."];
    }else if (result == 2){
        // Success, but couldn't uplaod Key to server
        theSelector = @selector(setupDidEndWithKeyNeedsUploading:);
        [alert setMessageText:@"Restart Required"];
        [alert setInformativeText:@"Drive Encryption succeeded, but we couldn't upload the key to the server.  Click OK to restart and complete the setup."];
    } else {
        // Failure
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert setMessageText:@"FileVault Setup Error"];
        [alert setInformativeText:
            [error stringByAppendingString:[NSString stringWithFormat:@" [%d]",
                                         result]]];
    }
    
    // Only alert on error or success, not on cancel
    if (result > -1) {
        NSLog(@"%@ [%d]", error, result);
        [alert beginSheetModalForWindow:_window
                          modalDelegate:self
                         didEndSelector:theSelector
                            contextInfo:nil];
    }
    
}

- (void)setupDidEndWithError:(NSAlert *)alert
{
    NSLog(@"Setup encountered an error.");
}

- (void)setupDidEndWithSuccess:(NSAlert *)alert
{
    NSLog(@"Setup complete. Restarting...");
    [self disableLaunchAgent];
    [_window orderOut:self];
    [self restart];
}

- (void)setupDidEndWithKeyNeedsUploading:(NSAlert *)alert
{
    NSLog(@"Setup complete. Restarting...");
    [self disableLaunchAgent];
    [_window orderOut:self];
    [self restart];
}

- (void)setupDidEndWithAlreadyEnabled:(NSAlert *)alert
{
    NSLog(@"FileVault is already enabled.");
    [self disableLaunchAgent];
    [_window close];
}

- (void)setupDidEndWithNotRoot:(NSAlert *)alert
{
    NSLog(@"You must be an administrator to enable FileVault.");
    [_window close];
}


- (IBAction)enable:(id)sender
{
    [self showSetupSheet:nil];
}

- (IBAction)noEnable:(id)sender
{
    [_window close];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)theApplication
{
    return YES;
}

-(void)applicationWillTerminate:(NSNotification *)notification{
    [self quitHelper];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self startHelper];
    // Insert code here to initialize your application
    BOOL forcedSetup = [[[NSUserDefaults standardUserDefaults]
                        valueForKeyPath:FVSForceSetup] boolValue];
    
    if (forcedSetup) {
        [_instruct setFont:[NSFont
                            fontWithName:@"Lucida Grande Bold" size:13.0]];
        [_instruct setStringValue:@"Policy set by your administrator requires \
that you activate FileVault before you can login to this workstation. Please \
click the enable button to continue."];
    }
    
    
    [_window makeKeyAndOrderFront:NSApp];
    [_window setCanBecomeVisibleWithoutLogin:YES];
    [_window setLevel:2147483631];
    [_window orderFrontRegardless];
    [_window makeKeyWindow];
    [_window becomeMainWindow];
    [_window center];
    
    // Is FileVault enabled?
    BOOL fvstate = [FVSAppDelegate rootVolumeIsEncrypted];
    
    
    if (fvstate == YES) {
        // ALERT
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Already Enabled"];
        [alert setInformativeText:@"FileVault has already been enabled."];
        [alert beginSheetModalForWindow:_window
                          modalDelegate:self
                         didEndSelector:@selector(setupDidEndWithAlreadyEnabled:)
                            contextInfo:nil];
    }
}

- (void)restart
{
    NSXPCConnection *connection = [[NSXPCConnection alloc]
                                   initWithMachServiceName:kHelperName options:NSXPCConnectionPrivileged];
    
    connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(FVSHelperAgent)];
    connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(FVSHelperProgress)];
    connection.exportedObject = self;
    [connection resume];
    [[connection remoteObjectProxy] restartByHelper];
    [connection invalidate];
    [_window close];
}

-(void)startHelper{
    NSXPCConnection *connection = [[NSXPCConnection alloc] initWithMachServiceName:kHelperName options:NSXPCConnectionPrivileged];
    
    connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(FVSHelperAgent)];
    [connection resume];
    [[connection remoteObjectProxy] helperStartSelf];
    [connection invalidate];
}

-(void)quitHelper{
    NSXPCConnection *connection = [[NSXPCConnection alloc] initWithMachServiceName:kHelperName options:NSXPCConnectionPrivileged];
    
    connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(FVSHelperAgent)];
    [connection resume];
    [[connection remoteObjectProxy] helperQuitSelf];
    [connection invalidate];
}

-(void)disableLaunchAgent{
    NSString *launchAgent = @"/Library/LaunchAgents/ca.sfu.its.filevaultsetup-launcher.plist";
    if (![[NSFileManager defaultManager] fileExistsAtPath:launchAgent]){
        return;
    }
    
    // Task Setup
    NSTask *theTask = [[NSTask alloc] init];
    [theTask setLaunchPath:@"/bin/launchctl"];
    
    NSArray *task_args = [NSArray arrayWithObjects:@"unload",@"-w",launchAgent, nil];
    [theTask setArguments:task_args];
    
    NSPipe *errorPipe = [NSPipe pipe];
    [theTask setStandardError:errorPipe];
    
    [theTask launch];
    [theTask waitUntilExit];
}
@end
