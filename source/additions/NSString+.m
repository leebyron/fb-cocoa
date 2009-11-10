//
//  NSString+.m
//  FBCocoa
//
//  Created by Owen Yamauchi on 7/22/09.
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import "NSString+.h"

@implementation NSString (FBCocoa)

+ (BOOL)exists:(id)string
{
  return string != nil &&
    [string isKindOfClass:[NSString class]] &&
    [string respondsToSelector:@selector(length)] &&
    [string length] > 0;
}

- (NSDictionary*)urlDecodeArguments
{
  NSArray* pairs = [self componentsSeparatedByString:@"&"];
  NSMutableDictionary* decoded = [[[NSMutableDictionary alloc] initWithCapacity:[pairs count]] autorelease];
  NSString* pair;
  for (int i = 0; i < [pairs count]; i++) {
    pair = [pairs objectAtIndex:i];
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

+ (NSString*)urlEncodeArguments:(NSDictionary*)dict
{
  NSMutableString* result = [NSMutableString string];

  NSEnumerator* enumerator = [dict keyEnumerator];
  NSString* key;
  while ((key = [enumerator nextObject])) {
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
  return (NSString*)CFURLCreateStringByAddingPercentEscapes(
    NULL, (CFStringRef)self, NULL, (CFStringRef)@"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8);
}

- (BOOL)containsString:(NSString*)string
{
  return [self rangeOfString:string].location != NSNotFound;
}

@end
