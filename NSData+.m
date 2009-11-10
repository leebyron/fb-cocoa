//
//  NSData+.m
//  FBCocoa
//
//  Created by Lee Byron on 11/9/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import "NSData+.h"
#include <openssl/md5.h>


@implementation NSData (FBCocoa)

- (NSString*)md5
{
  unsigned long length = [self length];
  unsigned char hash[MD5_DIGEST_LENGTH];

  MD5([self bytes], length, hash);

  NSMutableString *result = [NSMutableString string];
  int i;
  for (i = 0; i < MD5_DIGEST_LENGTH; i++) {
    [result appendFormat:@"%02x", hash[i]];
  }

  return result;
}

@end
