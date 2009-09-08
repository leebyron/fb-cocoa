//
//  FBRequest.h
//  FBCocoa
//
//  Created by Lee Byron on 7/30/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FBConnect.h"

@interface FBRequest : NSObject {
  NSString* request;
  id  target;
  SEL method;
  SEL errorMethod;
  NSMutableData *responseBuffer;
  FBConnect *parentConnect;
  NSURLConnection *connection;
}

-(id)initWithRequest:(NSString *)requestString
              parent:(FBConnect *)parent
              target:(id)tar
            selector:(SEL)sel
               error:(SEL)err;

- (void)start;

- (void)evaluateResponse:(id)json;

- (void)requestSuccess:(id)json;

- (void)requestFailure:(NSError *)err;

@end
