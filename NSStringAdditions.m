//
//  NSStringAdditions.m
//  FBCocoa
//
//  Created by Owen Yamauchi on 7/22/09.
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import "NSStringAdditions.h"


@implementation NSString (NSStringAdditions)

- (NSString *)stringByEscapingQuotesAndBackslashes
{
  NSString *s = self;
  s = [s stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
  s = [s stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
  return s;
}

@end
