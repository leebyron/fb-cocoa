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

+ (BOOL)exists:(id)string
{
  return string != nil && [string isKindOfClass:[NSString class]] && [string respondsToSelector:@selector(length)] && [string length] > 0;
}

- (NSDictionary*)urlDecodeArguments
{
  NSArray* pairs = [self componentsSeparatedByString:@"&"];
  NSMutableDictionary* decoded = [[[NSMutableDictionary alloc] initWithCapacity:[pairs count]] autorelease];
  for (NSString* pair in pairs) {
    NSRange pairSplit = [pair rangeOfString:@"="];
    if (pairSplit.location == NSNotFound) {
      [decoded setValue:@"1" forKey:[pair urlDecode]];
    } else {
      NSString* key   = [[pair substringToIndex:pairSplit.location] urlDecode];
      NSString* value = [[pair substringFromIndex:(pairSplit.location + pairSplit.length)] urlDecode];
      [decoded setValue:value forKey:key];
    }
  }
  return decoded;
}

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
    [encodedKey release];
    [encodedValue release];
  }
  return result;
}

- (NSString*)urlDecode
{
  return [self stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
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
