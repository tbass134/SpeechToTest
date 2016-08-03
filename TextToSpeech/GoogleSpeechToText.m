//
// Copyright 2016 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <AVFoundation/AVFoundation.h>

#import "GoogleSpeechToText.h"
#import "AudioController.h"
#import "SpeechRecognitionService.h"
#import "LexifoneTranslateUploadS3.h"

#import "google/cloud/speech/v1beta1/CloudSpeech.pbrpc.h"

#define SAMPLE_RATE 16000.0f

@interface GoogleSpeechToText () <AudioControllerDelegate>

@property (strong, nonatomic) IBOutlet UIButton *startButton;
@property (nonatomic, strong) NSMutableData *audioData;
@property (nonatomic, assign) BOOL isStreaming;
@end

@implementation GoogleSpeechToText

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Google Speech API";
    [AudioController sharedInstance].delegate = self;
    [self.startButton setTitle:@"Start" forState:UIControlStateNormal];
    self.isStreaming = NO;
}

- (IBAction)buttonTapped:(id)sender {
    if (!_isStreaming) {
        [self recordAudio];
        self.isStreaming = YES;
    } else {
        [self stopAudio];
        self.isStreaming = NO;
    }
    _textView.text = @"";
}

- (void)setIsStreaming:(BOOL)isStreaming
{
    if (isStreaming) {
        [self.startButton setTitle:@"Stop" forState:UIControlStateNormal];
    } else {
        [self.startButton setTitle:@"Start" forState:UIControlStateNormal];
    }
    
    _isStreaming = isStreaming;
}

- (void)recordAudio {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryRecord error:nil];
    
    _audioData = [[NSMutableData alloc] init];
    [[AudioController sharedInstance] prepareWithSampleRate:SAMPLE_RATE];
    [[SpeechRecognitionService sharedInstance] setSampleRate:SAMPLE_RATE];
    [[AudioController sharedInstance] start];
}

- (void)stopAudio {
    [[AudioController sharedInstance] stop];
    [[SpeechRecognitionService sharedInstance] stopStreaming];
    [[LexifoneTranslateUploadS3 sharedManager]clearContentsOfTranslationFile];
}

- (void) processSampleData:(NSData *)data
{
    [self.audioData appendData:data];
    NSInteger frameCount = [data length] / 2;
    int16_t *samples = (int16_t *) [data bytes];
    int64_t sum = 0;
    for (int i = 0; i < frameCount; i++) {
        sum += abs(samples[i]);
    }
//    NSLog(@"audio %d %d", (int) frameCount, (int) (sum * 1.0 / frameCount));
    
    // We recommend sending samples in 100ms chunks
    int chunk_size = 0.1 /* seconds/chunk */ * SAMPLE_RATE * 2 /* bytes/sample */ ; /* bytes/chunk */
    
    if ([self.audioData length] > chunk_size) {
        NSLog(@"SENDING");
        [[SpeechRecognitionService sharedInstance] streamAudioData:self.audioData
                                                    withCompletion:^(StreamingRecognizeResponse *response, NSError *error) {
                                                        if (response) {
                                                            BOOL finished = NO;
                                                            
                                                            NSLog(@"RESPONSE RECEIVED");
                                                            if (error) {
                                                                NSLog(@"ERROR: %@", error);
                                                                [self restartAudio];

                                                            } else {
                                                                NSLog(@"RESPONSE: %@", response);
                                                                
                                                                if (response.endpointerType == StreamingRecognizeResponse_EndpointerType_EndOfSpeech | response.endpointerType == StreamingRecognizeResponse_EndpointerType_EndOfAudio) {
//                                                                    [self restartAudio];
                                                                    
                                                                    
                                                                } else {
                                                                    for (StreamingRecognitionResult *result in response.resultsArray) {
                                                                        
                                                                        if (result.isFinal) {
                                                                            finished = YES;
                                                                            
    //                                                                        for (SpeechRecognitionAlternative *alt in result.alternativesArray) {
    //                                                                            if (alt.confidence > 0.7) {
    //                                                                                _textView.text = alt.transcript;
    //                                                                            }
    //                                                                        }
                                                                        }
                                                                        
                                                                        
                                                                    }
                                                                    if (error != nil || finished) {
                                                                        
                                                                        _textView.text = [[response.resultsArray firstObject].alternativesArray firstObject].transcript;
                                                                        [self restartAudio];


    //                                                                    NSLog(@"response %@",response);
                                                                    }
                                                                    //                                                                NSString *translationWithTimestamp = [NSString stringWithFormat:@"<%@>:%@\n",[NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970] * 1000], transcript];
    //                                                                [LexifoneTranslateUploadS3 sharedManager].translateMode = LexifoneTranslateUploadModeGoogleAPI;
    //                                                                [[LexifoneTranslateUploadS3 sharedManager] writeTranslationToFileWithText:translationWithTimestamp];

    //                                                                if (result) {
    //                                                                    if (result.alternativesArray.count) {
    //                                                                        NSString *transcript = [[result.alternativesArray lastObject]transcript];
    //                                                                        
    //                                                                        NSString *translationWithTimestamp = [NSString stringWithFormat:@"<%@>:%@\n",[NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970] * 1000], transcript];
    //                                                                        _textView.text = transcript;
    //                                                                        
    //                                                                        [LexifoneTranslateUploadS3 sharedManager].translateMode = LexifoneTranslateUploadModeGoogleAPI;
    //                                                                        
    //                                                                        [[LexifoneTranslateUploadS3 sharedManager] writeTranslationToFileWithText:translationWithTimestamp];
    //                                                                    }
    //                                                                }
                                                                }
                                                            }
                                                            //                                                    if (finished) {
                                                            //                                                      [self stopAudio:nil];
                                                            //                                                    }
                                                        } else {
//                                                            [self restartAudio];
                                                           
//                                                            [self stopAudio];
//                                                            self.isStreaming = NO;
                                                        }
                                                    }];
        self.audioData = [[NSMutableData alloc] init];
    }
}

- (void)restartAudio {
    
    [self stopAudio];
    self.isStreaming = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self recordAudio];
    });

}
@end

