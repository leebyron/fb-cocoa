//
//  NSStringAdditions.m
//  FBCocoa
//
//  Created by Owen Yamauchi on 7/22/09.
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import "NSStringAdditions.h"
#include <openssl/md5.h>

@implementation NSString (NSStringAdditions)

+ (NSString *)urlEncodeArguments:(NSDictionary *)dict
{
  NSMutableString *result = [NSMutableString string];

  for (NSString *key in dict) {
    if ([result length] > 0) {
      [result appendString:@"&"];
    }
    NSString *encodedKey = [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *encodedValue =
    [[[dict objectForKey:key] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];
    [result appendString:encodedKey];
    [result appendString:@"="];
    [result appendString:encodedValue];
  }
  return result;
}

- (NSString *)stringByEscapingQuotesAndBackslashes
{
  NSString *s = self;
  s = [s stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
  s = [s stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
  return s;
}

- (NSDictionary *)simpleJSONDecode
{
  NSCharacterSet *quot = [NSCharacterSet characterSetWithCharactersInString:@"\""];
  NSCharacterSet *brak = [NSCharacterSet characterSetWithCharactersInString:@"{}"];
  NSArray *rawList = [[self stringByTrimmingCharactersInSet:brak] componentsSeparatedByString:@","];
  NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
  for (NSString *pair in rawList) {
    NSArray *kv = [pair componentsSeparatedByString:@":"];
    NSString *key = [[kv objectAtIndex:0] stringByTrimmingCharactersInSet:quot];
    NSString *value = [[kv objectAtIndex:1] stringByTrimmingCharactersInSet:quot];
    [dict setValue:value forKey:key];
  }
  return dict;
}

- (NSString *)hexMD5
{
  NSData *digest = [self dataUsingEncoding:NSUTF8StringEncoding];
  unsigned long length = [digest length];
  unsigned char hash[MD5_DIGEST_LENGTH];

  MD5([digest bytes], length, hash);

  NSMutableString *result = [NSMutableString string];
  int i;
  for (i = 0; i < MD5_DIGEST_LENGTH; i++) {
    [result appendFormat:@"%02x", hash[i]];
  }

  return result;
}

- (BOOL)containsString:(NSString *)string
{
  return [self rangeOfString:string].location != NSNotFound;
}

@end
