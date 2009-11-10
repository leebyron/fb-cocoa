//
//  FBCallback.m
//  FBCocoa
//
//  Created by Lee Byron on 10/13/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import "FBCallback.h"


@implementation FBCallback

- (id)initWithTarget:(id)tar
            selector:(SEL)sel
{
  if (self = [super init]) {
    target = tar;
    method = sel;
  }
  return self;
}

- (void)dealloc
{
  [response release];
  [error release];
  [userData release];
  [super dealloc];
}

- (void)success:(id)json
{
  [self setResponse:json];
  DELEGATE(target, method);
}

- (void)failure:(NSError*)err
{
  [self setError:err];
  DELEGATE(target, method);
}

- (id)userData
{
  return userData;
}

- (void)setUserData:(id)data
{
  [data retain];
  [userData release];
  userData = data;
}

- (id)response
{
  return response;
}

- (void)setResponse:(id)aResponse
{
  [aResponse retain];
  [response release];
  response = aResponse;
}

- (NSError*)error
{
  return error;
}

- (void)setError:(NSError*)aError
{
  [aError retain];
  [error release];
  error = aError;
}

@end
