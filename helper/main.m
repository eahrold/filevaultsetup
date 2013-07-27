//
//  main.m
//  helper
//
//  Created by Eldon Ahrold on 7/26/13.
//  Copyright (c) 2013 Simon Fraser Universty. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FVSHelper.h"

static const NSTimeInterval kHelperCheckInterval = 1.0; // how often to check whether to quit


int main(int argc, const char *argv[])
{
    // LaunchServices automatically registers a mach service of the same
	// name as our bundle identifier.  This is the same as MachService key in
    // the SMJobBlessHelper-Launchd.plist
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSXPCListener *listener = [[NSXPCListener alloc] initWithMachServiceName:bundleID];
    
    // Create the delegate of the listener.
    FVSHelper *sharedAgent = [FVSHelper new];
    listener.delegate = sharedAgent;
    
    // Begin accepting incoming connections.
	// For mach service listeners, the resume method returns immediately so
	// we need to start our event loop manually.
    [listener resume];
    NSRunLoop * helperLoop = [NSRunLoop currentRunLoop];
    
    while (!sharedAgent.helperToolShouldQuit)
    {
        [helperLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kHelperCheckInterval]];
    }
	return 0;
}