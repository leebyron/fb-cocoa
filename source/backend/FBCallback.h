//
//  FBCallback.h
//  FBCocoa
//
//  Created by Lee Byron on 10/13/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FBCallback : NSObject {
  id  target;
  SEL method;

  id userData;
  id response;
  NSError* error;
}

- (id)initWithTarget:(id)tar
            selector:(SEL)sel;

- (void)success:(id)json;
- (void)failure:(NSError*)err;

- (id)userData;
- (void)setUserData:(id)data;

- (id)response;
- (void)setResponse:(id)aResponse;

- (NSError*)error;
- (void)setError:(NSError*)aError;

@end
