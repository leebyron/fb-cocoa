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
               error:(SEL)err
{
  if (self = [super init]) {
    target = [tar retain];
    method = sel;
    errorMethod = err;
  }
  return self;
}

-(void)dealloc
{
  [target release];
  [super dealloc];
}

- (void)success:(id)json
{
  if (target && method && [target respondsToSelector:method]) {
    [target performSelector:method withObject:json];
  }
}

- (void)failure:(NSError *)err
{
  if (target && errorMethod && [target respondsToSelector:errorMethod]) {
    [target performSelector:errorMethod withObject:err];
  }
}

@end
