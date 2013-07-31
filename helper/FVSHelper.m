//
//  FVSHelper.m
//  FileVault Setup
//
//  Created by Eldon Ahrold on 7/26/13.
//  Copyright (c) 2013 Simon Fraser Universty. All rights reserved.
//

#import "FVSHelper.h"
#import <syslog.h>


@implementation FVSHelper

@synthesize helperToolShouldQuit;

- (void)runFileVaultSetupHelperForUser:(NSString *)name
                    withPassword:(NSString *)passwordString
                     andSettings:(NSArray *)settings
                       withReply:(void (^)(NSString* result,NSString *error,NSDictionary *keys))reply{
    
    syslog(LOG_ALERT, "Running  fdesetup...");

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
    [outHandle closeFile];

    
    // Get reply items
    NSString* result = [NSString stringWithFormat:@"%d",[theTask terminationStatus]];
            // int won't go over NSXPC so make it a NSString and fix on other side.
    
    
//    NSString *error = @"bypassing the actual test";
//    NSString* result = @"0";
    NSDictionary *keys = [NSDictionary dictionaryWithContentsOfFile:outputFile];
    
    reply(result,error,keys);

}

-(void)escrowKeyForUser:(NSString*)user onServer:(NSString*)server
               withKeys:(NSDictionary*)keys withReply:(void (^)(NSError *error))reply{
    NSError* error = nil;
    NSURLResponse* response = nil;
    
    NSString* serialNumber = [keys valueForKey:@"SerialNumber"];
    NSString* recoveryKey = [keys valueForKey:@"RecoveryKey"];
    NSString* hostName = [[NSHost currentHost] localizedName];
    
    NSString *stringData=[NSString stringWithFormat:@"serial=%@&recovery_password=%@&username=%@&macname=%@",serialNumber,recoveryKey,user,hostName];
    
    
    // Create the request.
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:server]];
    
    // set as POST request
    request.HTTPMethod = @"POST";
    
    // set header fields
    [request setValue:@"application/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    
    // Convert data and set request's HTTPBody property
    NSData *requestBodyData = [stringData dataUsingEncoding:NSUTF8StringEncoding];
    request.HTTPBody = requestBodyData;
    
    // Create url connection and fire request
    //NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    reply(error);
}
-(void)restartByHelper{
    
    syslog(LOG_ALERT, "Restarting Computer");

    // Task Setup
    NSTask *theTask = [[NSTask alloc] init];
    [theTask setLaunchPath:@"/sbin/reboot"];
    
    // Task Run
    [theTask launch];    
}


-(void)helperQuitSelf{
    syslog(LOG_ALERT, "quitting helper");
    self.helperToolShouldQuit = YES;
}

-(void)helperStartSelf{
    syslog(LOG_ALERT, "Starting Helper");
    //nothing here, just brings the helper up.
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
