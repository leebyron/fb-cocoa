//
//  FBSession.h
//  FBCocoa
//
//  Created by Lee Byron on 8/10/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FBSession : NSObject {
  NSString *secret;
  NSString *key;
  NSString *signature;
  NSString *uid;
  NSDate   *expires;
  NSArray  *permissions;
}

@property(retain) NSString *uid;
@property(retain) NSString *key;
@property(retain) NSString *secret;
@property(retain) NSArray  *permissions;

-(void)setWithDictionary:(NSDictionary *)dict;
-(void)setPermissions:(NSArray *)perms;

-(BOOL)isValid;

-(void)clear;

@end
