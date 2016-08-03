//
//  LexifoneTranslatreUploadS3.m
//  TimeToCall
//
//  Created by Tony Hung on 7/13/16.
//  Copyright © 2016 Vonage. All rights reserved.
//

#import "LexifoneTranslateUploadS3.h"
#import <AWSS3/AWSS3.h>
#import <AWSCore/AWSCore.h>
#import "Constants.h"

#define UPLOAD_INTERVAL 30 // 3 minutes
@interface LexifoneTranslateUploadS3 ()

@property (strong) AWSS3TransferManagerUploadRequest *uploadRequest;
@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSTimer *uploadTimer;
@end

@implementation LexifoneTranslateUploadS3


+(LexifoneTranslateUploadS3*) sharedManager {
    
    static LexifoneTranslateUploadS3 *sharedManager = NULL;
    
    if(!sharedManager) {
        sharedManager = [[LexifoneTranslateUploadS3 alloc] init];
    }
    return sharedManager;
}

- (void)writeTranslationToFileWithText:(NSString *)text {

    NSString *translationFilePath = [self translationFilePath];
    if (![[NSFileManager defaultManager]fileExistsAtPath:translationFilePath]) {
        BOOL fileCreated = [[NSFileManager defaultManager]createFileAtPath:translationFilePath contents:nil attributes:nil];
        if (!fileCreated) {
            NSLog(@"file not created");
        }
    }
    
    NSFileHandle *myHandle = [NSFileHandle fileHandleForWritingAtPath:translationFilePath];
    [myHandle seekToEndOfFile];
    [myHandle writeData:[text dataUsingEncoding:NSUTF8StringEncoding]];
    
//    if (self.uploadTimer == nil) {
//        self.uploadTimer = [NSTimer scheduledTimerWithTimeInterval:UPLOAD_INTERVAL target:self selector:@selector(uploadTranslationFile) userInfo:nil repeats:YES];
//        [self.uploadTimer fire];
//    }
    [self uploadTranslationFile];
}

- (void)clearContentsOfTranslationFile {
    
    __weak LexifoneTranslateUploadS3 * weakSelf = self;

    [self uploadTranslationFileWithCompletionBlock:^(BOOL success) {
        if (success) {
            [weakSelf reset];
        }
    }];
    
    }

- (void)reset {
    NSString *translationFilePath = [self translationFilePath];

    if ([[NSFileManager defaultManager]fileExistsAtPath:translationFilePath]) {
        NSError *removeFileError = nil;
        
        [[NSFileManager defaultManager]removeItemAtPath:translationFilePath error:&removeFileError];
        if (removeFileError == nil) {
            NSLog(@"translate file Removed");
            _uuid = nil;
            [self.uploadTimer invalidate];
            self.uploadTimer = nil;
        }
    }

}

-(NSString *)translationFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains
    (NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [NSString stringWithFormat:@"%@/translation-%@_%@.txt",
            documentsDirectory,(self.translateMode == LexifoneTranslateUploadModeGoogleAPI ? @"gAPI" : @"iosAPI"), [self uuid]];
}

- (NSString *)uuid {
    
    if (_uuid == nil) {
        _uuid = [[NSUUID UUID] UUIDString];
        return _uuid;
    }
    
    return _uuid;
}

- (void)uploadTranslationFile {
    [self uploadTranslationFileWithCompletionBlock:nil];
}

- (void)uploadTranslationFileWithCompletionBlock:(void (^)(BOOL success))completionBlock {
    
    NSString *filePath = [self translationFilePath];
    NSURL *filePathURL = [NSURL fileURLWithPath:filePath];
    if (![[NSFileManager defaultManager]fileExistsAtPath:filePath]) {
        return;
    }
    
    NSLog(@"uploading %@",filePath);


    NSData *data = [[NSFileManager defaultManager] contentsAtPath:[filePathURL absoluteString]];
    
    AWSStaticCredentialsProvider *credentialsProvider = [[AWSStaticCredentialsProvider alloc] initWithAccessKey:kAWSKey
                                                                                                      secretKey:kAWSSecret];
    
    AWSServiceConfiguration *serviceConfiguration = [[AWSServiceConfiguration alloc]initWithRegion:AWSRegionUSEast1 credentialsProvider:credentialsProvider];
    
    [AWSServiceManager defaultServiceManager].defaultServiceConfiguration = serviceConfiguration;
    
    AWSS3TransferManager *transferManager = [AWSS3TransferManager defaultS3TransferManager];
    AWSS3TransferManagerUploadRequest *uploadRequest = [AWSS3TransferManagerUploadRequest new];
    uploadRequest.bucket = kAWSBucket;
    uploadRequest.key = filePath.lastPathComponent;
    uploadRequest.body = filePathURL;
    uploadRequest.contentType = @"text/plain";
    uploadRequest.contentLength = [NSNumber numberWithInteger:[data length]];
    

    [[transferManager upload:uploadRequest] continueWithBlock:^id _Nullable(AWSTask * _Nonnull task) {
        
        if (!task.error) {
            [self sendUUIDWithCompletionBlock:^(BOOL success) {
                if (success) {
                    if (completionBlock) {
                        completionBlock(YES);
                    }
                }
            }];

        } else {
            NSLog(@"AWSUpload Upload Failed, Reason: %@ ErrorCode: %ld", task.error, (long)task.error.code );
        }
        return nil;
    }];
}

- (void)sendUUIDWithCompletionBlock:(void (^)(BOOL success))completionBlock {
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURL *url = [NSURL URLWithString:kBackendURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    NSString *bodyString = [NSString stringWithFormat:@"transcriptId=%@", self.uuid];
    
    request.HTTPBody = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    NSURLSessionDataTask *postDataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString* responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"Send UUID for Translate. ResponseString: %@", responseString);
    }];
    [postDataTask resume];
}
@end

