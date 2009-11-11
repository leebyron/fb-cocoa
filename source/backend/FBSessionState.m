//
//  FBSession.m
//  FBCocoa
//
//  Created by Lee Byron on 8/10/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import "FBSessionState.h"
#import "JSON.h"
#import "EMKeychainItem.h"
#import "EMKeychainProxy.h"

#define kFBSavedSessionKey @"FBSavedSession"
#define kFacebookDesktopService @"Facebook Notifier Login"


@interface FBSessionState (Private)

- (void)setDictionary:(NSDictionary*)dict;

@end


@implementation FBSessionState

- (id)initWithKey:(NSString*)aKey
{
  if (self = [super init])
  {
    keychainKey = [aKey retain];
    permissions = [[NSMutableSet alloc] init];

    // read in stored session if it exists
    EMKeychainItem* keychain =
      [[EMKeychainProxy sharedProxy] genericKeychainItemForService:kFacebookDesktopService
                                                      withUsername:keychainKey];
    if (keychain && [[keychain password] length] > 0) {
      NSDictionary* dict = [[keychain password] JSONValue];
      if (dict) {
        [self setDictionary:dict];
      }
    }
  }
  return self;
}

- (void)dealloc
{
  [keychainKey release];

  [secret      release];
  [key         release];
  [signature   release];
  [uid         release];
  [expires     release];
  [permissions release];

  [super dealloc];
}

- (NSString*)uid
{
  return uid;
}

- (void)setUID:(NSString*)aString
{
  [aString retain];
  [uid release];
  uid = aString;
}

- (NSString*)key
{
  return key;
}

- (void)setKey:(NSString*)aString
{
  [aString retain];
  [key release];
  key = aString;
}

- (NSString*)secret
{
  return secret;
}

- (void)setSecret:(NSString*)aString
{
  [aString retain];
  [secret release];
  secret = aString;
}

- (NSSet*)permissions
{
  return permissions;
}

- (void)setPermissions:(id)perms
{
  if ([perms isKindOfClass:[NSArray class]]) {
    [permissions removeAllObjects];
    [permissions addObjectsFromArray:perms];
  } else if ([perms isKindOfClass:[NSSet class]]) {
    [permissions removeAllObjects];
    [permissions unionSet:perms];
  }
}

- (void)addPermission:(NSString*)perm
{
  [permissions addObject:perm];
}

- (void)addPermissions:(id)perms
{
  if ([perms isKindOfClass:[NSArray class]]) {
    [permissions addObjectsFromArray:perms];
  } else if ([perms isKindOfClass:[NSSet class]]) {
    [permissions unionSet:perms];
  }
}

- (BOOL)hasPermission:(NSString*)perm
{
  return [permissions containsObject:perm];
}

- (void) setWithDictionary:(NSDictionary*)dict
{
  [self setDictionary:dict];

  // save session forever
  NSString* pass = [dict JSONRepresentation];

  EMKeychainItem* keychain = [[EMKeychainProxy sharedProxy]
                              genericKeychainItemForService:kFacebookDesktopService
                                               withUsername:keychainKey];
  if (keychain) {
    [keychain setPassword:pass];
  } else {
    [[EMKeychainProxy sharedProxy]
     addGenericKeychainItemForService:kFacebookDesktopService
                         withUsername:keychainKey
                             password:pass];
  }
}

- (void)setDictionary:(NSDictionary*)dict
{
  [secret     release];
  [key        release];
  [signature  release];
  [uid        release];
  [expires    release];

  secret    = [[dict valueForKey:@"secret"] retain];
  key       = [[dict valueForKey:@"session_key"] retain];
  signature = [[dict valueForKey:@"sig"] retain];
  expires   = [[NSDate dateWithTimeIntervalSince1970:
                [[dict valueForKey:@"expires"] doubleValue]] retain];
  uid       = [dict valueForKey:@"uid"];
  if (![uid isKindOfClass:[NSString class]]) {
    uid = [(id)uid stringValue];
  }
  [uid retain];
}

- (BOOL)exists
{
  return uid != nil && uid != @"0";
}

- (BOOL)isValid
{
  // expires == 0 iff an infinite session has been granted
  return [self exists] && expires != nil &&
         ([expires compare:[NSDate dateWithTimeIntervalSince1970:0]] == NSOrderedSame ||
          [expires compare:[NSDate date]] == NSOrderedDescending);
}

- (void)invalidate
{
  expires = nil;
}

- (void)clear
{
  EMKeychainItem* keychain = [[EMKeychainProxy sharedProxy]
                              genericKeychainItemForService:kFacebookDesktopService
                              withUsername:keychainKey];
  if (keychain) {
    [keychain setPassword:@""];
  }

  [uid release];
  uid = nil;
}

@end
