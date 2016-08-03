//
//  LexifoneTranslatreUploadS3.h
//  TimeToCall
//
//  Created by Tony Hung on 7/13/16.
//  Copyright © 2016 Vonage. All rights reserved.k
//

#import <Foundation/Foundation.h>
#import <AWSCore/AWSCore.h>

typedef enum {
    LexifoneTranslateUploadModeGoogleAPI,
    LexifoneTranslateUploadModeSFAPI,
} LexifoneTranslateUploadMode;

@interface LexifoneTranslateUploadS3 : NSObject

@property (nonatomic, assign)LexifoneTranslateUploadMode translateMode;

+(LexifoneTranslateUploadS3*) sharedManager;

- (void)writeTranslationToFileWithText:(NSString *)text;
- (void)clearContentsOfTranslationFile;
@end

