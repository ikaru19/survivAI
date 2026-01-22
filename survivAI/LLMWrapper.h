//
//  LLMWrapper.m
//  survivAI
//
//  Created by Muhammad Syafrizal on 03/05/25.
//

#import <Foundation/Foundation.h>

@interface LLMWrapper : NSObject
- (NSString *)runPrompt:(NSString *)prompt;
- (void)setSystemPrompt:(NSString *)prompt;
@end
