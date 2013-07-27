//
//  FVSHelper.m
//  FileVault Setup
//
//  Created by Eldon Ahrold on 7/26/13.
//  Copyright (c) 2013 Simon Fraser Universty. All rights reserved.
//

#import "FVSHelper.h"


@implementation FVSHelper

@synthesize helperToolShouldQuit;

- (void)runFileVaultSetupForUser:(NSString *)name
                    withPassword:(NSString *)passwordString
                     andSettings:(NSMutableArray *)settings
                       withReply:(void (^)(int result,NSString *error))reply{
    
    //set up task args
    NSArray *task_args = [NSArray arrayWithArray:settings];
    
    // Property List Out
    NSString *outputFile = @"/private/var/root/fdesetup_output.plist";
    [[NSFileManager defaultManager] createFileAtPath:outputFile
                                            contents:nil
                                          attributes:nil];
    NSFileHandle *outHandle = [NSFileHandle
                               fileHandleForWritingAtPath:outputFile];
    
    // The Property List for Input
    NSDictionary *input = @{ @"Username" : name, @"Password" : passwordString };
    
    // Task Setup
    NSTask *theTask = [[NSTask alloc] init];
    [theTask setLaunchPath:@"/usr/bin/fdesetup"];
    [theTask setArguments:task_args];
    [theTask setStandardOutput:outHandle];
    
    NSPipe *errorPipe = [NSPipe pipe];
    [theTask setStandardError:errorPipe];
    
    NSPipe *inputPipe = [NSPipe pipe];
    [theTask setStandardInput:inputPipe];
    NSFileHandle *writeHandle = [inputPipe fileHandleForWriting];
    
    // Task Run
    [theTask launch];
    
    // Task Input
    NSData *data = [NSPropertyListSerialization
                    dataFromPropertyList:input
                    format:NSPropertyListBinaryFormat_v1_0
                    errorDescription:nil];
    
    [writeHandle writeData:data];
    [writeHandle closeFile];
    
    // Task Error
    NSString *error = [[NSString alloc]
                       initWithData:[[errorPipe fileHandleForReading]
                                     readDataToEndOfFile]
                       encoding:NSUTF8StringEncoding];
    
   
    // Clean up
    [theTask waitUntilExit];
    
    // Close
    int result = [theTask terminationStatus];
    //[self setSetupError:error];
    reply(result,error);

}

-(void)restartByHelper;

{
    
    // Task Setup
    NSTask *theTask = [[NSTask alloc] init];
    [theTask setLaunchPath:@"/sbin/reboot"];
    
    // Task Run
    [theTask launch];
    
}


-(void)quitHelper{
    self.helperToolShouldQuit = YES;
}

-(void)startHelper{
    
}

//----------------------------------------
// Helper Singleton
//----------------------------------------
+ (FVSHelper *)sharedAgent {
    static dispatch_once_t onceToken;
    static FVSHelper *shared;
    dispatch_once(&onceToken, ^{
        shared = [FVSHelper new];
    });
    return shared;
}


//----------------------------------------
// Set up the one method of NSXPClistener
//----------------------------------------
- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(FVSHelperAgent)];
    newConnection.exportedObject = self;
    
    newConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(FVSHelperProgress)];
    self.xpcConnection = newConnection;
    
    [newConnection resume];
    return YES;
}


@end
