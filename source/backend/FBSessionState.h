//
//  FBSession.h
//  FBCocoa
//
//  Created by Lee Byron on 8/10/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FBSessionState : NSObject {
  NSString*     keychainKey;
  NSString*     secret;
  NSString*     key;
  NSString*     signature;
  NSString*     uid;
  NSDate*       expires;
  NSMutableSet* permissions;
}

- (id)initWithKey:(NSString*)aKey;

- (NSString*)uid;
- (void)setUID:(NSString*)aString;

- (NSString *)key;
- (void)setKey:(NSString*)aString;

- (NSString*)secret;
- (void)setSecret:(NSString*)aString;

- (NSSet*)permissions;
- (void)setPermissions:(id)perms;
- (void)addPermission:(NSString*)perm;
- (void)addPermissions:(id)perms;
- (BOOL)hasPermission:(NSString*)perm;

- (void)setWithDictionary:(NSDictionary*)dict;

- (BOOL)exists;

- (BOOL)isValid;

- (void)invalidate;

- (void)clear;

@end
