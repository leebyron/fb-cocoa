//
//  FBLoginSession.h
//  FBCocoa
//
//  Created by Lee Byron on 8/10/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FBLoginSession : NSObject {
  NSString *secret;
  NSString *key;
  NSString *signature;
  NSString *uid;
  NSDate   *expires;
}

@property(retain) NSString *uid;
@property(retain) NSString *key;
@property(retain) NSString *secret;

-(void)setWithDictionary:(NSDictionary *)dict;

-(BOOL)isValid;

-(void)clear;

@end
