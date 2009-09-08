//
//  NSString+.m
//  FBCocoa
//
//  Created by Owen Yamauchi on 7/22/09.
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import "NSString+.h"
#include <openssl/md5.h>

@implementation NSString (Additions)

+ (NSString *)urlEncodeArguments:(NSDictionary *)dict
{
  NSMutableString *result = [NSMutableString string];

  for (NSString *key in dict) {
    if ([result length] > 0) {
      [result appendString:@"&"];
    }
    NSString *encodedKey = [key urlEncode];
    NSString *encodedValue = [[dict objectForKey:key] urlEncode];
    if (encodedKey != nil && encodedValue != nil) {
      [result appendString:encodedKey];
      [result appendString:@"="];
      [result appendString:encodedValue];
    }
  }
  return result;
}

- (NSString *)urlEncode
{
  return (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                             (CFStringRef)self,
                                                             NULL,
                                                             (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                             kCFStringEncodingUTF8);
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
