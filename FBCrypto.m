//
//  FBCrypto.m
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import "FBCrypto.h"
#include <openssl/md5.h>

@implementation FBCrypto

+ (NSString *)hexMD5:(NSString *)s
{
  const unsigned char *data = (unsigned char *)[s UTF8String];
  unsigned long length = [s length];
  unsigned char hash[MD5_DIGEST_LENGTH];

  MD5(data, length, hash);

  NSMutableString *result = [NSMutableString string];
  int i;
  for (i = 0; i < MD5_DIGEST_LENGTH; i++) {
    [result appendFormat:@"%02x", hash[i]];
  }

  return result;
}

@end
