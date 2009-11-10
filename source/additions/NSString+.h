//
//  NSString+.h
//  FBCocoa
//
//  Created by Owen Yamauchi on 7/22/09.
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSString (FBCocoa)

+ (BOOL)exists:(id)string;

- (NSDictionary*)urlDecodeArguments;

+ (NSString*)urlEncodeArguments:(NSDictionary*)dict;

- (NSString*)urlDecode;
- (NSString*)urlEncode;

- (BOOL)containsString:(NSString*)string;

@end
