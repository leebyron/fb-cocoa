//
//  FBSession.m
//  FBCocoa
//
//  Created by Lee Byron on 8/10/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import "FBSession.h"

#define kFBSavedSessionKey @"FBSavedSession"
#define kFBSavedPermissionsKey @"FBSavedPermisssions"

@interface FBSession (Private)

- (void)setDictionary:(NSDictionary *)dict;

@end


@implementation FBSession

@synthesize uid, key, secret, permissions;

-(id)init
{
  if (!(self = [super init])) {
    return nil;
  }

  // read in stored session if it exists
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  if ([ud dictionaryForKey:kFBSavedSessionKey]) {
    NSDictionary *dict = [ud dictionaryForKey:kFBSavedSessionKey];
    [self setDictionary:dict];
    permissions = [[ud arrayForKey:kFBSavedPermissionsKey] retain];
  }

  return self;
}

-(void)dealloc
{
  [secret      release];
  [key         release];
  [signature   release];
  [uid         release];
  [expires     release];
  [permissions release];

  [super dealloc];
}

-(void)setDictionary:(NSDictionary *)dict
{
  [secret release];
  [key release];
  [signature release];
  [uid release];
  [expires release];

  secret = [[dict valueForKey:@"secret"] retain];
  key = [[dict valueForKey:@"session_key"] retain];
  signature = [[dict valueForKey:@"sig"] retain];
  uid = [[dict valueForKey:@"uid"] retain];
  expires = [[NSDate dateWithTimeIntervalSince1970:[[dict valueForKey:@"expires"] doubleValue]] retain];
}

-(void) setWithDictionary:(NSDictionary *)dict
{
  [self setDictionary:dict];

  // save session forever
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  [ud removeObjectForKey:kFBSavedSessionKey];
  [ud setObject:dict forKey:kFBSavedSessionKey];
  [ud synchronize];
}

-(void)setPermissions:(NSArray *)perms
{
  [perms retain];
  [permissions release];
  permissions = perms;

  // save session forever
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  [ud removeObjectForKey:kFBSavedPermissionsKey];
  [ud setObject:permissions forKey:kFBSavedPermissionsKey];
  [ud synchronize];
}

-(BOOL)isValid
{
  return uid != nil && expires != nil && [expires compare:[NSDate date]] == NSOrderedDescending;
}

-(void)clear
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  [ud removeObjectForKey:kFBSavedSessionKey];
  [ud removeObjectForKey:kFBSavedPermissionsKey];
  [ud synchronize];
  [uid release];
  uid = nil;
}

@end
