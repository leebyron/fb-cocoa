//
//  FBSession.h
//  FBCocoa
//
//  Created by Lee Byron on 8/10/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FBSessionState : NSObject {
  NSString *secret;
  NSString *key;
  NSString *signature;
  NSString *uid;
  NSDate   *expires;
  NSArray  *permissions;
}

- (NSString *)uid;
- (void)setUID:(NSString *)aString;
- (NSString *)key;
- (void)setKey:(NSString *)aString;
- (NSString *)secret;
- (void)setSecret:(NSString *)aString;
- (NSArray *)permissions;

-(void)setWithDictionary:(NSDictionary *)dict;
-(void)setPermissions:(NSArray *)perms;

-(BOOL)exists;
-(BOOL)isValid;

-(void)clear;
-(void)invalidate;

@end
