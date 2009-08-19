//
//  FBRequest.h
//  FBCocoa
//
//  Created by Lee Byron on 7/30/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FBConnect.h"

@interface FBRequest : NSURLConnection {
  id  target;
  SEL method;
  SEL errorMethod;
  NSMutableData *responseBuffer;
  FBConnect *parentConnect;
}

-(id)initWithRequest:(NSURLRequest *)req
              target:(id)tar
            selector:(SEL)sel
              parent:(FBConnect *)parent
               error:(SEL)err;

@end
